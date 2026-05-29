import AppKit
import SwiftUI

final class PandaWindowController: NSWindowController {
    private let baseSize = NSSize(width: 180, height: 200)
    private let positionKey = "PandaPal.lastPosition"
    private let sizeKey = "PandaPal.size"
    private let genderKey = "PandaPal.gender"
    let viewModel = PandaViewModel()

    private var pandaSize: NSSize {
        let m = viewModel.size.multiplier
        return NSSize(width: baseSize.width * m, height: baseSize.height * m)
    }

    convenience init() {
        let storedSize = UserDefaults.standard.string(forKey: "PandaPal.size").flatMap(PandaSize.init(rawValue:)) ?? .medium
        let m = storedSize.multiplier
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 180 * m, height: 200 * m)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        self.init(window: panel)
        viewModel.size = storedSize
        let storedGender = UserDefaults.standard.string(forKey: "PandaPal.gender").flatMap(PandaGender.init(rawValue:)) ?? .girl
        viewModel.gender = storedGender

        let hostingView = PandaHostingView(rootView: PandaContainerView(viewModel: viewModel))
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        viewModel.onWander = { [weak self] dx, dy, duration in
            self?.wander(dx: dx, dy: dy, duration: duration)
        }

        viewModel.onCaptureDragOffset = { [weak self] in
            self?.captureDragOffset()
        }

        viewModel.onDragTrackMouse = { [weak self] in
            self?.dragWindowToMouse()
        }

        viewModel.onDragEnded = { [weak self] in
            self?.savePosition()
        }

        viewModel.onChaseStart = { [weak self] in
            self?.startMouseChase()
        }

        viewModel.onSizeSelected = { [weak self] size in
            self?.setSize(size)
        }

        hostingView.onRightClick = { [weak self] event in
            self?.showContextMenu(for: event)
        }

        restorePosition()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    func setGender(_ gender: PandaGender) {
        viewModel.gender = gender
        UserDefaults.standard.set(gender.rawValue, forKey: genderKey)
    }

    func setSize(_ size: PandaSize) {
        viewModel.size = size
        UserDefaults.standard.set(size.rawValue, forKey: sizeKey)

        guard let window = window else { return }
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let new = pandaSize
        let origin = NSPoint(x: center.x - new.width / 2, y: center.y - new.height / 2)
        window.setFrame(NSRect(origin: origin, size: new), display: true, animate: false)
        savePosition()
    }

    func resetPosition() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - pandaSize.width / 2
        let y = screenFrame.midY - pandaSize.height / 2
        window?.setFrameOrigin(NSPoint(x: x, y: y))
        savePosition()
    }

    private func restorePosition() {
        if let positionString = UserDefaults.standard.string(forKey: positionKey) {
            let components = positionString.split(separator: ",")
            if components.count == 2,
               let x = Double(components[0]),
               let y = Double(components[1]) {
                window?.setFrameOrigin(NSPoint(x: x, y: y))
                return
            }
        }
        resetPosition()
    }

    private func savePosition() {
        guard let origin = window?.frame.origin else { return }
        let positionString = "\(origin.x),\(origin.y)"
        UserDefaults.standard.set(positionString, forKey: positionKey)
    }

    private var dragOffset: NSPoint = .zero

    private func captureDragOffset() {
        guard let window = window else { return }
        wanderTimer?.invalidate()
        wanderTimer = nil
        // Grabbing her mid-hunt cancels the chase so the drag wins.
        chaseTimer?.invalidate()
        chaseTimer = nil
        let mouse = NSEvent.mouseLocation
        dragOffset = NSPoint(
            x: window.frame.origin.x - mouse.x,
            y: window.frame.origin.y - mouse.y
        )
    }

    private func dragWindowToMouse() {
        guard let window = window else { return }
        let mouse = NSEvent.mouseLocation
        // Window origin is recomputed from absolute mouse position every event,
        // so no error accumulates even if SwiftUI throttles events.
        window.setFrameOrigin(NSPoint(
            x: mouse.x + dragOffset.x,
            y: mouse.y + dragOffset.y
        ))
    }

    private var wanderTimer: Timer?
    private var chaseTimer: Timer?

    // Walk the window toward the live cursor at a steady pace, re-reading the
    // mouse every frame so she tracks it even as it keeps moving. Once she's on
    // top of it (or a safety timeout fires) she pounces. The model owns the leg
    // + pounce animation; this just moves the window and reports facing/catch.
    private func startMouseChase() {
        guard let window = window else {
            viewModel.catchPrey()
            return
        }

        wanderTimer?.invalidate()
        wanderTimer = nil
        chaseTimer?.invalidate()

        let speed: CGFloat = 7.0           // points per frame ≈ 420 pt/s
        let catchRadius: CGFloat = 34      // close enough to lunge
        let maxDuration: TimeInterval = 9.0
        let startTime = Date()

        // She grabs with her paws, which sit below — and slightly right of —
        // her body's center. Aim that paw point, not the window center, at the
        // cursor so the cursor ends up right where her little paws clamp shut.
        let pawDropBelowCenter: CGFloat = 26 * viewModel.size.multiplier
        let pawRightOfCenter: CGFloat = 8 * viewModel.size.multiplier

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak window] timer in
            guard let self = self, let window = window else {
                timer.invalidate()
                return
            }

            let mouse = NSEvent.mouseLocation
            let frame = window.frame
            // Screen y is up, so "below center" is midY minus the drop.
            let pawX = frame.midX + pawRightOfCenter
            let pawY = frame.midY - pawDropBelowCenter
            let dx = mouse.x - pawX
            let dy = mouse.y - pawY
            let dist = hypot(dx, dy)

            if dist <= catchRadius || Date().timeIntervalSince(startTime) > maxDuration {
                timer.invalidate()
                self.chaseTimer = nil
                // Final lunge: close the remaining gap so the paw point lands
                // exactly on the cursor as she pounces, rather than stopping
                // up to catchRadius short of it.
                self.lungeOntoCursor(pawRightOfCenter: pawRightOfCenter, pawDropBelowCenter: pawDropBelowCenter)
                self.viewModel.catchPrey()
                return
            }

            // Face the way she's running.
            self.viewModel.updateChaseFacing(dx >= 0 ? 1 : -1)

            // Step toward the cursor, clamped to the union of all screens so she
            // can chase across monitors without walking off into the void.
            let step = min(speed, dist)
            let bounds = self.screensBounds()
            let nx = min(max(frame.origin.x + dx / dist * step, bounds.minX), bounds.maxX - frame.width)
            let ny = min(max(frame.origin.y + dy / dist * step, bounds.minY), bounds.maxY - frame.height)
            window.setFrameOrigin(NSPoint(x: nx, y: ny))
        }
        chaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func screensBounds() -> NSRect {
        return NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
    }

    // Slide the window over the crouch/wind-up so the paw point ends exactly on
    // the cursor at the moment of the slam (the pounce's leap is at ~0.5s, slam
    // at ~0.78s — this glide finishes well before then).
    private func lungeOntoCursor(pawRightOfCenter: CGFloat, pawDropBelowCenter: CGFloat) {
        guard let window = window else { return }

        let mouse = NSEvent.mouseLocation
        let frame = window.frame
        let target = NSPoint(
            x: mouse.x - frame.width / 2 - pawRightOfCenter,
            y: mouse.y - frame.height / 2 + pawDropBelowCenter
        )

        let start = frame.origin
        let duration: TimeInterval = 0.45
        let startTime = Date()

        chaseTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak window] timer in
            guard let self = self, let window = window else {
                timer.invalidate()
                return
            }
            let t = min(1.0, Date().timeIntervalSince(startTime) / duration)
            let eased = t * t * (3 - 2 * t)
            window.setFrameOrigin(NSPoint(
                x: start.x + (target.x - start.x) * CGFloat(eased),
                y: start.y + (target.y - start.y) * CGFloat(eased)
            ))
            if t >= 1.0 {
                timer.invalidate()
                self.chaseTimer = nil
                self.savePosition()
            }
        }
        chaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func wander(dx: CGFloat, dy: CGFloat, duration: TimeInterval) {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let start = window.frame.origin
        let visible = screen.visibleFrame

        var targetX = start.x + dx
        var targetY = start.y + dy
        targetX = min(max(targetX, visible.minX + 10), visible.maxX - pandaSize.width - 10)
        targetY = min(max(targetY, visible.minY + 10), visible.maxY - pandaSize.height - 10)
        let target = NSPoint(x: targetX, y: targetY)

        // NSWindow.animator() doesn't reliably animate borderless panels —
        // drive the interpolation ourselves at 60fps.
        wanderTimer?.invalidate()
        let startTime = Date()
        wanderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak window] timer in
            guard let window = window else {
                timer.invalidate()
                return
            }
            let t = min(1.0, Date().timeIntervalSince(startTime) / duration)
            let eased = t * t * t * (t * (t * 6 - 15) + 10)
            let deltaX = Double(target.x - start.x)
            let deltaY = Double(target.y - start.y)
            let travel = hypot(deltaX, deltaY)
            let lift = sin(t * .pi) * min(10, max(3, travel * 0.018))
            let x = start.x + (target.x - start.x) * CGFloat(eased)
            let y = start.y + (target.y - start.y) * CGFloat(eased) + CGFloat(lift)
            window.setFrameOrigin(NSPoint(x: x, y: y))
            if t >= 1.0 {
                timer.invalidate()
                self?.savePosition()
            }
        }
        if let wanderTimer = wanderTimer {
            RunLoop.main.add(wanderTimer, forMode: .common)
        }
    }

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }

    private func showContextMenu(for event: NSEvent) {
        guard let view = window?.contentView else { return }
        let menu = NSMenu()

        let pet = NSMenuItem(title: "Pet", action: #selector(menuPet), keyEquivalent: "")
        pet.target = self
        menu.addItem(pet)

        let wave = NSMenuItem(title: "Wave Hello", action: #selector(menuWave), keyEquivalent: "")
        wave.target = self
        menu.addItem(wave)

        let dance = NSMenuItem(title: "Dance", action: #selector(menuDance), keyEquivalent: "")
        dance.target = self
        menu.addItem(dance)

        let walk = NSMenuItem(title: "Walk", action: #selector(menuWalk), keyEquivalent: "")
        walk.target = self
        menu.addItem(walk)

        let chase = NSMenuItem(title: "Chase", action: #selector(menuChase), keyEquivalent: "")
        chase.target = self
        menu.addItem(chase)

        let feed = NSMenuItem(title: "Feed", action: #selector(menuFeed), keyEquivalent: "")
        feed.target = self
        menu.addItem(feed)

        menu.addItem(NSMenuItem.separator())

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for size in PandaSize.allCases {
            let item = NSMenuItem(title: size.label, action: #selector(menuSize(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = size.rawValue
            item.state = viewModel.size == size ? .on : .off
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let genderItem = NSMenuItem(title: "Gender", action: nil, keyEquivalent: "")
        let genderMenu = NSMenu()
        for gender in PandaGender.allCases {
            let item = NSMenuItem(title: gender.label, action: #selector(menuGender(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = gender.rawValue
            item.state = viewModel.gender == gender ? .on : .off
            genderMenu.addItem(item)
        }
        genderItem.submenu = genderMenu
        menu.addItem(genderItem)

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func menuGender(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let gender = PandaGender(rawValue: raw) else { return }
        setGender(gender)
    }

    @objc private func menuPet() {
        viewModel.pet()
    }

    @objc private func menuWave() {
        viewModel.waveHello()
    }

    @objc private func menuDance() {
        viewModel.danceNow()
    }

    @objc private func menuWalk() {
        viewModel.forceWander()
    }

    @objc private func menuChase() {
        viewModel.chaseNow()
    }

    @objc private func menuFeed() {
        viewModel.feedBamboo()
    }

    @objc private func menuSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = PandaSize(rawValue: raw) else { return }
        setSize(size)
    }
}

final class PandaHostingView<Content: View>: NSHostingView<Content> {
    var onRightClick: ((NSEvent) -> Void)?

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        onRightClick?(event)
        return nil
    }
}

import AppKit
import SwiftUI

final class PandaWindowController: NSWindowController {
    private let baseSize = NSSize(width: 180, height: 200)
    private let positionKey = "PandaPal.lastPosition"
    private let sizeKey = "PandaPal.size"
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

        let walk = NSMenuItem(title: "Walk", action: #selector(menuWalk), keyEquivalent: "")
        walk.target = self
        menu.addItem(walk)

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

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func menuPet() {
        viewModel.pet()
    }

    @objc private func menuWalk() {
        viewModel.forceWander()
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

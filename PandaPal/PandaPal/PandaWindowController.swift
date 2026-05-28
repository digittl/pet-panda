import AppKit
import SwiftUI

final class PandaWindowController: NSWindowController {
    private let baseSize = NSSize(width: 140, height: 160)
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
            contentRect: NSRect(origin: .zero, size: NSSize(width: 140 * m, height: 160 * m)),
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

        let hostingView = NSHostingView(rootView: PandaContainerView(viewModel: viewModel))
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        viewModel.onWander = { [weak self] dx, dy, duration in
            self?.wander(dx: dx, dy: dy, duration: duration)
        }

        viewModel.onMoveBy = { [weak self] dx, dy in
            self?.moveWindowBy(dx: dx, dy: dy)
        }

        viewModel.onDragEnded = { [weak self] in
            self?.savePosition()
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

    private func moveWindowBy(dx: CGFloat, dy: CGFloat) {
        wanderTimer?.invalidate()
        wanderTimer = nil

        guard let window = window else { return }
        var origin = window.frame.origin
        origin.x += dx
        // NSEvent.mouseLocation is y-up; window origin is also y-up.
        origin.y += dy
        window.setFrameOrigin(origin)
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
            let eased: Double = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            let x = start.x + (target.x - start.x) * CGFloat(eased)
            let y = start.y + (target.y - start.y) * CGFloat(eased)
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
}

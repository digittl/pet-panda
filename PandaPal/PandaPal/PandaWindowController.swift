import AppKit
import SwiftUI

final class PandaWindowController: NSWindowController {
    private let pandaSize = NSSize(width: 140, height: 160)
    private let positionKey = "PandaPal.lastPosition"
    private let viewModel = PandaViewModel()

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 140, height: 160)),
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
        guard let window = window else { return }
        var origin = window.frame.origin
        origin.x += dx
        // SwiftUI gesture deltaY is positive going down; window y is positive going up.
        origin.y -= dy
        window.setFrameOrigin(origin)
    }

    private func wander(dx: CGFloat, dy: CGFloat, duration: TimeInterval) {
        guard let window = window, let screen = window.screen ?? NSScreen.main else { return }
        let frame = window.frame
        let visible = screen.visibleFrame

        var targetX = frame.origin.x + dx
        var targetY = frame.origin.y + dy

        targetX = min(max(targetX, visible.minX + 10), visible.maxX - pandaSize.width - 10)
        targetY = min(max(targetY, visible.minY + 10), visible.maxY - pandaSize.height - 10)

        let target = NSPoint(x: targetX, y: targetY)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrameOrigin(target)
        }, completionHandler: { [weak self] in
            self?.savePosition()
        })
    }

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }
}

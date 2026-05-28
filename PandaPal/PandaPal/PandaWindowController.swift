import AppKit
import SwiftUI

final class PandaWindowController: NSWindowController {
    private let pandaSize = NSSize(width: 120, height: 140)
    private let positionKey = "PandaPal.lastPosition"

    convenience init() {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 120, height: 140)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let pandaViewModel = PandaViewModel()
        let hostingView = NSHostingView(rootView: PandaContainerView(viewModel: pandaViewModel))
        hostingView.frame = panel.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]

        panel.contentView = hostingView

        self.init(window: panel)

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

    @objc private func windowDidMove(_ notification: Notification) {
        savePosition()
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }
}

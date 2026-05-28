import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pandaWindowController: PandaWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Don't restore the SwiftUI Settings scene on relaunch.
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")

        closeStrayWindows()
        setupMenuBar()
        showPanda()

        DispatchQueue.main.async { [weak self] in
            self?.closeStrayWindows()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func closeStrayWindows() {
        for window in NSApp.windows {
            if window === pandaWindowController?.window {
                continue
            }

            // Only close SwiftUI-managed scene windows. NSStatusBar's internal
            // window also lives in NSApp.windows on some OS versions — closing
            // that would kill our menu bar item.
            let id = window.identifier?.rawValue ?? ""
            let isSwiftUIScene = id.contains("SwiftUI") || id.contains("Settings")
            let looksLikeSettings = window.title.contains("Settings")
            if isSwiftUIScene || looksLikeSettings {
                window.close()
            }
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Panda Pal")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Panda", action: #selector(togglePanda), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
    }

    private func showPanda() {
        if pandaWindowController == nil {
            pandaWindowController = PandaWindowController()
        }
        pandaWindowController?.showWindow(nil)
    }

    @objc private func togglePanda() {
        guard let controller = pandaWindowController else {
            showPanda()
            return
        }
        if controller.window?.isVisible == true {
            controller.window?.orderOut(nil)
        } else {
            controller.showWindow(nil)
        }
    }

    @objc private func resetPosition() {
        pandaWindowController?.resetPosition()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

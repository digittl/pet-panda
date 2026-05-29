import AppKit
import Sparkle
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var pandaWindowController: PandaWindowController?
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
        menu.addItem(NSMenuItem(title: "Pet Panda", action: #selector(petPanda), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Wave Hello", action: #selector(waveHello), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Dance", action: #selector(danceNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Walk Now", action: #selector(walkNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Chase Cursor", action: #selector(chaseNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Feed Bamboo", action: #selector(feedBamboo), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Reset Position", action: #selector(resetPosition), keyEquivalent: "r"))

        let sizeItem = NSMenuItem(title: "Size", action: nil, keyEquivalent: "")
        let sizeMenu = NSMenu()
        for size in PandaSize.allCases {
            let item = NSMenuItem(title: size.label, action: #selector(setSize(_:)), keyEquivalent: "")
            item.representedObject = size.rawValue
            sizeMenu.addItem(item)
        }
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let genderItem = NSMenuItem(title: "Gender", action: nil, keyEquivalent: "")
        let genderMenu = NSMenu()
        for gender in PandaGender.allCases {
            let item = NSMenuItem(title: gender.label, action: #selector(setGender(_:)), keyEquivalent: "")
            item.representedObject = gender.rawValue
            genderMenu.addItem(item)
        }
        genderItem.submenu = genderMenu
        menu.addItem(genderItem)

        menu.addItem(NSMenuItem.separator())

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = updaterController
        menu.addItem(checkForUpdates)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        for item in menu.items where item.target == nil && item.action != nil {
            item.target = self
        }
        for item in sizeMenu.items {
            item.target = self
        }
        for item in genderMenu.items {
            item.target = self
        }

        statusItem.menu = menu
        updateSizeMenuState(sizeMenu)
        updateGenderMenuState(genderMenu)
    }

    private func updateGenderMenuState(_ genderMenu: NSMenu) {
        let current = pandaWindowController?.viewModel.gender.rawValue
            ?? UserDefaults.standard.string(forKey: "PandaPal.gender")
            ?? PandaGender.girl.rawValue
        for item in genderMenu.items {
            if let raw = item.representedObject as? String {
                item.state = raw == current ? .on : .off
            }
        }
    }

    @objc private func setGender(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let gender = PandaGender(rawValue: raw) else { return }
        pandaWindowController?.setGender(gender)
        if let genderMenu = sender.menu {
            updateGenderMenuState(genderMenu)
        }
    }

    private func updateSizeMenuState(_ sizeMenu: NSMenu) {
        let current = pandaWindowController?.viewModel.size.rawValue
            ?? UserDefaults.standard.string(forKey: "PandaPal.size")
            ?? PandaSize.medium.rawValue
        for item in sizeMenu.items {
            if let raw = item.representedObject as? String {
                item.state = raw == current ? .on : .off
            }
        }
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = PandaSize(rawValue: raw) else { return }
        pandaWindowController?.setSize(size)
        if let sizeMenu = sender.menu {
            updateSizeMenuState(sizeMenu)
        }
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

    @objc private func petPanda() {
        pandaWindowController?.viewModel.pet()
    }

    @objc private func waveHello() {
        pandaWindowController?.viewModel.waveHello()
    }

    @objc private func danceNow() {
        pandaWindowController?.viewModel.danceNow()
    }

    @objc private func walkNow() {
        pandaWindowController?.viewModel.forceWander()
    }

    @objc private func chaseNow() {
        pandaWindowController?.viewModel.chaseNow()
    }

    @objc private func feedBamboo() {
        pandaWindowController?.viewModel.feedBamboo()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

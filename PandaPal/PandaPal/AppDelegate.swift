import AppKit
import Sparkle
import SwiftUI

/// App entry point and the single source of truth for the pet's menu.
///
/// One `populateMenu(_:)` builds the complete command list (actions, Size /
/// Gender / Pet Type submenus, updates, quit). It feeds both surfaces so they
/// can never drift apart:
///   • the menu-bar status item — re-populated on every open via NSMenuDelegate
///     so its checkmarks always reflect live state, and
///   • the right-click context menu on the pet itself — built fresh per click
///     by `presentContextMenu(_:)`, which PandaWindowController routes to.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
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

    func applicationWillTerminate(_ notification: Notification) {
        // If we quit mid-hunt the system cursor is still hidden — restore it so
        // the user isn't left without a pointer after the app exits.
        pandaWindowController?.restoreSystemCursorIfHidden()
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

    // MARK: - Menu construction

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "pawprint.fill", accessibilityDescription: "Panda Pal")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // NSMenuDelegate: rebuild the status-bar menu right before it opens so the
    // Size / Gender / Pet Type checkmarks always match current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusItem?.menu else { return }
        populateMenu(menu)
    }

    // The one definition of the pet's full command set. Both the status-bar
    // menu and the right-click menu are built from this, so they stay in sync.
    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        addAction(to: menu, title: "Show/Hide Pet", action: #selector(togglePanda), key: "p")
        addAction(to: menu, title: "Pet", action: #selector(petPanda))
        addAction(to: menu, title: "Wave Hello", action: #selector(waveHello))
        addAction(to: menu, title: "Dance", action: #selector(danceNow))
        addAction(to: menu, title: "Walk Now", action: #selector(walkNow))
        addAction(to: menu, title: "Chase Cursor", action: #selector(chaseNow))
        addAction(to: menu, title: "Feed \(currentKind.treatName)", action: #selector(feedBamboo))
        addAction(to: menu, title: "Reset Position", action: #selector(resetPosition), key: "r")

        menu.addItem(.separator())

        menu.addItem(submenuItem(title: "Size", values: PandaSize.allCases.map { ($0.label, $0.rawValue) },
                                 current: currentSize.rawValue, action: #selector(setSize(_:))))
        menu.addItem(submenuItem(title: "Gender", values: PandaGender.allCases.map { ($0.label, $0.rawValue) },
                                 current: currentGender.rawValue, action: #selector(setGender(_:))))
        menu.addItem(submenuItem(title: "Pet Type", values: PetKind.allCases.map { ($0.label, $0.rawValue) },
                                 current: currentKind.rawValue, action: #selector(setPetKind(_:))))

        menu.addItem(.separator())

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = updaterController
        menu.addItem(checkForUpdates)

        menu.addItem(.separator())
        addAction(to: menu, title: "Quit", action: #selector(quitApp), key: "q")
    }

    private func addAction(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    // Build a checkmarked submenu from (label, rawValue) pairs. The raw value
    // rides on representedObject so the @objc handler can decode the choice.
    private func submenuItem(title: String, values: [(String, String)], current: String, action: Selector) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for (label, raw) in values {
            let item = NSMenuItem(title: label, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = raw
            item.state = raw == current ? .on : .off
            submenu.addItem(item)
        }

        parent.submenu = submenu
        return parent
    }

    // Current state, falling back to persisted defaults before the window
    // controller exists (the menu can be built during launch).
    private var currentSize: PandaSize {
        pandaWindowController?.viewModel.size
            ?? UserDefaults.standard.string(forKey: "PandaPal.size").flatMap(PandaSize.init(rawValue:))
            ?? .medium
    }

    private var currentGender: PandaGender {
        pandaWindowController?.viewModel.gender
            ?? UserDefaults.standard.string(forKey: "PandaPal.gender").flatMap(PandaGender.init(rawValue:))
            ?? .girl
    }

    private var currentKind: PetKind {
        pandaWindowController?.viewModel.kind
            ?? UserDefaults.standard.string(forKey: "PandaPal.petKind").flatMap(PetKind.init(rawValue:))
            ?? .panda
    }

    // Pop the full menu up wherever the pet was right-clicked. Built fresh so
    // its checkmarks reflect the moment it opens.
    private func presentContextMenu(_ event: NSEvent) {
        guard let view = pandaWindowController?.window?.contentView else { return }
        let menu = NSMenu()
        populateMenu(menu)
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    // MARK: - Window lifecycle

    private func showPanda() {
        if pandaWindowController == nil {
            pandaWindowController = PandaWindowController()
        }

        pandaWindowController?.onContextMenuRequested = { [weak self] event in
            self?.presentContextMenu(event)
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

    // MARK: - Menu actions

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

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let size = PandaSize(rawValue: raw) else { return }
        pandaWindowController?.setSize(size)
    }

    @objc private func setGender(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let gender = PandaGender(rawValue: raw) else { return }
        pandaWindowController?.setGender(gender)
    }

    @objc private func setPetKind(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let kind = PetKind(rawValue: raw) else { return }
        pandaWindowController?.setPetKind(kind)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

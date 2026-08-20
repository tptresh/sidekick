import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = SettingsStore.shared
    let viewModel = SpideyViewModel()

    private var statusItem: NSStatusItem!
    private var panel: SearchPanel!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    var showOnLaunchQuery: String?
    var snapshotDirectory: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()
        setUpPanel()
        ClipboardStore.shared.start()
        registerHotKey()
        _ = AppProvider.shared
        FileProvider.warmUp()
        LinkChecker.shared.startAutomaticChecks()

        viewModel.onHide = { [weak self] in self?.hidePanel() }

        settings.$hotKey
            .dropFirst()
            .sink { [weak self] _ in self?.registerHotKey() }
            .store(in: &cancellables)
        settings.$theme
            .sink { [weak self] theme in self?.updateStatusIcon(theme) }
            .store(in: &cancellables)
        viewModel.$results
            .receive(on: DispatchQueue.main)
            .sink { [weak self] results in self?.resizePanel(resultCount: results.count) }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let window = note.object as? NSWindow, window == self.panel else { return }
            self.hidePanel()
        }

        showFirstRunHintIfNeeded()

        if let query = showOnLaunchQuery {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showPanel()
                self?.viewModel.query = query
            }
        }

        if let directory = snapshotDirectory {
            runSnapshots(into: directory)
        }
    }

    // MARK: - Snapshots (dev only)

    private func runSnapshots(into directory: String) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let cases: [(query: String, theme: HeroTheme, file: String)] = [
            ("", .spiderman, "empty.png"),
            ("", .batman, "empty-batman.png"),
            ("saf", .spiderman, "apps.png"),
            ("youtube lofi beats", .spiderman, "youtube.png"),
            ("death note", .spiderman, "streaming.png"),
            ("2+2*5", .spiderman, "calculator.png"),
            ("claude fix the spelling issue on my web page", .spiderman, "claude.png"),
            ("clip", .spiderman, "clipboard.png"),
            ("vinted", .spiderman, "sites.png"),
            ("netflix", .spiderman, "netflix.png"),
            ("grand seiko", .batman, "batman.png"),
            ("100 usd to gbp", .spiderman, "convert.png"),
            ("5km in miles", .spiderman, "units.png"),
            ("time in tokyo", .spiderman, "worldclock.png"),
            ("emoji fire", .spiderman, "emoji.png"),
            ("#e02128", .spiderman, "color.png"),
            ("pw 24", .spiderman, "password.png"),
            ("timer 10m tea", .spiderman, "timer.png"),
            ("quit safari", .spiderman, "quit.png"),
            ("left half", .spiderman, "window.png"),
            ("wifi", .spiderman, "toggles.png"),
        ]
        showPanel()
        let originalTheme = settings.theme
        var delay = 0.5
        for item in cases {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.settings.theme = item.theme
                self.viewModel.query = item.query
            }
            // Give async file results a moment, then capture.
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.9) { [weak self] in
                self?.capturePanel(to: directory + "/" + item.file)
            }
            delay += 1.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.5) { [weak self] in
            self?.settings.theme = originalTheme
            NSApp.terminate(nil)
        }
    }

    private func capturePanel(to path: String) {
        guard let view = panel.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Main menu

    // An accessory app shows no menu bar, but key equivalents still dispatch
    // through the main menu; without an Edit menu, Cmd+C/V/X/A do nothing in
    // any text field (Preferences, the search bar).
    private func setUpMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "Quit Sidekick",
            action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"
        )
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status item

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateStatusIcon(settings.theme)

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open Sidekick", action: #selector(togglePanelFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Sidekick", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func updateStatusIcon(_ theme: HeroTheme) {
        statusItem?.button?.image = StatusIcons.menuBarIcon(for: theme)
    }

    // MARK: - Panel

    private func setUpPanel() {
        let contentRect = NSRect(x: 0, y: 0, width: SearchView.panelWidth, height: SearchView.barHeight)
        panel = SearchPanel(contentRect: contentRect)
        let hostingView = NSHostingView(
            rootView: SearchView(viewModel: viewModel, settings: settings)
        )
        panel.contentView = hostingView
    }

    @objc private func togglePanelFromMenu() {
        togglePanel()
    }

    func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        viewModel.reset()
        positionPanel(resultCount: 0)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        NotificationCenter.default.post(name: .spideyFocusSearch, object: nil)
    }

    func hidePanel() {
        panel.orderOut(nil)
    }

    private func panelTopY(on screen: NSScreen) -> CGFloat {
        let frame = screen.visibleFrame
        return frame.minY + frame.height * 0.78
    }

    private func positionPanel(resultCount: Int) {
        guard let screen = NSScreen.main else { return }
        let height = SearchView.panelHeight(resultCount: resultCount)
        let frame = screen.visibleFrame
        let x = frame.midX - SearchView.panelWidth / 2
        let topY = panelTopY(on: screen)
        panel.setFrame(
            NSRect(x: x, y: topY - height, width: SearchView.panelWidth, height: height),
            display: true
        )
    }

    private func resizePanel(resultCount: Int) {
        guard panel.isVisible, let screen = panel.screen ?? NSScreen.main else { return }
        let height = SearchView.panelHeight(resultCount: resultCount)
        let topY = panel.frame.maxY
        var frame = panel.frame
        frame.origin.y = topY - height
        frame.size.height = height
        _ = screen
        panel.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Hotkey

    private func registerHotKey() {
        let preferred = settings.hotKey
        if HotKeyCenter.shared.register(preferred, handler: { [weak self] in self?.togglePanel() }) {
            settings.activeHotKey = preferred
            return
        }
        // Usually means Spotlight still owns Cmd+Space; fall back to Option+Space.
        if preferred != .optionSpace,
           HotKeyCenter.shared.register(.optionSpace, handler: { [weak self] in self?.togglePanel() }) {
            settings.activeHotKey = .optionSpace
        } else {
            settings.activeHotKey = nil
        }
    }

    // MARK: - Preferences

    @objc func openPreferences() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sidekick Preferences"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - First run

    private func showFirstRunHintIfNeeded() {
        let key = "didShowSpotlightHint"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        guard settings.activeHotKey != settings.hotKey else { return }
        let alert = NSAlert()
        alert.messageText = "Sidekick is using ⌥Space for now"
        alert.informativeText = """
        Spotlight still owns ⌘Space, so Sidekick registered ⌥Space instead.

        To use ⌘Space: System Settings > Keyboard > Keyboard Shortcuts > Spotlight, untick "Show Spotlight search", then reopen Sidekick or re-pick the hotkey in Preferences.
        """
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The caffeinate child process would otherwise outlive the app.
        CaffeinateManager.shared.stop()
    }
}

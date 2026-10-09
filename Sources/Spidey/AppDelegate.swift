import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let settings = SettingsStore.shared
    let viewModel = SpideyViewModel()

    private var statusItem: NSStatusItem!
    private var menuBarPopover: NSPopover?
    private var menuBarPopoverClosedAt = Date.distantPast
    private var panel: SearchPanel!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    var showOnLaunchQuery: String?
    var snapshotDirectory: String?
    var entranceTheme: HeroTheme?
    var entranceDirectory: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setUpMainMenu()
        setUpStatusItem()
        setUpPanel()
        ClipboardStore.shared.start()
        ScreenshotWatcher.shared.start()
        registerHotKey()
        // Timers left running at the last quit are restored now, so they ring
        // with their sound on time instead of only once "timer" is typed.
        _ = TimerCenter.shared
        _ = AppProvider.shared
        FileProvider.warmUp()
        ContactIndex.shared.warmUp()
        LinkChecker.shared.startAutomaticChecks()
        if snapshotDirectory == nil, entranceDirectory == nil {
            WeatherStore.shared.start()
        }
        if snapshotDirectory == nil, entranceDirectory == nil {
            AppearanceScheduler.shared.start()
        }

        viewModel.onHide = { [weak self] in self?.hidePanel() }

        // @Published emits on willSet, so read the emitted value, not settings.hotKey.
        settings.$hotKey
            .dropFirst()
            .sink { [weak self] combo in self?.registerHotKey(preferred: combo, userPicked: true) }
            .store(in: &cancellables)
        settings.$theme
            .combineLatest(CaffeinateManager.shared.$isActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] theme, awake in self?.updateStatusIcon(theme, awake: awake) }
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

        // The Mac going to sleep is when people actually stop watching, so
        // save whichever episode is open in the browser before it goes dark.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification, object: nil, queue: .main
        ) { _ in
            WatchCapture.captureNow(timeout: 3) {}
        }

        // If we fell back (e.g. Spotlight owned Cmd+Space at launch), retry the
        // preferred combo whenever the app is brought forward - the user may
        // have freed it up in System Settings since.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.settings.activeHotKey != self.settings.hotKey else { return }
            self.registerHotKey()
        }

        showFirstRunHintIfNeeded()

        // Snapshot and entrance captures are unattended; permission dialogs
        // would hang them.
        if snapshotDirectory == nil, entranceDirectory == nil {
            SetupCenter.shared.runAtLaunch()
        }

        if let query = showOnLaunchQuery {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showPanel()
                self?.viewModel.query = query
            }
        }

        if let directory = snapshotDirectory {
            runSnapshots(into: directory)
        }

        if let theme = entranceTheme, let directory = entranceDirectory {
            runEntranceCapture(theme, into: directory)
        }
    }

    // MARK: - Entrance capture (dev only)

    private func runEntranceCapture(_ theme: HeroTheme, into directory: String) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let originalTheme = settings.theme
        ThemeAnimator.shared.play(theme)
        for (index, delay) in [0.35, 0.75, 1.1, 1.5, 1.9, 2.3, 2.7, 3.1].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                ThemeAnimator.shared.captureFrame(to: directory + "/\(theme.rawValue)-\(index).png")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) { [weak self] in
            self?.settings.theme = originalTheme
            NSApp.terminate(nil)
        }
    }

    // MARK: - Snapshots (dev only)

    private func runSnapshots(into directory: String) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let cases: [(query: String, theme: HeroTheme, file: String)] = [
            ("", .spiderman, "empty.png"),
            ("saf", .spiderman, "apps.png"),
            ("youtube lofi beats", .spiderman, "youtube.png"),
            ("death note", .spiderman, "streaming.png"),
            ("2+2*5", .spiderman, "calculator.png"),
            ("claude fix the spelling issue on my web page", .spiderman, "claude.png"),
            ("clip", .spiderman, "clipboard.png"),
            ("vinted", .spiderman, "sites.png"),
            ("netflix", .spiderman, "netflix.png"),
            ("grand seiko", .spiderman, "sites-watches.png"),
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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon(settings.theme, awake: CaffeinateManager.shared.isActive)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleMenuBarPopover)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func updateStatusIcon(_ theme: HeroTheme, awake: Bool) {
        statusItem?.button?.image = StatusIcons.menuBarIcon(for: theme, awake: awake)
        statusItem?.button?.toolTip = awake ? "Sidekick - keeping your Mac awake" : "Sidekick"
    }

    @objc private func toggleMenuBarPopover() {
        if let popover = menuBarPopover, popover.isShown {
            popover.performClose(nil)
            return
        }
        // A transient popover closes on mouse-down outside it, which includes
        // the emblem itself; without this the same click would reopen it.
        guard Date().timeIntervalSince(menuBarPopoverClosedAt) > 0.3,
              let button = statusItem.button else { return }
        // Built fresh each time so the date and next switch time are current.
        let popover = makeMenuBarPopover()
        menuBarPopover = popover
        WeatherStore.shared.refreshIfStale()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func makeMenuBarPopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.delegate = self
        popover.animates = true
        let controller = NSHostingController(rootView: MenuBarPanel(
            settings: settings,
            openPreferences: { [weak self] in
                self?.menuBarPopover?.performClose(nil)
                self?.openPreferences()
            }
        ))
        controller.sizingOptions = .preferredContentSize
        popover.contentViewController = controller
        return popover
    }

    func popoverDidClose(_ notification: Notification) {
        menuBarPopoverClosedAt = Date()
        menuBarPopover = nil
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

    func togglePanel() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        viewModel.reset()
        WatchCapture.refreshOnScreen()
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

    private func registerHotKey(preferred: HotKeyCombo? = nil, userPicked: Bool = false) {
        let preferred = preferred ?? settings.hotKey
        // A refused pick from Preferences is saved back to the working combo,
        // so the next launch does not retry it and land on Option+Space. A
        // fallback (usually Spotlight still owning Cmd+Space) keeps the choice.
        let outcome = HotKeyFallback.resolve(
            preferred: preferred, userPicked: userPicked,
            current: HotKeyCenter.shared.currentCombo,
            register: { combo in
                HotKeyCenter.shared.register(combo, handler: { [weak self] in self?.togglePanel() })
            }
        )
        settings.activeHotKey = outcome.active
        if let save = outcome.savePreferred, settings.hotKey != save { settings.hotKey = save }
    }

    // MARK: - Preferences

    @objc func openPreferences() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Sidekick Preferences"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.contentMinSize = NSSize(width: 520, height: 480)
            window.setContentSize(NSSize(width: 600, height: 720))
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

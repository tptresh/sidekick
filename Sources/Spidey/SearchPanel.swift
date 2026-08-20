import AppKit
import QuickLookUI

// Borderless floating panel that can take keyboard focus without activating the app.
// Also hosts the Quick Look plumbing: Cmd+Y (Finder's shortcut) previews the
// selected file row, and while the preview is open Space closes it again. Space
// is otherwise untouched so it always types into the query field.
final class SearchPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    // MARK: - Quick Look

    // Cmd+Y toggles the preview of the selected result's file.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown,
           event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "y" {
            QuickLookController.shared.toggle(from: self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // Hiding the launcher takes any open preview with it. All hide paths in
    // the app funnel through orderOut, so this is the single teardown hook.
    override func orderOut(_ sender: Any?) {
        QuickLookController.shared.close()
        QuickLookController.shared.deactivateIfNeeded()
        super.orderOut(sender)
    }

    // QLPreviewPanel walks the key window's responder chain looking for a
    // controller. This panel volunteers and hands the data-source/delegate
    // duties to the shared QuickLookController.
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        QuickLookController.shared.searchPanel = self
        panel.dataSource = QuickLookController.shared
        panel.delegate = QuickLookController.shared
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
        // Undo the activation the preview needed, so Spidey stops being the
        // frontmost app and providers that target it work again.
        QuickLookController.shared.deactivateIfNeeded()
        // Give the keyboard back to the query field once the preview closes
        // (whether via Space, Cmd+Y, or Esc inside the preview).
        if isVisible {
            makeKeyAndOrderFront(nil)
            NotificationCenter.default.post(name: .spideyFocusSearch, object: nil)
        }
    }
}

// Data source and delegate for the shared QLPreviewPanel: previews whichever
// selected result row is backed by a real file (dragFileURL).
final class QuickLookController: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = QuickLookController()

    // Set by SearchView so the preview can follow the live selection.
    weak var viewModel: SpideyViewModel?
    weak var searchPanel: SearchPanel?

    // URL behind the currently selected row, if the row is a file.
    private var selectedFileURL: URL? {
        guard let viewModel,
              viewModel.results.indices.contains(viewModel.selectedIndex) else { return nil }
        return viewModel.results[viewModel.selectedIndex].dragFileURL
    }

    private var isOpen: Bool {
        QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }

    // True while the app is active solely for the preview's sake.
    private var activatedForPreview = false

    func toggle(from panel: SearchPanel) {
        if isOpen {
            close()
        } else if selectedFileURL != nil {
            searchPanel = panel
            // The launcher normally never activates the app (nonactivating
            // panel), but the preview needs key status so Space, Esc, and the
            // arrows reach it.
            NSApp.activate(ignoringOtherApps: true)
            activatedForPreview = true
            QLPreviewPanel.shared().makeKeyAndOrderFront(nil)
        }
    }

    // Hands frontmost status back once the preview is gone, but only if the
    // preview was why we activated; the panel stays nonactivating otherwise.
    func deactivateIfNeeded() {
        guard activatedForPreview else { return }
        activatedForPreview = false
        NSApp.deactivate()
    }

    func close() {
        guard isOpen else { return }
        QLPreviewPanel.shared().orderOut(nil)
    }

    // Called by SearchView whenever the selection or the result list changes,
    // so an open preview always shows the row under the highlight.
    func selectionChanged() {
        guard isOpen else { return }
        let panel = QLPreviewPanel.shared()!
        panel.reloadData()
        if selectedFileURL != nil {
            panel.currentPreviewItemIndex = 0
        }
    }

    // MARK: - QLPreviewPanelDataSource

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        selectedFileURL == nil ? 0 : 1
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        selectedFileURL as NSURL?
    }

    // MARK: - QLPreviewPanelDelegate

    // While the preview is key: Space or Cmd+Y closes it, and the arrows move
    // the launcher's selection underneath (which reloads the preview through
    // selectionChanged). Esc is handled by the panel itself.
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        guard event.type == .keyDown else { return false }
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers?.lowercased() == "y" {
            close()
            return true
        }
        switch event.keyCode {
        case 49: // Space closes the open preview, Finder-style.
            close()
            return true
        case 125: // Down arrow
            viewModel?.moveSelection(by: 1)
            return true
        case 126: // Up arrow
            viewModel?.moveSelection(by: -1)
            return true
        default:
            return false
        }
    }
}

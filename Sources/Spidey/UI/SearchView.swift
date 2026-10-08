import SwiftUI
import AppKit
import UniformTypeIdentifiers

extension Notification.Name {
    static let spideyFocusSearch = Notification.Name("SpideyFocusSearch")
}

struct SearchView: View {
    @ObservedObject var viewModel: SpideyViewModel
    @ObservedObject var settings: SettingsStore
    @State private var isDropTargeted = false

    static let panelWidth: CGFloat = 640
    static let rowHeight: CGFloat = 48
    static let barHeight: CGFloat = 60
    static let maxVisibleRows = 9

    var body: some View {
        let palette = settings.theme.palette
        VStack(spacing: 0) {
            searchBar(palette: palette)
            if !viewModel.results.isEmpty {
                Rectangle()
                    .fill(palette.textPrimary.opacity(0.08))
                    .frame(height: 1)
                resultsList(palette: palette)
            }
        }
        .frame(width: Self.panelWidth)
        .background(
            ZStack {
                VisualEffectBackground(isLight: settings.theme.isLight)
                LinearGradient(
                    colors: [palette.backgroundTop.opacity(0.96), palette.background.opacity(0.97)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isDropTargeted ? palette.accent.opacity(0.8) : palette.textPrimary.opacity(0.12),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .onAppear {
            QuickLookController.shared.viewModel = viewModel
        }
        // Results can change under a fixed selection index (e.g. file results
        // arriving late), so keep any open Quick Look preview in sync. The
        // publisher fires on willSet, so hop to the next runloop tick to read
        // the settled values.
        .onReceive(viewModel.$results) { _ in
            DispatchQueue.main.async {
                QuickLookController.shared.selectionChanged()
            }
        }
    }

    private func searchBar(palette: ThemePalette) -> some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 12) {
                themeGlyph(palette: palette)
                SearchField(
                    text: $viewModel.query,
                    placeholder: placeholder,
                    palette: palette,
                    font: NSFont.systemFont(ofSize: 24, weight: .light),
                    onMove: { viewModel.moveSelection(by: $0) },
                    onEnter: { viewModel.runSelected(commandModifier: $0) },
                    onEscape: { viewModel.escapePressed() }
                )
                .frame(height: 32)
            }
            .padding(.horizontal, 18)
            .frame(height: Self.barHeight)

            if !viewModel.droppedFiles.isEmpty {
                Text("\(viewModel.droppedFiles.count) file\(viewModel.droppedFiles.count == 1 ? "" : "s") dropped")
                    .font(.caption)
                    .foregroundColor(palette.accent)
                    .padding(.trailing, 18)
            }
        }
    }

    // Sasuke carries the Rinnegan itself here, purple and ringed, instead of the
    // flat badge the menu bar has to fall back on at 18 points.
    @ViewBuilder
    private func themeGlyph(palette: ThemePalette) -> some View {
        if settings.theme == .sasuke {
            RinneganDisc(diameter: 26)
        } else {
            Image(nsImage: StatusIcons.watermark(for: settings.theme, size: 26, color: NSColor(palette.accent)))
                .resizable()
                .frame(width: 26, height: 26)
                .opacity(0.85)
        }
    }

    private var placeholder: String {
        viewModel.droppedFiles.isEmpty ? settings.theme.searchPlaceholder : "Choose an action for the dropped files"
    }

    private func resultsList(palette: ThemePalette) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, item in
                        ResultRow(
                            item: item,
                            palette: palette,
                            isSelected: index == viewModel.selectedIndex
                        )
                        .id(index)
                        .onTapGesture {
                            viewModel.selectedIndex = index
                            viewModel.runSelected(commandModifier: false)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(height: listHeight)
            .onChange(of: viewModel.selectedIndex) { index in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(index, anchor: nil)
                }
                QuickLookController.shared.selectionChanged()
            }
        }
    }

    private var listHeight: CGFloat {
        CGFloat(min(viewModel.results.count, Self.maxVisibleRows)) * Self.rowHeight + 12
    }

    static func panelHeight(resultCount: Int) -> CGFloat {
        guard resultCount > 0 else { return barHeight }
        return barHeight + 1 + CGFloat(min(resultCount, maxVisibleRows)) * rowHeight + 12
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let group = DispatchGroup()
        var urls: [URL] = []
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    urls.append(url)
                } else if let url = item as? URL {
                    urls.append(url)
                }
            }
        }
        group.notify(queue: .main) {
            viewModel.handleDrop(urls)
        }
        return !providers.isEmpty
    }
}

private struct ResultRow: View {
    let item: ResultItem
    let palette: ThemePalette
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            iconView
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(palette.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(palette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if isSelected {
                Text("↩")
                    .font(.system(size: 12))
                    .foregroundColor(palette.textSecondary.opacity(0.8))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: SearchView.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? palette.accent.opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? palette.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                )
                .padding(.horizontal, 6)
        )
        .contentShape(Rectangle())
        .modifier(DragModifier(url: item.dragFileURL))
    }

    @ViewBuilder
    private var iconView: some View {
        switch item.icon {
        case .appIcon(let image):
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 18, weight: .light))
                .foregroundColor(palette.accent.opacity(isSelected ? 1.0 : 0.85))
        }
    }
}

// Rows backed by a file can be dragged out of the panel.
private struct DragModifier: ViewModifier {
    let url: URL?

    func body(content: Content) -> some View {
        if let url {
            // contentsOf registers the file's real type (e.g. png) alongside the
            // URL, so image wells and chat apps accept the drop as a file.
            content.onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider(object: url as NSURL) }
        } else {
            content
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    let isLight: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.appearance = NSAppearance(named: isLight ? .aqua : .darkAqua)
    }
}

// NSTextField wrapper so arrows, Return, and Esc can be intercepted cleanly.
private struct SearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let palette: ThemePalette
    let font: NSFont
    let onMove: (Int) -> Void
    let onEnter: (Bool) -> Void
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = font
        field.textColor = NSColor(palette.textPrimary)
        field.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(palette.textPrimary).withAlphaComponent(0.35),
                .font: font,
            ]
        )
        field.delegate = context.coordinator
        context.coordinator.field = field
        context.coordinator.observeFocusRequests()
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Keep the coordinator's copy fresh so callbacks capture current state.
        context.coordinator.parent = self
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.font = font
        nsView.textColor = NSColor(palette.textPrimary)
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: NSColor(palette.textPrimary).withAlphaComponent(0.35),
                .font: font,
            ]
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchField
        weak var field: NSTextField?
        private var focusObserver: NSObjectProtocol?

        init(_ parent: SearchField) {
            self.parent = parent
        }

        deinit {
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
        }

        func observeFocusRequests() {
            if let focusObserver {
                NotificationCenter.default.removeObserver(focusObserver)
            }
            focusObserver = NotificationCenter.default.addObserver(
                forName: .spideyFocusSearch, object: nil, queue: .main
            ) { [weak self] _ in
                guard let field = self?.field else { return }
                field.window?.makeFirstResponder(field)
                field.currentEditor()?.selectedRange = NSRange(
                    location: field.stringValue.count, length: 0
                )
            }
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMove(-1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMove(1)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                let commandHeld = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
                parent.onEnter(commandHeld)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            case #selector(NSResponder.insertTab(_:)):
                parent.onMove(1)
                return true
            // Cmd+Return has no key binding, so it arrives as noop: rather
            // than insertNewline:.
            case Selector(("noop:")):
                guard let event = NSApp.currentEvent, event.type == .keyDown,
                      event.keyCode == 36 || event.keyCode == 76,
                      event.modifierFlags.contains(.command)
                else { return false }
                parent.onEnter(true)
                return true
            default:
                return false
            }
        }
    }
}

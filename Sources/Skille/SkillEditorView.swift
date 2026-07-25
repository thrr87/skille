import SwiftUI
import AppKit
import SkilleControl

struct SkillEditorView: View {
    let controlPlane: ControlPlane
    let skillPath: String
    let title: String
    @Binding var session: EditorSession
    var showsCloseButton: Bool = false
    var onSaved: () -> Void = {}
    var requestNavigation: (@escaping () -> Void) -> Void = { $0() }

    @State private var files: [SkillFileEntry] = []
    @State private var selected: String?
    @State private var showPreview = false
    @State private var status: String?
    @Environment(\.dismiss) private var dismiss

    private var isDirty: Bool {
        session.isDirty
    }

    var body: some View {
        HStack(spacing: 0) {
            fileSidebar
                .frame(width: 200)
            Divider()
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { requestNavigation { dismiss() } }
                        .keyboardShortcut(.cancelAction)
                }
            }
            ToolbarItemGroup(placement: .secondaryAction) {
                if isMarkdown {
                    Toggle("Preview", isOn: $showPreview)
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                        .accessibilityLabel("Toggle markdown preview")
                        .help("Toggle Markdown preview (Shift Command P)")
                }
                if case .text = session.fileKind {
                    Button("Save") { save() }
                        .keyboardShortcut("s")
                        .disabled(!isDirty)
                        .accessibilityLabel("Save file")
                        .accessibilityHint(isDirty ? "Save changes to disk" : "No unsaved changes")
                        .help("Save file (Command S)")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let footerStatus {
                Text(footerStatus)
                    .font(.caption)
                    .foregroundStyle(isDirty ? .orange : .secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.bar)
                    .accessibilityLabel(footerStatus)
            }
        }
        .onAppear { reloadTree() }
        .onChange(of: skillPath) { _, _ in
            selected = nil
            reloadTree()
        }
        .onChange(of: session.buffer) { _, _ in status = nil }
    }

    private var fileSidebar: some View {
        List(files, selection: selectedFile) { file in
            Text(file.relativePath)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .tag(file.relativePath)
                .accessibilityLabel(file.relativePath)
        }
        .listStyle(.sidebar)
        .accessibilityLabel("Skill files")
    }

    @ViewBuilder
    private var detailPane: some View {
        if selected == nil {
            ContentUnavailableView("Select a file", systemImage: "doc")
        } else {
            switch session.fileKind {
            case .text:
                if showPreview && isMarkdown {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(previewBlocks.enumerated()), id: \.offset) { _, block in
                                previewBlock(block)
                            }
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .textSelection(.enabled)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Markdown preview")
                } else {
                    TextEditor(text: $session.buffer)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .accessibilityLabel(selected ?? "File contents")
                        .accessibilityValue(session.buffer)
                        .accessibilityHint("Editable text. Press Command S to save.")
                }
            case .nonText:
                nonTextPane(message: "Binary or non-text file")
            case .tooLarge:
                nonTextPane(message: "File is too large to edit in Skille")
            }
        }
    }

    private var isMarkdown: Bool {
        (selected ?? "").lowercased().hasSuffix(".md")
    }

    private var previewBlocks: [MarkdownPreview.Block] {
        (try? MarkdownPreview.blocks(fromSkillMarkdown: session.buffer)) ?? []
    }

    @ViewBuilder
    private func previewBlock(_ block: MarkdownPreview.Block) -> some View {
        switch block.kind {
        case .heading(let level):
            Text(block.content)
                .font(headingFont(level))
                .fontWeight(.semibold)
        case .paragraph:
            Text(block.content)
                .fixedSize(horizontal: false, vertical: true)
        case .unorderedListItem:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(block.content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .orderedListItem(let ordinal):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(ordinal).")
                    .monospacedDigit()
                Text(block.content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .codeBlock:
            ScrollView(.horizontal) {
                Text(block.content)
                    .font(.system(.body, design: .monospaced))
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(10)
            }
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }
    }

    private var footerStatus: String? {
        isDirty ? "Unsaved changes" : status
    }

    private var selectedFile: Binding<String?> {
        Binding(
            get: { selected },
            set: { newValue in
                guard newValue != selected else { return }
                requestNavigation {
                    selected = newValue
                    if let newValue { load(newValue) }
                }
            }
        )
    }

    private func nonTextPane(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .foregroundStyle(.secondary)
            if let selected {
                Text(selected)
                    .font(.caption.monospaced())
            }
            HStack {
                Button("Open Externally") { openExternally() }
                Button("Reveal in Finder") { revealInFinder() }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reloadTree() {
        files = (try? controlPlane.listSkillFiles(at: skillPath)) ?? []
        let next = if let selected, files.contains(where: { $0.relativePath == selected }) {
            selected
        } else {
            files.first { $0.relativePath == "SKILL.md" }?.relativePath
                ?? files.first?.relativePath
        }
        selected = next
        if let next,
           session.skillRootPath != skillPath || session.relativePath != next
        {
            load(next)
        }
    }

    private func load(_ relative: String) {
        do {
            try session.open(skillRootPath: skillPath, relativePath: relative)
            status = nil
            showPreview = false
        } catch {
            status = error.localizedDescription
        }
    }

    private func save() {
        do {
            try session.save()
            status = "Saved"
            onSaved()
        } catch {
            status = error.localizedDescription
        }
    }

    private func openExternally() {
        guard let selected,
              let url = try? controlPlane.absoluteFileURL(skillRootPath: skillPath, relativePath: selected)
        else { return }
        NSWorkspace.shared.open(url)
    }

    private func revealInFinder() {
        guard let selected,
              let url = try? controlPlane.absoluteFileURL(skillRootPath: skillPath, relativePath: selected)
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

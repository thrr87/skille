import SwiftUI
import AppKit
import SkilleControl

struct SkillEditorView: View {
    let controlPlane: ControlPlane
    let skillPath: String
    let title: String
    var showsCloseButton: Bool = false
    var onSaved: () -> Void = {}

    @State private var files: [SkillFileEntry] = []
    @State private var selected: String?
    @State private var buffer = ""
    @State private var original = ""
    @State private var fileKind: SkillFileKind = .text("")
    @State private var showPreview = false
    @State private var status: String?
    @Environment(\.dismiss) private var dismiss

    private var isDirty: Bool {
        guard case .text = fileKind else { return false }
        return buffer != original
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
                    Button("Close") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            ToolbarItemGroup {
                if isMarkdown {
                    Toggle("Preview", isOn: $showPreview)
                        .keyboardShortcut("p", modifiers: [.command, .shift])
                        .accessibilityLabel("Toggle markdown preview")
                }
                if case .text = fileKind {
                    Button("Save") { save() }
                        .keyboardShortcut("s")
                        .disabled(!isDirty)
                        .accessibilityLabel("Save file")
                        .accessibilityHint(isDirty ? "Save changes to disk" : "No unsaved changes")
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let status {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(.bar)
                    .accessibilityLabel(status)
            }
        }
        .onAppear { reloadTree() }
        .onChange(of: selected) { _, newValue in
            if let newValue { load(newValue) }
        }
        .onChange(of: skillPath) { _, _ in
            selected = nil
            reloadTree()
        }
    }

    private var fileSidebar: some View {
        List(files, selection: $selected) { file in
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
            switch fileKind {
            case .text:
                if showPreview && isMarkdown {
                    ScrollView {
                        Text(markdownPreview)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .textSelection(.enabled)
                    }
                    .accessibilityLabel("Markdown preview")
                } else {
                    TextEditor(text: $buffer)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .background(Color(nsColor: .textBackgroundColor))
                        .accessibilityLabel(selected ?? "File contents")
                        .accessibilityValue(buffer)
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

    private var markdownPreview: AttributedString {
        (try? AttributedString(markdown: buffer)) ?? AttributedString(buffer)
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
        if selected == nil || !files.contains(where: { $0.relativePath == selected }) {
            selected = files.first { $0.relativePath == "SKILL.md" }?.relativePath
                ?? files.first?.relativePath
        }
        if let selected { load(selected) }
    }

    private func load(_ relative: String) {
        do {
            let content = try controlPlane.readTextFile(at: skillPath, relativePath: relative)
            fileKind = content.kind
            if case let .text(text) = content.kind {
                buffer = text
                original = text
            } else {
                buffer = ""
                original = ""
            }
            status = nil
            showPreview = false
        } catch {
            status = error.localizedDescription
        }
    }

    private func save() {
        guard let selected, case .text = fileKind else { return }
        do {
            try controlPlane.writeTextFile(at: skillPath, relativePath: selected, content: buffer)
            original = buffer
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

import SwiftUI
import AppKit
import SkilleControl

struct SkillEditorView: View {
    let controlPlane: ControlPlane
    let skillPath: String
    let title: String

    @State private var files: [SkillFileEntry] = []
    @State private var selected: String?
    @State private var buffer = ""
    @State private var fileKind: SkillFileKind = .text("")
    @State private var showPreview = false
    @State private var status: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationSplitView {
            List(files, selection: $selected) { file in
                Text(file.relativePath)
                    .font(.body.monospaced())
                    .tag(file.relativePath)
            }
            .navigationTitle("Files")
            .onChange(of: selected) { _, newValue in
                if let newValue { load(newValue) }
            }
        } detail: {
            detailPane
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
            ToolbarItemGroup {
                if isMarkdown {
                    Toggle("Preview", isOn: $showPreview)
                }
                if case .text = fileKind {
                    Button("Save") { save() }
                        .keyboardShortcut("s")
                }
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        .onAppear { reloadTree() }
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
                    }
                } else {
                    TextEditor(text: $buffer)
                        .font(.system(.body, design: .monospaced))
                        .padding(8)
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
            if let status {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reloadTree() {
        files = (try? controlPlane.listSkillFiles(at: skillPath)) ?? []
        if selected == nil {
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
            } else {
                buffer = ""
            }
            status = nil
        } catch {
            status = error.localizedDescription
        }
    }

    private func save() {
        guard let selected, case .text = fileKind else { return }
        do {
            try controlPlane.writeTextFile(at: skillPath, relativePath: selected, content: buffer)
            status = "Saved"
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

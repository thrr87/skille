import SwiftUI
import AppKit
import SkilleControl

struct NewSkillSheet: View {
    let controlPlane: ControlPlane
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var descriptionText = ""
    @State private var selectedRoots: Set<String> = []
    @State private var errorText: String?

    private var roots: [InstallRootOption] { controlPlane.availableInstallRoots() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Skill")
                .font(.title2.weight(.semibold))
            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $descriptionText)
                .textFieldStyle(.roundedBorder)
            Text("Skill roots")
                .font(.headline)
            SkillRootPicker(roots: roots, selection: $selectedRoots)
            .frame(minHeight: 120)
            .onAppear {
                selectedRoots = Set(roots.filter(\.isDefaultSuggestion).map(\.id))
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || selectedRoots.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480, height: 400)
    }

    private func create() {
        do {
            try controlPlane.createSkill(
                name: name,
                description: descriptionText,
                skillRootIds: Array(selectedRoots)
            )
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct SkillRootPicker: View {
    let roots: [InstallRootOption]
    @Binding var selection: Set<String>

    var body: some View {
        List(selection: $selection) {
            rootSection("Recommended", roots.filter(\.isDefaultSuggestion))
            rootSection(
                "User Skill roots",
                roots.filter { !$0.isDefaultSuggestion && $0.scope == "global" }
            )
            rootSection("Project Skill roots", roots.filter { $0.scope == "project" })
        }
    }

    @ViewBuilder
    private func rootSection(_ title: String, _ roots: [InstallRootOption]) -> some View {
        if !roots.isEmpty {
            Section(title) {
                ForEach(roots) { root in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(AdapterRegistry.displayNames(forAdapterIds: root.adapterIds))
                            if root.isDefaultSuggestion {
                                Text("recommended")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(root.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .tag(root.id)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(AdapterRegistry.displayNames(forAdapterIds: root.adapterIds)), "
                            + "\(root.scope == "project" ? "Project" : "User") Skill root, "
                            + "\(root.path)"
                            + (root.isDefaultSuggestion ? ", recommended" : "")
                    )
                }
            }
        }
    }
}

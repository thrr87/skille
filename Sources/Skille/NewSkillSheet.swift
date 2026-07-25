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
            List(roots, selection: $selectedRoots) { root in
                HStack {
                    Text(root.path).font(.body.monospaced())
                    if root.isDefaultSuggestion {
                        Text("default").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .tag(root.id)
            }
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

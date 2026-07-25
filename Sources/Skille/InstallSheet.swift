import SwiftUI
import AppKit
import SkilleControl

struct InstallSheet: View {
    let controlPlane: ControlPlane
    let sourceId: String
    var onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPackages: Set<String> = []
    @State private var selectedRoots: Set<String> = []
    @State private var errorText: String?

    private var detail: SourceDetail? { controlPlane.sourceDetail(id: sourceId) }
    private var roots: [InstallRootOption] { controlPlane.availableInstallRoots() }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Install")
                .font(.title2.weight(.semibold))
            if let detail {
                Text(detail.summary.displayName)
                    .foregroundStyle(.secondary)
                Text("Packages")
                    .font(.headline)
                List(detail.packages, selection: $selectedPackages) { pkg in
                    Text("\(pkg.displayName) (\(pkg.pathInRepo))")
                        .tag(pkg.pathInRepo)
                }
                .frame(minHeight: 120)
                Text("Skill roots")
                    .font(.headline)
                List(roots, selection: $selectedRoots) { root in
                    HStack {
                        Text(root.path).font(.body.monospaced())
                        if root.isDefaultSuggestion {
                            Text("default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(root.id)
                }
                .frame(minHeight: 100)
                .onAppear {
                    selectedRoots = Set(roots.filter(\.isDefaultSuggestion).map(\.id))
                    if selectedRoots.isEmpty, let first = roots.first {
                        selectedRoots = [first.id]
                    }
                }
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Install") { perform() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedPackages.isEmpty || selectedRoots.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 480)
    }

    private func perform() {
        do {
            try controlPlane.install(
                sourceId: sourceId,
                packagePaths: Array(selectedPackages),
                skillRootIds: Array(selectedRoots)
            )
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

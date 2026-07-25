import SwiftUI
import SkilleControl

struct AttachSourceSheet: View {
    let controlPlane: ControlPlane
    let locationId: String
    var suggestedURL: String?
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var branch = "main"
    @State private var pathInRepo = ""
    @State private var errorText: String?
    @State private var joinName: String?
    @State private var usedSuggestion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Attach Source")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Bind a git URL and path so this orphan can receive updates. Nothing is tracked until you confirm.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField("Git URL", text: $url)
                .textFieldStyle(.roundedBorder)
            if let suggestedURL, !usedSuggestion {
                Button("Use detected origin: \(suggestedURL)") {
                    url = suggestedURL
                    usedSuggestion = true
                }
                .font(.caption)
            }
            TextField("Branch", text: $branch)
                .textFieldStyle(.roundedBorder)
            TextField("Path in repo", text: $pathInRepo)
                .textFieldStyle(.roundedBorder)
            if let joinName {
                Text("This will join existing skill “\(joinName)”. Confirm to continue.")
                    .foregroundStyle(.orange)
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button(joinName == nil ? "Attach" : "Confirm join") { attach() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(
                        url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || pathInRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            // Suggestion is opt-in via button — never pre-filled (no silent track).
        }
    }

    private func attach() {
        do {
            let preview = try controlPlane.previewAttachSource(
                locationId: locationId,
                url: url,
                branch: branch.isEmpty ? "main" : branch,
                pathInRepo: pathInRepo
            )
            if case let .joinExisting(_, name) = preview, joinName == nil {
                joinName = name
                return
            }
            try controlPlane.attachSource(
                locationId: locationId,
                url: url,
                branch: branch.isEmpty ? "main" : branch,
                pathInRepo: pathInRepo,
                confirmJoin: joinName != nil
            )
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

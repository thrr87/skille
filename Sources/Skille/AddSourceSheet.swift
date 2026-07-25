import SwiftUI
import AppKit
import SkilleControl

struct AddSourceSheet: View {
    var onAdd: (String, String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var branch = "main"
    @State private var isAdding = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Skill Source")
                .font(.title2.weight(.semibold))
            TextField("Git URL", text: $url)
                .textFieldStyle(.roundedBorder)
                .disabled(isAdding)
            TextField("Branch", text: $branch)
                .textFieldStyle(.roundedBorder)
                .disabled(isAdding)
            if isAdding {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching and discovering packages…")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Fetching source and discovering packages")
            }
            if let errorText {
                Text(errorText)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Add Source error: \(errorText)")
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isAdding)
                Button(isAdding ? "Adding…" : "Add") { add() }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    isAdding || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func add() {
        guard !isAdding else { return }
        isAdding = true
        errorText = nil
        Task {
            do {
                try await onAdd(url, branch.isEmpty ? "main" : branch)
                dismiss()
            } catch {
                errorText = error.localizedDescription
            }
            isAdding = false
        }
    }
}

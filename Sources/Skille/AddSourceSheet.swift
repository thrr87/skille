import SwiftUI
import AppKit
import SkilleControl

struct AddSourceSheet: View {
    var onAdd: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var branch = "main"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Skill Source")
                .font(.title2.weight(.semibold))
            TextField("Git URL", text: $url)
                .textFieldStyle(.roundedBorder)
            TextField("Branch", text: $branch)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    onAdd(url, branch.isEmpty ? "main" : branch)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 440)
    }
}

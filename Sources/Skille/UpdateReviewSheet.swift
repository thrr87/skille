import SwiftUI
import SkilleControl

struct UpdateReviewSheet: View {
    let controlPlane: ControlPlane
    let review: UpdateReview
    var onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?
    @State private var expanded = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update review")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(review.onDiskPath)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            if review.isDirty {
                Text("Local edits detected. Accept is blocked until you Discard local & apply.")
                    .foregroundStyle(.orange)
            }
            List {
                ForEach(review.files) { file in
                    DisclosureGroup(isExpanded: Binding(
                        get: { expanded.contains(file.relativePath) },
                        set: { open in
                            if open { expanded.insert(file.relativePath) }
                            else { expanded.remove(file.relativePath) }
                        }
                    )) {
                        if let diff = file.textDiff {
                            Text(diff)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        } else {
                            Text(binaryCaption(file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack {
                            Text(file.relativePath)
                                .font(.body.monospaced())
                            Spacer()
                            Text(file.status.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Reject") {
                    try? controlPlane.rejectUpdate(locationId: review.locationId)
                    dismiss()
                }
                if review.isDirty {
                    Button("Discard local & apply") { accept(discard: true) }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Accept") { accept(discard: false) }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 640, height: 480)
    }

    private func binaryCaption(_ file: UpdateFileChange) -> String {
        let old = file.oldByteSize.map(String.init) ?? "—"
        let new = file.newByteSize.map(String.init) ?? "—"
        return "Binary · \(file.status.rawValue) · \(old) → \(new) bytes"
    }

    private func accept(discard: Bool) {
        do {
            try controlPlane.acceptUpdate(locationId: review.locationId, discardLocal: discard)
            onDone()
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}

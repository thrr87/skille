import SwiftUI
import AppKit
import SkilleControl

struct UpdateChecklistSheet: View {
    let controlPlane: ControlPlane
    let sourceId: String
    var onContinue: ([UpdateReview]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var items: [UpdateChecklistItem] = []
    @State private var selected: Set<String> = []
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Update checklist")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("Select locations with updates to review one by one.")
                .foregroundStyle(.secondary)
            if items.isEmpty {
                Text("No updates available for this source.")
                    .foregroundStyle(.secondary)
            } else {
                List(items, selection: $selected) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.displayName).font(.body.weight(.medium))
                            Text(item.onDiskPath).font(.caption.monospaced())
                        }
                        Spacer()
                        if item.isDirty {
                            Text("Dirty").font(.caption).foregroundStyle(.orange)
                                .accessibilityLabel("Local edits")
                        }
                    }
                    .tag(item.locationId)
                }
                .frame(minHeight: 180)
            }
            if let errorText {
                Text(errorText).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Continue") { continueReviews() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520, height: 400)
        .onAppear {
            items = (try? controlPlane.locationsNeedingUpdate(sourceId: sourceId)) ?? []
            selected = Set(items.map(\.locationId))
        }
    }

    private func continueReviews() {
        do {
            let reviews = try controlPlane.prepareUpdateReviews(locationIds: Array(selected))
            dismiss()
            onContinue(reviews)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

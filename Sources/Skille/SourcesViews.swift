import SwiftUI
import AppKit
import SkilleControl

struct SourcesHome: View {
    let controlPlane: ControlPlane
    let sources: [SkillSourceSummary]
    @Binding var selection: String?
    var onAddSource: () -> Void
    var onInstall: (String) -> Void
    var onUpdateChecklist: (String) -> Void

    var body: some View {
        if sources.isEmpty {
            ContentUnavailableView {
                Label("No sources", systemImage: "shippingbox")
            } description: {
                Text("Add a git Skill Source to list packages and install later.")
            } actions: {
                Button("Add Source", action: onAddSource)
            }
        } else {
            NavigationSplitView {
                List(sources, selection: $selection) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.displayName)
                                .font(.body.weight(.medium))
                            Text("\(source.branch) · \(source.normalizedUrl)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if source.hasUpdate {
                            Text("Update")
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2), in: Capsule())
                        }
                    }
                    .tag(source.id)
                }
                .navigationTitle("Sources")
            } detail: {
                if let selection, let detail = controlPlane.sourceDetail(id: selection) {
                    SourceInspector(
                        detail: detail,
                        onInstall: { onInstall(selection) },
                        onUpdate: { onUpdateChecklist(selection) }
                    )
                } else {
                    ContentUnavailableView(
                        "Select a source",
                        systemImage: "shippingbox",
                        description: Text("Packages in the repo appear here.")
                    )
                }
            }
        }
    }
}

struct SourceInspector: View {
    let detail: SourceDetail
    var onInstall: () -> Void
    var onUpdate: () -> Void

    var body: some View {
        List {
            Section {
                LabeledContent("URL", value: detail.summary.normalizedUrl)
                LabeledContent("Branch", value: detail.summary.branch)
            }
            Section("Packages") {
                ForEach(detail.packages) { pkg in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pkg.displayName)
                                .font(.body.weight(.medium))
                            Text(pkg.pathInRepo)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pkg.installStatus == .notInstalled ? "Not installed" : "Installed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Button("Install…", action: onInstall)
                Button("Update…", action: onUpdate)
                    .disabled(!detail.summary.hasUpdate)
            }
        }
        .navigationTitle(detail.summary.displayName)
    }
}

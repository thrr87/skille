import SwiftUI
import SkilleControl

/// Main window: Sources | Skills | Projects. Skills is home.
struct LibraryShell: View {
    let controlPlane: ControlPlane
    @State private var tab: LibraryTab = .skills
    @State private var skills: [SkillSummary] = []
    @State private var selectedSkillID: String?
    @State private var toast: String?
    @State private var isScanning = false

    var body: some View {
        TabView(selection: $tab) {
            SourcesStub()
                .tabItem { Label("Sources", systemImage: "shippingbox") }
                .tag(LibraryTab.sources)
            SkillsHome(
                controlPlane: controlPlane,
                skills: skills,
                selection: $selectedSkillID
            )
                .tabItem { Label("Skills", systemImage: "square.stack.3d.up") }
                .tag(LibraryTab.skills)
            ProjectsStub()
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(LibraryTab.projects)
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItemGroup {
                Button("Scan") { runScan(manual: true) }
                    .disabled(isScanning)
                Button("Add Source") {}
                    .disabled(true)
                Button("New Skill") {}
                    .disabled(true)
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { runScan(manual: false) }
    }

    private func runScan(manual: Bool) {
        isScanning = true
        defer { isScanning = false }
        do {
            let result = try controlPlane.scan()
            skills = controlPlane.listSkills()
            if let selectedSkillID, !skills.contains(where: { $0.id == selectedSkillID }) {
                self.selectedSkillID = nil
            }
            if result.inventoryChanged || manual {
                let message: String
                if result.skillsFound == 0 {
                    message = result.detectedAdapterIds.isEmpty
                        ? "Scan finished — no adapters or skills found"
                        : "Scan finished — no skills in \(result.detectedAdapterIds.count) adapters"
                } else {
                    message = "Found \(result.skillsFound) skill\(result.skillsFound == 1 ? "" : "s") across \(result.rootsFound) root\(result.rootsFound == 1 ? "" : "s")"
                }
                showToast(message)
            }
        } catch {
            showToast("Scan failed: \(error.localizedDescription)")
        }
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeIn(duration: 0.15)) { toast = nil }
        }
    }
}

private enum LibraryTab: Hashable {
    case sources, skills, projects
}

struct SkillsHome: View {
    let controlPlane: ControlPlane
    let skills: [SkillSummary]
    @Binding var selection: String?

    var body: some View {
        if skills.isEmpty {
            SkillsEmptyState()
        } else {
            NavigationSplitView {
                List(skills, selection: $selection) { skill in
                    SkillRow(skill: skill)
                        .tag(skill.id)
                }
                .navigationTitle("Skills")
            } detail: {
                if let selection, let detail = controlPlane.skillDetail(id: selection) {
                    SkillInspector(detail: detail)
                } else {
                    ContentUnavailableView(
                        "Select a skill",
                        systemImage: "square.stack.3d.up",
                        description: Text("Locations and actions appear here.")
                    )
                }
            }
        }
    }
}

struct SkillInspector: View {
    let detail: SkillDetail

    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: detail.summary.displayName)
                LabeledContent("Locations", value: "\(detail.summary.locationCount)")
                if detail.summary.isOrphan {
                    LabeledContent("Status", value: "Orphan")
                }
                if detail.summary.hasUpdate {
                    LabeledContent("Update", value: "Available")
                }
                if detail.summary.isDirty {
                    LabeledContent("Dirty", value: "Local edits")
                }
            }
            Section("Locations") {
                ForEach(detail.locations) { loc in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(loc.onDiskPath)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                        Text(rootCaption(loc))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                Button("Edit") {}
                    .disabled(true)
                if detail.summary.isOrphan {
                    Button("Attach Source…") {}
                        .disabled(true)
                } else {
                    Button("Update…") {}
                        .disabled(true)
                }
            }
        }
        .navigationTitle(detail.summary.displayName)
    }

    private func rootCaption(_ loc: LocationSummary) -> String {
        let adapters = loc.adapterIds.isEmpty ? "shared root" : loc.adapterIds.joined(separator: ", ")
        return "\(loc.skillRootPath) · \(adapters)"
    }
}

struct SkillRow: View {
    let skill: SkillSummary

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.body.weight(.medium))
                if skill.isOrphan {
                    Text("Orphan")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(skill.locationCount)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15), in: Capsule())
                .accessibilityLabel("\(skill.locationCount) locations")
        }
        .padding(.vertical, 2)
    }
}

struct SkillsEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No skills yet")
                    .font(.title2.weight(.semibold))
                Text("Scan finds skills already on disk, or add a Skill Source and a Project to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            HStack(spacing: 12) {
                Button("Add Source") {}
                    .disabled(true)
                Button("Add Project") {}
                    .disabled(true)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct SourcesStub: View {
    var body: some View {
        ContentUnavailableView(
            "Sources",
            systemImage: "shippingbox",
            description: Text("Add a Skill Source to install from git.")
        )
    }
}

private struct ProjectsStub: View {
    var body: some View {
        ContentUnavailableView(
            "Projects",
            systemImage: "folder",
            description: Text("Add a project folder to include its skill roots.")
        )
    }
}

#Preview {
    LibraryShell(
        controlPlane: try! ControlPlane(
            sidecarRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("skille-preview")
        )
    )
}

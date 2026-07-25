import SwiftUI
import AppKit
import SkilleControl

/// Main window: Sources | Skills | Projects. Skills is home.
struct LibraryShell: View {
    let controlPlane: ControlPlane
    @State private var tab: LibraryTab = .skills
    @State private var skills: [SkillSummary] = []
    @State private var sources: [SkillSourceSummary] = []
    @State private var selectedSkillID: String?
    @State private var selectedSourceID: String?
    @State private var toast: String?
    @State private var isScanning = false
    @State private var showAddSource = false
    @State private var showNewSkill = false
    @State private var installSourceID: String?
    @State private var checklistSourceID: String?
    @State private var reviewQueue: [UpdateReview] = []
    @State private var activeReview: UpdateReview?

    var body: some View {
        TabView(selection: $tab) {
            SourcesHome(
                controlPlane: controlPlane,
                sources: sources,
                selection: $selectedSourceID,
                onAddSource: { showAddSource = true },
                onInstall: { installSourceID = $0 },
                onUpdateChecklist: { checklistSourceID = $0 }
            )
                .tabItem { Label("Sources", systemImage: "shippingbox") }
                .tag(LibraryTab.sources)
            SkillsHome(
                controlPlane: controlPlane,
                skills: skills,
                selection: $selectedSkillID,
                onAddProject: { addProject() },
                onAddSource: { showAddSource = true },
                onInventoryChanged: {
                    skills = controlPlane.listSkills()
                    sources = controlPlane.listSources()
                }
            )
                .tabItem { Label("Skills", systemImage: "square.stack.3d.up") }
                .tag(LibraryTab.skills)
            ProjectsTab(controlPlane: controlPlane, onChanged: { runScan(manual: true) })
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(LibraryTab.projects)
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItemGroup {
                Button("Scan") { runScan(manual: true) }
                    .disabled(isScanning)
                Button("Add Source") { showAddSource = true }
                Button("New Skill") { showNewSkill = true }
            }
        }
        .sheet(isPresented: $showAddSource) {
            AddSourceSheet { url, branch in
                addSource(url: url, branch: branch)
            }
        }
        .sheet(isPresented: $showNewSkill) {
            NewSkillSheet(controlPlane: controlPlane) {
                runScan(manual: true)
                showToast("Skill created")
            }
        }
        .sheet(isPresented: Binding(
            get: { installSourceID != nil },
            set: { if !$0 { installSourceID = nil } }
        )) {
            if let installSourceID {
                InstallSheet(controlPlane: controlPlane, sourceId: installSourceID) {
                    runScan(manual: true)
                    skills = controlPlane.listSkills()
                    sources = controlPlane.listSources()
                    showToast("Install complete")
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { checklistSourceID != nil },
            set: { if !$0 { checklistSourceID = nil } }
        )) {
            if let checklistSourceID {
                UpdateChecklistSheet(controlPlane: controlPlane, sourceId: checklistSourceID) { reviews in
                    reviewQueue = reviews
                    activeReview = reviewQueue.first
                }
            }
        }
        .sheet(item: $activeReview) { review in
            UpdateReviewSheet(controlPlane: controlPlane, review: review) {
                skills = controlPlane.listSkills()
                sources = controlPlane.listSources()
                if !reviewQueue.isEmpty {
                    reviewQueue.removeFirst()
                }
                activeReview = reviewQueue.first
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
            _ = try? controlPlane.checkUpdates()
            skills = controlPlane.listSkills()
            sources = controlPlane.listSources()
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

    private func addProject() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try controlPlane.addProject(path: url.path)
            runScan(manual: true)
        } catch {
            showToast("Could not add project: \(error.localizedDescription)")
        }
    }

    private func addSource(url: String, branch: String) {
        do {
            let source = try controlPlane.addSource(url: url, branch: branch)
            sources = controlPlane.listSources()
            selectedSourceID = source.id
            tab = .sources
            showToast("Fetched \(source.displayName)")
        } catch {
            showToast("Add Source failed: \(error.localizedDescription)")
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
    var onAddProject: () -> Void = {}
    var onAddSource: () -> Void = {}
    var onInventoryChanged: () -> Void = {}

    var body: some View {
        if skills.isEmpty {
            SkillsEmptyState(onAddProject: onAddProject, onAddSource: onAddSource)
        } else {
            NavigationSplitView {
                List(skills, selection: $selection) { skill in
                    SkillRow(skill: skill)
                        .tag(skill.id)
                }
                .navigationTitle("Skills")
            } detail: {
                if let selection, let detail = controlPlane.skillDetail(id: selection) {
                    SkillInspector(
                        detail: detail,
                        controlPlane: controlPlane,
                        onInventoryChanged: onInventoryChanged
                    )
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
    let controlPlane: ControlPlane
    var onInventoryChanged: () -> Void = {}
    @State private var editorPath: String?
    @State private var showLocationChooser = false
    @State private var reviewLocationId: String?
    @State private var updateChooser = false
    @State private var showAttachSource = false

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
                Button("Edit") { startEdit() }
                if detail.summary.isOrphan {
                    Button("Attach Source…") { showAttachSource = true }
                } else {
                    Button("Update…") { startUpdate() }
                        .disabled(!detail.summary.hasUpdate && !detail.summary.isDirty)
                }
            }
        }
        .navigationTitle(detail.summary.displayName)
        .sheet(item: $editorPath) { path in
            SkillEditorView(
                controlPlane: controlPlane,
                skillPath: path,
                title: detail.summary.displayName
            )
        }
        .sheet(isPresented: $showAttachSource) {
            AttachSourceSheet(
                controlPlane: controlPlane,
                locationId: detail.summary.id,
                suggestedURL: controlPlane.suggestedGitOrigin(
                    forLocationPath: detail.locations.first?.onDiskPath ?? ""
                )
            ) {
                onInventoryChanged()
            }
        }
        .sheet(isPresented: Binding(
            get: { reviewLocationId != nil },
            set: { if !$0 { reviewLocationId = nil } }
        )) {
            if let reviewLocationId,
               let review = try? controlPlane.prepareUpdateReview(locationId: reviewLocationId)
            {
                UpdateReviewSheet(controlPlane: controlPlane, review: review) {
                    onInventoryChanged()
                }
            }
        }
        .confirmationDialog("Edit which location?", isPresented: $showLocationChooser) {
            ForEach(detail.locations) { loc in
                Button(loc.onDiskPath) { editorPath = loc.onDiskPath }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Update which location?", isPresented: $updateChooser) {
            ForEach(detail.locations) { loc in
                Button(loc.onDiskPath) { reviewLocationId = loc.id }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func startEdit() {
        if detail.locations.count == 1 {
            editorPath = detail.locations[0].onDiskPath
        } else if detail.locations.count > 1 {
            showLocationChooser = true
        }
    }

    private func startUpdate() {
        if detail.locations.count == 1 {
            reviewLocationId = detail.locations[0].id
        } else if detail.locations.count > 1 {
            updateChooser = true
        }
    }

    private func rootCaption(_ loc: LocationSummary) -> String {
        let adapters = loc.adapterIds.isEmpty ? "shared root" : loc.adapterIds.joined(separator: ", ")
        return "\(loc.skillRootPath) · \(adapters)"
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}

extension UpdateReview: Identifiable {
    public var id: String { locationId }
}

struct SkillRow: View {
    let skill: SkillSummary

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.displayName)
                    .font(.body.weight(.medium))
                HStack(spacing: 6) {
                    if skill.isOrphan {
                        Text("Orphan")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if skill.isFromProject {
                        Text("Project")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                    }
                    if skill.hasUpdate {
                        Text("Update")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                    }
                    if skill.isDirty {
                        Text("Dirty")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.red.opacity(0.15), in: Capsule())
                    }
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
    var onAddProject: () -> Void = {}
    var onAddSource: () -> Void = {}

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
                Button("Add Source", action: onAddSource)
                Button("Add Project", action: onAddProject)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
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

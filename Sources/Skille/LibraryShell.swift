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
    @State private var skillFilter = ""

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
                .accessibilityLabel("Sources tab")
            SkillsHome(
                controlPlane: controlPlane,
                skills: filteredSkills,
                selection: $selectedSkillID,
                filter: $skillFilter,
                onAddProject: { addProject() },
                onAddSource: { showAddSource = true },
                onInventoryChanged: {
                    skills = controlPlane.listSkills()
                    sources = controlPlane.listSources()
                }
            )
                .tabItem { Label("Skills", systemImage: "square.stack.3d.up") }
                .tag(LibraryTab.skills)
                .accessibilityLabel("Skills tab")
            ProjectsTab(controlPlane: controlPlane, onChanged: { runScan(manual: true) })
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(LibraryTab.projects)
                .accessibilityLabel("Projects tab")
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItemGroup {
                Button("Scan") { runScan(manual: true) }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(isScanning)
                    .accessibilityLabel("Scan skill roots")
                Button("Add Source") { showAddSource = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    .accessibilityLabel("Add skill source")
                Button("New Skill") { showNewSkill = true }
                    .keyboardShortcut("n", modifiers: [.command])
                    .accessibilityLabel("Create new skill")
            }
        }
        .background(
            Group {
                Button("") { tab = .sources }.keyboardShortcut("1", modifiers: [.command]).opacity(0)
                Button("") { tab = .skills }.keyboardShortcut("2", modifiers: [.command]).opacity(0)
                Button("") { tab = .projects }.keyboardShortcut("3", modifiers: [.command]).opacity(0)
            }
        )
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
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .task { runScan(manual: false) }
    }

    private var filteredSkills: [SkillSummary] {
        let query = skillFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return skills }
        return skills.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
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
    @Binding var filter: String
    var onAddProject: () -> Void = {}
    var onAddSource: () -> Void = {}
    var onInventoryChanged: () -> Void = {}

    var body: some View {
        if skills.isEmpty && filter.isEmpty {
            SkillsEmptyState(onAddProject: onAddProject, onAddSource: onAddSource)
        } else {
            NavigationSplitView {
                List(skills, selection: $selection) { skill in
                    SkillRow(skill: skill)
                        .tag(skill.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(skillAccessibilityLabel(skill))
                        .accessibilityHint("Shows skill contents in the detail pane")
                }
                .navigationTitle("Skills")
                .searchable(text: $filter, prompt: "Filter skills")
                .accessibilityLabel("Skills list")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            } detail: {
                if let selection, let detail = controlPlane.skillDetail(id: selection) {
                    SkillInspector(
                        detail: detail,
                        controlPlane: controlPlane,
                        onInventoryChanged: onInventoryChanged
                    )
                } else {
                    ContentUnavailableView(
                        filter.isEmpty ? "Select a skill" : "No matching skills",
                        systemImage: "square.stack.3d.up",
                        description: Text(
                            filter.isEmpty
                                ? "SKILL.md opens here for reading and editing."
                                : "Try a different filter."
                        )
                    )
                }
            }
        }
    }

    private func skillAccessibilityLabel(_ skill: SkillSummary) -> String {
        var parts = [skill.displayName]
        if !skill.adapterIds.isEmpty {
            parts.append("used by \(AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds))")
        }
        if skill.isOrphan { parts.append("no git source") }
        if skill.hasUpdate { parts.append("update available") }
        if skill.isDirty { parts.append("local edits") }
        if skill.locationCount > 1 {
            parts.append("\(skill.locationCount) on-disk locations")
        }
        return parts.joined(separator: ", ")
    }
}

struct SkillInspector: View {
    let detail: SkillDetail
    let controlPlane: ControlPlane
    var onInventoryChanged: () -> Void = {}

    @State private var activeLocationPath: String?
    @State private var reviewLocationId: String?
    @State private var updateChooser = false
    @State private var showAttachSource = false

    var body: some View {
        VStack(spacing: 0) {
            inspectorHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)
            Divider()
            if let path = resolvedLocationPath {
                SkillEditorView(
                    controlPlane: controlPlane,
                    skillPath: path,
                    title: detail.summary.displayName,
                    onSaved: onInventoryChanged
                )
            } else {
                ContentUnavailableView(
                    "No location",
                    systemImage: "folder",
                    description: Text("This skill has no on-disk location.")
                )
            }
        }
        .navigationTitle(detail.summary.displayName)
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
        .confirmationDialog("Update which location?", isPresented: $updateChooser) {
            ForEach(detail.locations) { loc in
                Button(loc.onDiskPath) { reviewLocationId = loc.id }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { syncActiveLocation() }
        .onChange(of: detail.summary.id) { _, _ in syncActiveLocation() }
    }

    private var resolvedLocationPath: String? {
        if let activeLocationPath,
           detail.locations.contains(where: { $0.onDiskPath == activeLocationPath })
        {
            return activeLocationPath
        }
        return detail.locations.first?.onDiskPath
    }

    private var inspectorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Text(detail.summary.displayName)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if detail.summary.isOrphan {
                    Button("Attach Source…") { showAttachSource = true }
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: [.command, .shift])
                        .help("Link a git URL so Skille can check for updates")
                } else {
                    Button("Update…") { startUpdate() }
                        .controlSize(.small)
                        .disabled(!detail.summary.hasUpdate && !detail.summary.isDirty)
                        .keyboardShortcut("u", modifiers: [.command, .shift])
                }
            }

            if !detail.summary.adapterIds.isEmpty {
                Text("Used by \(AdapterRegistry.displayNames(forAdapterIds: detail.summary.adapterIds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        "Used by \(AdapterRegistry.displayNames(forAdapterIds: detail.summary.adapterIds))"
                    )
            }

            HStack(spacing: 6) {
                if detail.summary.isOrphan {
                    Text("No source")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Discovered on disk without a tracked git source. Attach Source to enable updates.")
                }
                if detail.summary.hasUpdate {
                    Text("Update").font(.caption2).foregroundStyle(.orange)
                }
                if detail.summary.isDirty {
                    Text("Dirty").font(.caption2).foregroundStyle(.red)
                }
                if detail.locations.count > 1 {
                    Picker("Location", selection: locationSelection) {
                        ForEach(detail.locations) { loc in
                            Text(shortLocationLabel(loc)).tag(Optional(loc.onDiskPath))
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .accessibilityLabel("Skill location")
                } else if let loc = detail.locations.first {
                    Text(loc.onDiskPath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .accessibilityLabel("On disk path \(loc.onDiskPath)")
                }
            }
        }
    }

    private var locationSelection: Binding<String?> {
        Binding(
            get: { resolvedLocationPath },
            set: { activeLocationPath = $0 }
        )
    }

    private func syncActiveLocation() {
        if activeLocationPath == nil
            || !detail.locations.contains(where: { $0.onDiskPath == activeLocationPath })
        {
            activeLocationPath = detail.locations.first?.onDiskPath
        }
    }

    private func startUpdate() {
        if detail.locations.count == 1 {
            reviewLocationId = detail.locations[0].id
        } else if detail.locations.count > 1 {
            updateChooser = true
        }
    }

    private func shortLocationLabel(_ loc: LocationSummary) -> String {
        let adapters = loc.adapterIds.isEmpty
            ? "shared root"
            : AdapterRegistry.displayNames(forAdapterIds: loc.adapterIds)
        return "\(loc.onDiskPath) · \(adapters)"
    }
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
                if !skill.adapterIds.isEmpty {
                    Text(AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if skill.isOrphan {
                    Text("No source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    if skill.isOrphan && !skill.adapterIds.isEmpty {
                        Text("No source")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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
            Spacer(minLength: 4)
            if skill.locationCount > 1 {
                Text("\(skill.locationCount)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .help("\(skill.locationCount) on-disk copies")
                    .accessibilityLabel("\(skill.locationCount) on-disk locations")
            } else if !skill.adapterIds.isEmpty {
                Text("\(skill.adapterIds.count)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .help(AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds))
                    .accessibilityLabel(
                        "\(skill.adapterIds.count) agents: \(AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds))"
                    )
            }
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
                .accessibilityHidden(true)
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

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
    @State private var installSourceID: String?

    var body: some View {
        TabView(selection: $tab) {
            SourcesHome(
                controlPlane: controlPlane,
                sources: sources,
                selection: $selectedSourceID,
                onAddSource: { showAddSource = true },
                onInstall: { installSourceID = $0 }
            )
                .tabItem { Label("Sources", systemImage: "shippingbox") }
                .tag(LibraryTab.sources)
            SkillsHome(
                controlPlane: controlPlane,
                skills: skills,
                selection: $selectedSkillID,
                onAddProject: { addProject() },
                onAddSource: { showAddSource = true }
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
                Button("New Skill") {}
                    .disabled(true)
            }
        }
        .sheet(isPresented: $showAddSource) {
            AddSourceSheet { url, branch in
                addSource(url: url, branch: branch)
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

private struct ProjectsTab: View {
    let controlPlane: ControlPlane
    var onChanged: () -> Void
    @State private var projects: [ProjectRecord] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button("Add…") { add() }
            }
            .padding(16)
            if projects.isEmpty {
                ContentUnavailableView(
                    "No projects",
                    systemImage: "folder",
                    description: Text("Add a project folder to include its skill roots in Scan.")
                )
            } else {
                List {
                    ForEach(projects) { project in
                        HStack {
                            Text(project.rootPath)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                            Spacer()
                            Button("Remove", role: .destructive) {
                                remove(project)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        projects = controlPlane.listProjects()
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? controlPlane.addProject(path: url.path)
        reload()
        onChanged()
    }

    private func remove(_ project: ProjectRecord) {
        try? controlPlane.removeProject(id: project.id)
        reload()
        onChanged()
    }
}

private struct SourcesHome: View {
    let controlPlane: ControlPlane
    let sources: [SkillSourceSummary]
    @Binding var selection: String?
    var onAddSource: () -> Void
    var onInstall: (String) -> Void

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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.displayName)
                            .font(.body.weight(.medium))
                        Text("\(source.branch) · \(source.normalizedUrl)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(source.id)
                }
                .navigationTitle("Sources")
            } detail: {
                if let selection, let detail = controlPlane.sourceDetail(id: selection) {
                    SourceInspector(detail: detail, onInstall: { onInstall(selection) })
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

private struct SourceInspector: View {
    let detail: SourceDetail
    var onInstall: () -> Void

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
                Button("Update…") {}
                    .disabled(true)
            }
        }
        .navigationTitle(detail.summary.displayName)
    }
}

private struct InstallSheet: View {
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

private struct AddSourceSheet: View {
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

#Preview {
    LibraryShell(
        controlPlane: try! ControlPlane(
            sidecarRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("skille-preview")
        )
    )
}

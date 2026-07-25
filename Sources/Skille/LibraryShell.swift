import SwiftUI
import AppKit
import SkilleControl

/// Main window: Sources | Skills | Projects. Skills is home.
struct LibraryShell: View {
    let controlPlane: ControlPlane
    @State private var editorSession: EditorSession
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
    @State private var skillQuery = SkillLibraryQuery()
    @State private var pendingNavigation: (() -> Void)?
    @State private var navigationError: String?

    init(controlPlane: ControlPlane) {
        self.controlPlane = controlPlane
        _editorSession = State(initialValue: EditorSession(controlPlane: controlPlane))
    }

    var body: some View {
        TabView(selection: guardedTab) {
            SourcesHome(
                controlPlane: controlPlane,
                sources: sources,
                selection: $selectedSourceID,
                onAddSource: { showAddSource = true },
                onInstall: { installSourceID = $0 },
                onUpdateChecklist: { checklistSourceID = $0 }
            )
                .tabItem {
                    Label("Sources", systemImage: "shippingbox")
                        .accessibilityValue(tab == .sources ? "Selected" : "")
                        .help("Sources (Command 1)")
                }
                .tag(LibraryTab.sources)
            SkillsHome(
                controlPlane: controlPlane,
                skills: skills,
                selection: guardedSkillSelection,
                query: $skillQuery,
                editorSession: $editorSession,
                onAddProject: { addProject() },
                onAddSource: { showAddSource = true },
                onInventoryChanged: {
                    skills = controlPlane.listSkills()
                    sources = controlPlane.listSources()
                },
                requestNavigation: requestNavigation
            )
                .tabItem {
                    Label("Skills", systemImage: "square.stack.3d.up")
                        .accessibilityValue(tab == .skills ? "Selected" : "")
                        .help("Skills (Command 2)")
                }
                .tag(LibraryTab.skills)
            ProjectsTab(controlPlane: controlPlane, onChanged: { runScan(manual: true) })
                .tabItem {
                    Label("Projects", systemImage: "folder")
                        .accessibilityValue(tab == .projects ? "Selected" : "")
                        .help("Projects (Command 3)")
                }
                .tag(LibraryTab.projects)
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Scan") {
                    runScan(manual: true)
                }
                    .keyboardShortcut("r", modifiers: [.command])
                    .disabled(isScanning)
                    .accessibilityLabel("Scan skill roots")
                    .help("Scan skill roots (Command R)")
            }
            ToolbarItem(placement: .primaryAction) {
                Menu("New", systemImage: "plus") {
                    Button { showAddSource = true } label: {
                        Label("Add Source", systemImage: "shippingbox")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                    Button { showNewSkill = true } label: {
                        Label("New Skill", systemImage: "doc.badge.plus")
                    }
                    .keyboardShortcut("n", modifiers: [.command])
                }
                .labelStyle(.titleAndIcon)
                .accessibilityLabel("Create or add")
                .help("New Skill (Command N) or Add Source (Shift Command N)")
            }
        }
        .background(
            Group {
                Button("") { requestNavigation { tab = .sources } }
                    .keyboardShortcut("1", modifiers: [.command]).opacity(0)
                    .accessibilityHidden(true)
                Button("") { requestNavigation { tab = .skills } }
                    .keyboardShortcut("2", modifiers: [.command]).opacity(0)
                    .accessibilityHidden(true)
                Button("") { requestNavigation { tab = .projects } }
                    .keyboardShortcut("3", modifiers: [.command]).opacity(0)
                    .accessibilityHidden(true)
                Button("") {
                    guard NSApp.currentEvent?.modifierFlags.contains(.shift) != true else {
                        return
                    }
                    showNewSkill = true
                }
                    .keyboardShortcut("n", modifiers: [.command]).opacity(0)
                    .accessibilityHidden(true)
                Button("") { showAddSource = true }
                    .keyboardShortcut("n", modifiers: [.command, .shift]).opacity(0)
                    .accessibilityHidden(true)
            }
        )
        .sheet(isPresented: $showAddSource) {
            AddSourceSheet { url, branch in
                try await addSource(url: url, branch: branch)
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
        .task {
            guard controlPlane.hasSavedLibrary else { return }
            runScan(manual: false)
        }
        .background(
            WindowCloseGuard { window in
                guard !editorSession.requestNavigation() else { return true }
                pendingNavigation = { window.performClose(nil) }
                return false
            }
        )
        .confirmationDialog(
            "Save changes before leaving?",
            isPresented: Binding(
                get: { editorSession.hasPendingNavigation },
                set: { presented in
                    if !presented && editorSession.hasPendingNavigation {
                        resolveNavigation(.cancel)
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Save") { resolveNavigation(.save) }
            Button("Discard Changes", role: .destructive) {
                resolveNavigation(.discard)
            }
            Button("Cancel", role: .cancel) { resolveNavigation(.cancel) }
        } message: {
            Text("Your edits have not been saved.")
        }
        .alert(
            "Could Not Save",
            isPresented: Binding(
                get: { navigationError != nil },
                set: { if !$0 { navigationError = nil } }
            )
        ) {
            Button("OK") { navigationError = nil }
        } message: {
            Text(navigationError ?? "")
        }
    }

    private var guardedTab: Binding<LibraryTab> {
        Binding(
            get: { tab },
            set: { newValue in requestNavigation { tab = newValue } }
        )
    }

    private var guardedSkillSelection: Binding<String?> {
        Binding(
            get: { selectedSkillID },
            set: { newValue in requestNavigation { selectedSkillID = newValue } }
        )
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
                requestNavigation { self.selectedSkillID = nil }
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

    private func requestNavigation(_ action: @escaping () -> Void) {
        if editorSession.requestNavigation() {
            action()
        } else {
            pendingNavigation = action
        }
    }

    private func resolveNavigation(_ decision: EditorNavigationDecision) {
        do {
            guard try editorSession.resolveNavigation(decision) else {
                pendingNavigation = nil
                return
            }
            let action = pendingNavigation
            pendingNavigation = nil
            action?()
        } catch {
            navigationError = error.localizedDescription
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

    private func addSource(url: String, branch: String) async throws {
        let plane = controlPlane
        let source = try await Task.detached {
            try plane.addSource(url: url, branch: branch)
        }.value
        sources = controlPlane.listSources()
        selectedSourceID = source.id
        requestNavigation { tab = .sources }
        showToast("Fetched \(source.displayName)")
    }
}

private enum LibraryTab: Hashable {
    case sources, skills, projects
}

private struct WindowCloseGuard: NSViewRepresentable {
    let shouldClose: (NSWindow) -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(shouldClose: shouldClose)
    }

    func makeNSView(context: Context) -> HostingView {
        HostingView(coordinator: context.coordinator)
    }

    func updateNSView(_ view: HostingView, context: Context) {
        context.coordinator.shouldClose = shouldClose
    }

    static func dismantleNSView(_ view: HostingView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    final class HostingView: NSView {
        let coordinator: Coordinator

        init(coordinator: Coordinator) {
            self.coordinator = coordinator
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            nil
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            coordinator.install(on: window)
        }
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        var shouldClose: (NSWindow) -> Bool
        weak var window: NSWindow?
        weak var originalDelegate: NSWindowDelegate?

        init(shouldClose: @escaping (NSWindow) -> Bool) {
            self.shouldClose = shouldClose
        }

        @MainActor func install(on window: NSWindow?) {
            guard let window, window.delegate !== self else { return }
            self.window = window
            originalDelegate = window.delegate
            window.delegate = self
        }

        @MainActor func uninstall() {
            if window?.delegate === self {
                window?.delegate = originalDelegate
            }
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            shouldClose(sender) && (originalDelegate?.windowShouldClose?(sender) ?? true)
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector)
                || (originalDelegate?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            originalDelegate?.responds(to: selector) == true
                ? originalDelegate
                : super.forwardingTarget(for: selector)
        }
    }
}

struct SkillsHome: View {
    let controlPlane: ControlPlane
    let skills: [SkillSummary]
    @Binding var selection: String?
    @Binding var query: SkillLibraryQuery
    @Binding var editorSession: EditorSession
    var onAddProject: () -> Void = {}
    var onAddSource: () -> Void = {}
    var onInventoryChanged: () -> Void = {}
    var requestNavigation: (@escaping () -> Void) -> Void = { $0() }

    var body: some View {
        if skills.isEmpty && query.isEmpty {
            SkillsEmptyState(onAddProject: onAddProject, onAddSource: onAddSource)
        } else {
            NavigationSplitView {
                List(result.skills, selection: $selection) { skill in
                    SkillRow(skill: skill)
                        .tag(skill.id)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(skillAccessibilityLabel(skill))
                        .accessibilityHint("Shows skill contents in the detail pane")
                }
                .navigationTitle("Skills")
                .searchable(text: $query.text, prompt: "Search Skills")
                .toolbar {
                    ToolbarItem {
                        filterMenu
                    }
                }
                .accessibilityLabel("Skills list")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            } detail: {
                if let selection = result.selection,
                   let detail = controlPlane.skillDetail(id: selection)
                {
                    SkillInspector(
                        detail: detail,
                        controlPlane: controlPlane,
                        editorSession: $editorSession,
                        onInventoryChanged: onInventoryChanged,
                        requestNavigation: requestNavigation
                    )
                } else {
                    ContentUnavailableView(
                        result.skills.isEmpty ? "No matching skills" : "Select a skill",
                        systemImage: result.skills.isEmpty
                            ? "magnifyingglass"
                            : "square.stack.3d.up",
                        description: Text(
                            result.skills.isEmpty
                                ? "Try a different search or clear a filter."
                                : "SKILL.md opens here for reading and editing."
                        )
                    )
                    .accessibilityLabel(
                        result.skills.isEmpty
                            ? "No skills match the active search and filters"
                            : "Select a skill"
                    )
                }
            }
        }
    }

    private var result: SkillLibraryResult {
        query.apply(to: skills, selection: selection)
    }

    private var availableAdapterIds: [String] {
        Set(skills.flatMap(\.adapterIds)).sorted()
    }

    private var filterMenu: some View {
        Menu(
            query.activeFilterCount == 0
                ? "Filter"
                : "\(query.activeFilterCount) \(query.activeFilterCount == 1 ? "Filter" : "Filters")",
            systemImage: query.activeFilterCount == 0
                ? "line.3.horizontal.decrease.circle"
                : "line.3.horizontal.decrease.circle.fill"
        ) {
            Picker("Agent", selection: $query.adapterId) {
                Text("All Agents").tag(String?.none)
                ForEach(availableAdapterIds, id: \.self) { id in
                    Text(AdapterRegistry.displayNames(forAdapterIds: [id]))
                        .tag(Optional(id))
                }
            }
            Picker("Scope", selection: $query.scope) {
                Text("All Scopes").tag(SkillScopeFilter.all)
                Text("User").tag(SkillScopeFilter.global)
                Text("Project").tag(SkillScopeFilter.project)
            }
            Picker("Provenance", selection: $query.provenance) {
                Text("All Provenance").tag(SkillProvenanceFilter.all)
                Text("Sourced").tag(SkillProvenanceFilter.sourced)
                Text("No Source").tag(SkillProvenanceFilter.orphan)
            }
            Divider()
            Toggle("Update Available", isOn: $query.updatesOnly)
            Toggle("Local Edits", isOn: $query.dirtyOnly)
            if !query.isEmpty {
                Divider()
                Button("Clear Search and Filters") { query = SkillLibraryQuery() }
            }
        }
        .labelStyle(.titleAndIcon)
        .accessibilityLabel(
            query.activeFilterCount == 0
                ? "Skill filters, none active"
                : "Skill filters, \(query.activeFilterCount) active"
        )
    }

    private func skillAccessibilityLabel(_ skill: SkillSummary) -> String {
        var parts = [skill.displayName]
        if let sourceName = skill.sourceName { parts.append("source \(sourceName)") }
        if !skill.adapterIds.isEmpty {
            parts.append("used by \(AdapterRegistry.displayNames(forAdapterIds: skill.adapterIds))")
        }
        if let context = skill.locationPaths.first ?? skill.skillRootPaths.first {
            parts.append("on disk at \(context)")
        }
        parts.append(skill.isFromProject ? "project scope" : "user scope")
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
    @Binding var editorSession: EditorSession
    var onInventoryChanged: () -> Void = {}
    var requestNavigation: (@escaping () -> Void) -> Void = { $0() }

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
                    session: $editorSession,
                    onSaved: onInventoryChanged,
                    requestNavigation: requestNavigation
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
        .onChange(of: detail.locations) { _, _ in syncActiveLocation() }
    }

    private var resolvedLocationPath: String? {
        if let activeLocationPath,
           detail.locations.contains(where: { $0.onDiskPath == activeLocationPath })
        {
            return activeLocationPath
        }
        if editorSession.isDirty {
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
                        .accessibilityLabel("No git source")
                }
                if detail.summary.hasUpdate {
                    Text("Update").font(.caption2).foregroundStyle(.orange)
                        .accessibilityLabel("Update available")
                }
                if detail.summary.isDirty {
                    Text("Dirty").font(.caption2).foregroundStyle(.red)
                        .accessibilityLabel("Local edits")
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
            set: { newValue in
                requestNavigation { activeLocationPath = newValue }
            }
        )
    }

    private func syncActiveLocation() {
        guard !detail.locations.contains(where: { $0.onDiskPath == activeLocationPath }) else {
            return
        }
        requestNavigation { activeLocationPath = detail.locations.first?.onDiskPath }
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
                } else if let sourceName = skill.sourceName {
                    Text(sourceName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let context = rowContext {
                    Text(context)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                HStack(spacing: 6) {
                    if skill.isOrphan {
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
                Label("\(skill.locationCount)", systemImage: "doc.on.doc")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
                    .help("\(skill.locationCount) on-disk copies")
                    .accessibilityLabel("\(skill.locationCount) on-disk locations")
            }
        }
        .padding(.vertical, 2)
    }

    private var rowContext: String? {
        if skill.locationCount == 1 {
            return skill.locationPaths.first ?? skill.skillRootPaths.first
        }
        guard !skill.skillRootPaths.isEmpty else { return nil }
        return skill.skillRootPaths.joined(separator: ", ")
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
        .accessibilityElement(children: .contain)
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

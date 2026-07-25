import Foundation

/// Primary control-plane seam: UI and tests drive Skille through this API.
/// Inject `sidecarRoot`, `homeDirectory`, and `git` (temp dirs + FixtureGitFetch in tests).
public struct ControlPlane: Sendable {
    public let sidecarRoot: URL
    public let homeDirectory: URL
    private let git: any GitFetching

    public init(
        sidecarRoot: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        git: any GitFetching = ProcessGitFetch()
    ) throws {
        self.sidecarRoot = sidecarRoot
        self.homeDirectory = homeDirectory
        self.git = git
        try FileManager.default.createDirectory(
            at: sidecarRoot,
            withIntermediateDirectories: true
        )
    }

    /// Default macOS sidecar: `~/Library/Application Support/Skille`.
    public static func defaultSidecarRoot(
        fileManager: FileManager = .default
    ) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("Skille", isDirectory: true)
    }

    public func listSkills() -> [SkillSummary] {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        return skillSummaries(from: snap)
    }

    public func listProjects() -> [ProjectRecord] {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        return snap.projects.sorted { $0.rootPath < $1.rootPath }
    }

    public func addProject(path: String) throws {
        var snap = try SidecarStore.load(from: sidecarRoot)
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard !snap.projects.contains(where: { $0.rootPath == standardized }) else { return }
        snap.projects.append(
            ProjectRecord(id: stableID("proj", standardized), rootPath: standardized)
        )
        try SidecarStore.save(snap, to: sidecarRoot)
    }

    public func removeProject(id: String) throws {
        var snap = try SidecarStore.load(from: sidecarRoot)
        snap.projects.removeAll { $0.id == id }
        try SidecarStore.save(snap, to: sidecarRoot)
    }

    public func listSources() -> [SkillSourceSummary] {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        let logicalBySource = Dictionary(grouping: snap.logicalSkills, by: \.sourceId)
        return snap.sources
            .map { source in
                let logicalIds = Set((logicalBySource[source.id] ?? []).map(\.id))
                let hasUpdate = snap.locations.contains { loc in
                    guard let lid = loc.logicalSkillId, logicalIds.contains(lid) else { return false }
                    return Self.needsUpdate(loc, tip: source.commitSHA)
                }
                return SkillSourceSummary(
                    id: source.id,
                    displayName: source.displayName,
                    normalizedUrl: source.normalizedUrl,
                    branch: source.branch,
                    hasUpdate: hasUpdate
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    @discardableResult
    public func addSource(url: String, branch: String = "main") throws -> SkillSourceSummary {
        let normalized = Self.normalizeGitURL(url)
        let id = stableID("src", "\(normalized)|\(branch)")
        let cache = sidecarRoot
            .appendingPathComponent("cache", isDirectory: true)
            .appendingPathComponent(id.replacingOccurrences(of: "/", with: "_"), isDirectory: true)
        let sha = try git.fetch(url: normalized, branch: branch, into: cache)
        let display = URL(string: normalized)?.deletingPathExtension().lastPathComponent
            ?? normalized

        var snap = try SidecarStore.load(from: sidecarRoot)
        snap.sources.removeAll { $0.id == id }
        snap.sources.append(
            SkillSourceRecord(
                id: id,
                normalizedUrl: normalized,
                branch: branch,
                displayName: display,
                cachePath: cache.path,
                commitSHA: sha
            )
        )
        try SidecarStore.save(snap, to: sidecarRoot)
        return SkillSourceSummary(
            id: id,
            displayName: display,
            normalizedUrl: normalized,
            branch: branch
        )
    }

    public func sourceDetail(id: String) -> SourceDetail? {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        guard let source = snap.sources.first(where: { $0.id == id }) else { return nil }
        let installedPaths = Set(
            snap.logicalSkills.filter { $0.sourceId == source.id }.map(\.skillPathInRepo)
        )
        let packages = discoverPackages(in: URL(fileURLWithPath: source.cachePath, isDirectory: true))
            .map {
                SourcePackage(
                    pathInRepo: $0.path,
                    displayName: $0.name,
                    installStatus: installedPaths.contains($0.path) ? .installed : .notInstalled
                )
            }
            .sorted { $0.pathInRepo < $1.pathInRepo }
        return SourceDetail(
            summary: SkillSourceSummary(
                id: source.id,
                displayName: source.displayName,
                normalizedUrl: source.normalizedUrl,
                branch: source.branch
            ),
            packages: packages
        )
    }

    public func availableInstallRoots() -> [InstallRootOption] {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        return writableRootRecords(in: snap).map { root in
            InstallRootOption(
                id: root.id,
                path: root.path,
                isDefaultSuggestion: root.scope == "global"
                    && root.path.hasSuffix("/.agents/skills"),
                adapterIds: root.adapterIds,
                scope: root.scope
            )
        }.sorted {
            if $0.isDefaultSuggestion != $1.isDefaultSuggestion { return $0.isDefaultSuggestion }
            if $0.scope != $1.scope { return $0.scope < $1.scope }
            return $0.path < $1.path
        }
    }

    private func writableRootRecords(in snap: SidecarSnapshot) -> [SkillRootRecord] {
        let detected = detectAdapters()
        var rootsByPath: [String: SkillRootRecord] = [:]

        func add(path: String, adapterId: String, scope: String, projectId: String? = nil) {
            if var root = rootsByPath[path] {
                if !root.adapterIds.contains(adapterId) {
                    root.adapterIds.append(adapterId)
                    root.adapterIds.sort()
                    rootsByPath[path] = root
                }
            } else {
                rootsByPath[path] = SkillRootRecord(
                    id: stableID("root", path),
                    adapterIds: [adapterId],
                    path: path,
                    scope: scope,
                    projectId: projectId
                )
            }
        }

        for adapter in AdapterRegistry.v1 where detected.contains(adapter.id) {
            for relative in adapter.writableGlobalSkillRoots {
                let path = homeDirectory.appendingPathComponent(relative, isDirectory: true).path
                add(path: path, adapterId: adapter.id, scope: "global")
            }
            for project in snap.projects {
                for relative in adapter.writableProjectSkillRoots {
                    let path = URL(fileURLWithPath: project.rootPath, isDirectory: true)
                        .appendingPathComponent(relative, isDirectory: true)
                        .path
                    add(
                        path: path,
                        adapterId: adapter.id,
                        scope: "project",
                        projectId: project.id
                    )
                }
            }
        }

        return rootsByPath.values.sorted { $0.path < $1.path }
    }

    public func install(
        sourceId: String,
        packagePaths: [String],
        skillRootIds: [String]
    ) throws {
        var snap = try SidecarStore.load(from: sidecarRoot)
        guard let source = snap.sources.first(where: { $0.id == sourceId }) else {
            throw InstallError.sourceNotFound
        }
        let cacheRoot = URL(fileURLWithPath: source.cachePath, isDirectory: true)
        let fm = FileManager.default

        for packagePath in packagePaths {
            let from = cacheRoot.appendingPathComponent(packagePath, isDirectory: true)
            guard fm.fileExists(atPath: from.appendingPathComponent("SKILL.md").path) else {
                throw InstallError.packageNotFound(packagePath)
            }
            let folderName = URL(fileURLWithPath: packagePath).lastPathComponent
            let display = displayName(
                from: from.appendingPathComponent("SKILL.md"),
                fallback: folderName
            )
            let logicalID = stableID("logical", "\(sourceId)|\(packagePath)")
            if !snap.logicalSkills.contains(where: { $0.id == logicalID }) {
                snap.logicalSkills.append(
                    LogicalSkillRecord(
                        id: logicalID,
                        sourceId: sourceId,
                        skillPathInRepo: packagePath,
                        displayName: display
                    )
                )
            }

            for rootId in skillRootIds {
                let rootPath = try resolveRootPath(rootId, into: &snap)

                let dest = URL(fileURLWithPath: rootPath, isDirectory: true)
                    .appendingPathComponent(folderName, isDirectory: true)
                    .standardizedFileURL
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: from, to: dest)

                let digests = try SkillTreeIO.fileDigests(ofTree: dest)
                let destPath = dest.resolvingSymlinksInPath().path
                let locID = stableID("loc", destPath)
                snap.locations.removeAll { $0.id == locID || $0.onDiskPath == destPath }
                snap.locations.append(
                    LocationRecord(
                        id: locID,
                        skillRootId: rootId,
                        onDiskPath: destPath,
                        displayName: display,
                        logicalSkillId: logicalID,
                        appliedCommitSHA: source.commitSHA,
                        fileDigests: digests
                    )
                )
            }
        }

        try SidecarStore.save(snap, to: sidecarRoot)
    }

    public func createSkill(name: String, description: String, skillRootIds: [String]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AuthoringError.invalidName }
        let folder = sanitizedSkillFolderName(trimmed)
        var snap = try SidecarStore.load(from: sidecarRoot)
        let body = """
        ---
        name: \(trimmed)
        description: \(description)
        ---
        # \(trimmed)

        \(description)
        """

        for rootId in skillRootIds {
            let rootPath = try resolveRootPath(rootId, into: &snap)
            let dest = URL(fileURLWithPath: rootPath, isDirectory: true)
                .appendingPathComponent(folder, isDirectory: true)
            if FileManager.default.fileExists(atPath: dest.path) {
                throw AuthoringError.alreadyExists(dest.path)
            }
            try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            try body.write(to: dest.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        }
        try SidecarStore.save(snap, to: sidecarRoot)
    }

    private func sanitizedSkillFolderName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = String(name.lowercased().map { ch -> Character in
            String(ch).rangeOfCharacter(from: allowed) != nil ? ch : "-"
        })
        var result = mapped
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func normalizeGitURL(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix(".git") { /* keep */ }
        if s.hasSuffix("/") { s.removeLast() }
        return s
    }

    public func skillDetail(id: String) -> SkillDetail? {
        let snap = (try? SidecarStore.load(from: sidecarRoot)) ?? SidecarSnapshot()
        let roots = Dictionary(uniqueKeysWithValues: snap.skillRoots.map { ($0.id, $0) })
        // Orphans: row id == location id. Logical skills (later): row id == logicalSkillId.
        let locs = snap.locations.filter { $0.id == id || $0.logicalSkillId == id }
        guard !locs.isEmpty else { return nil }
        let summary = skillSummaries(from: snap).first { $0.id == id }
            ?? SkillSummary(
                id: id,
                displayName: locs[0].displayName,
                locationCount: locs.count,
                isOrphan: locs.allSatisfy { $0.logicalSkillId == nil },
                isFromProject: locs.contains { roots[$0.skillRootId]?.scope == "project" },
                adapterIds: Self.unionAdapterIds(for: locs, roots: roots)
            )
        let locations = locs.map { loc in
            let root = roots[loc.skillRootId]
            return LocationSummary(
                id: loc.id,
                onDiskPath: loc.onDiskPath,
                skillRootPath: root?.path ?? "",
                adapterIds: root?.adapterIds ?? [],
                appliedCommitSHA: loc.appliedCommitSHA,
                fileDigests: loc.fileDigests
            )
        }
        .sorted { $0.onDiskPath < $1.onDiskPath }
        return SkillDetail(summary: summary, locations: locations)
    }

    private func skillSummaries(from snap: SidecarSnapshot) -> [SkillSummary] {
        let roots = Dictionary(uniqueKeysWithValues: snap.skillRoots.map { ($0.id, $0) })
        let tipBySource = Dictionary(uniqueKeysWithValues: snap.sources.map { ($0.id, $0.commitSHA) })
        let logicalById = Dictionary(uniqueKeysWithValues: snap.logicalSkills.map { ($0.id, $0) })
        // Group by logicalSkillId when present; otherwise one row per orphan location.
        var grouped: [String: [LocationRecord]] = [:]
        for loc in snap.locations {
            let key = loc.logicalSkillId ?? loc.id
            grouped[key, default: []].append(loc)
        }
        return grouped.map { key, locs in
            let sorted = locs.sorted { $0.onDiskPath < $1.onDiskPath }
            let fromProject = sorted.contains { roots[$0.skillRootId]?.scope == "project" }
            let dirty = sorted.contains { Self.isDirty($0) }
            let update = sorted.contains { loc in
                guard let logicalId = loc.logicalSkillId,
                      let logical = logicalById[logicalId],
                      let tip = tipBySource[logical.sourceId]
                else { return false }
                return Self.needsUpdate(loc, tip: tip)
            }
            return SkillSummary(
                id: key,
                displayName: sorted[0].displayName,
                locationCount: sorted.count,
                isOrphan: sorted.allSatisfy { $0.logicalSkillId == nil },
                hasUpdate: update,
                isDirty: dirty,
                isFromProject: fromProject,
                adapterIds: Self.unionAdapterIds(for: sorted, roots: roots)
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func unionAdapterIds(
        for locs: [LocationRecord],
        roots: [String: SkillRootRecord]
    ) -> [String] {
        var ids = Set<String>()
        for loc in locs {
            if let root = roots[loc.skillRootId] {
                ids.formUnion(root.adapterIds)
            }
        }
        return ids.sorted()
    }

    public static func isDirty(_ location: LocationRecord) -> Bool {
        guard !location.fileDigests.isEmpty else { return false }
        let current = (try? SkillTreeIO.fileDigests(
            ofTree: URL(fileURLWithPath: location.onDiskPath, isDirectory: true)
        )) ?? []
        return current != location.fileDigests
    }

    public static func needsUpdate(_ location: LocationRecord, tip: String) -> Bool {
        guard let applied = location.appliedCommitSHA else { return false }
        return tip != applied
    }

    @discardableResult
    public func checkUpdates() throws -> UpdateCheckResult {
        var snap = try SidecarStore.load(from: sidecarRoot)
        var updates = 0
        var dirty = 0

        for index in snap.sources.indices {
            var source = snap.sources[index]
            let cache = URL(fileURLWithPath: source.cachePath, isDirectory: true)
            let tip = try git.fetch(url: source.normalizedUrl, branch: source.branch, into: cache)
            source.commitSHA = tip
            source.lastFetchAt = Date()
            snap.sources[index] = source
        }

        let tipBySource = Dictionary(uniqueKeysWithValues: snap.sources.map { ($0.id, $0.commitSHA) })
        let logicalById = Dictionary(uniqueKeysWithValues: snap.logicalSkills.map { ($0.id, $0) })

        for loc in snap.locations {
            if Self.isDirty(loc) { dirty += 1 }
            if let logicalId = loc.logicalSkillId,
               let logical = logicalById[logicalId],
               let tip = tipBySource[logical.sourceId],
               Self.needsUpdate(loc, tip: tip)
            {
                updates += 1
            }
        }

        try SidecarStore.save(snap, to: sidecarRoot)
        return UpdateCheckResult(updatesFound: updates, dirtyFound: dirty)
    }

    public func prepareUpdateReview(locationId: String) throws -> UpdateReview {
        let snap = try SidecarStore.load(from: sidecarRoot)
        let (loc, logical, source) = try provenance(locationId: locationId, in: snap)

        let remoteRoot = URL(fileURLWithPath: source.cachePath, isDirectory: true)
            .appendingPathComponent(logical.skillPathInRepo, isDirectory: true)
        let localRoot = URL(fileURLWithPath: loc.onDiskPath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: remoteRoot.path) else {
            throw UpdateReviewError.remoteMissing
        }

        return UpdateReview(
            locationId: locationId,
            displayName: loc.displayName,
            onDiskPath: loc.onDiskPath,
            proposedCommitSHA: source.commitSHA,
            appliedCommitSHA: loc.appliedCommitSHA,
            isDirty: Self.isDirty(loc),
            files: try SkillTreeIO.diffTrees(local: localRoot, remote: remoteRoot)
        )
    }

    public func acceptUpdate(locationId: String, discardLocal: Bool) throws {
        var snap = try SidecarStore.load(from: sidecarRoot)
        guard let index = snap.locations.firstIndex(where: { $0.id == locationId }) else {
            throw UpdateReviewError.locationNotFound
        }
        var loc = snap.locations[index]
        let (_, logical, source) = try provenance(locationId: locationId, in: snap)

        if Self.isDirty(loc) && !discardLocal {
            throw UpdateReviewError.dirtyRequiresDiscard
        }

        let remoteRoot = URL(fileURLWithPath: source.cachePath, isDirectory: true)
            .appendingPathComponent(logical.skillPathInRepo, isDirectory: true)
        let localRoot = URL(fileURLWithPath: loc.onDiskPath, isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: localRoot.path) {
            try fm.removeItem(at: localRoot)
        }
        try fm.createDirectory(at: localRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: remoteRoot, to: localRoot)

        loc.appliedCommitSHA = source.commitSHA
        loc.fileDigests = try SkillTreeIO.fileDigests(ofTree: localRoot)
        snap.locations[index] = loc
        try SidecarStore.save(snap, to: sidecarRoot)
    }

    public func rejectUpdate(locationId: String) throws {
        // AC: Reject leaves disk and last-applied unchanged.
        _ = locationId
    }

    public func locationsNeedingUpdate(sourceId: String) throws -> [UpdateChecklistItem] {
        let snap = try SidecarStore.load(from: sidecarRoot)
        guard let source = snap.sources.first(where: { $0.id == sourceId }) else {
            throw UpdateReviewError.locationNotFound
        }
        let logicalIds = Set(snap.logicalSkills.filter { $0.sourceId == sourceId }.map(\.id))
        return snap.locations.compactMap { loc -> UpdateChecklistItem? in
            guard let lid = loc.logicalSkillId, logicalIds.contains(lid),
                  Self.needsUpdate(loc, tip: source.commitSHA)
            else { return nil }
            return UpdateChecklistItem(
                locationId: loc.id,
                displayName: loc.displayName,
                onDiskPath: loc.onDiskPath,
                isDirty: Self.isDirty(loc)
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    public func prepareUpdateReviews(locationIds: [String]) throws -> [UpdateReview] {
        try locationIds.map { try prepareUpdateReview(locationId: $0) }
    }

    public enum AttachPreview: Equatable, Sendable {
        case newLogicalSkill
        case joinExisting(logicalSkillId: String, displayName: String)
    }

    public func previewAttachSource(
        locationId: String,
        url: String,
        branch: String = "main",
        pathInRepo: String
    ) throws -> AttachPreview {
        let snap = try SidecarStore.load(from: sidecarRoot)
        guard snap.locations.contains(where: { $0.id == locationId }) else {
            throw AttachSourceError.locationNotFound
        }
        let normalized = Self.normalizeGitURL(url)
        let sourceId = stableID("src", "\(normalized)|\(branch)")
        let logicalID = stableID("logical", "\(sourceId)|\(pathInRepo)")
        if let existing = snap.logicalSkills.first(where: { $0.id == logicalID }) {
            return .joinExisting(logicalSkillId: existing.id, displayName: existing.displayName)
        }
        return .newLogicalSkill
    }

    public func attachSource(
        locationId: String,
        url: String,
        branch: String = "main",
        pathInRepo: String,
        confirmJoin: Bool
    ) throws {
        var snap = try SidecarStore.load(from: sidecarRoot)
        guard let index = snap.locations.firstIndex(where: { $0.id == locationId }) else {
            throw AttachSourceError.locationNotFound
        }
        var loc = snap.locations[index]
        guard loc.logicalSkillId == nil else {
            throw AttachSourceError.notOrphan
        }

        let preview = try previewAttachSource(
            locationId: locationId,
            url: url,
            branch: branch,
            pathInRepo: pathInRepo
        )
        if case .joinExisting = preview, !confirmJoin {
            throw AttachSourceError.confirmationRequired
        }

        // Ensure source exists (fetch into cache); never silent — caller provided URL.
        let source = try addSource(url: url, branch: branch)
        snap = try SidecarStore.load(from: sidecarRoot)

        let logicalID = stableID("logical", "\(source.id)|\(pathInRepo)")
        if !snap.logicalSkills.contains(where: { $0.id == logicalID }) {
            snap.logicalSkills.append(
                LogicalSkillRecord(
                    id: logicalID,
                    sourceId: source.id,
                    skillPathInRepo: pathInRepo,
                    displayName: loc.displayName
                )
            )
        }

        guard let sourceRecord = snap.sources.first(where: { $0.id == source.id }),
              let locIndex = snap.locations.firstIndex(where: { $0.id == locationId })
        else {
            throw AttachSourceError.locationNotFound
        }
        loc = snap.locations[locIndex]
        loc.logicalSkillId = logicalID
        loc.appliedCommitSHA = sourceRecord.commitSHA
        loc.fileDigests = try SkillTreeIO.fileDigests(
            ofTree: URL(fileURLWithPath: loc.onDiskPath, isDirectory: true)
        )
        snap.locations[locIndex] = loc
        try SidecarStore.save(snap, to: sidecarRoot)
    }

    public func suggestedGitOrigin(forLocationPath path: String) -> String? {
        SkilleControl.suggestedGitOrigin(startingAt: path)
    }

    public static func diffTrees(local: URL, remote: URL) throws -> [UpdateFileChange] {
        try SkillTreeIO.diffTrees(local: local, remote: remote)
    }

    @discardableResult
    public func scan() throws -> ScanResult {
        let previous = try SidecarStore.load(from: sidecarRoot)
        let detected = detectAdapters()
        var rootByPath: [String: SkillRootRecord] = [:]

        for adapter in AdapterRegistry.v1 where detected.contains(adapter.id) {
            for relative in adapter.globalSkillRoots {
                upsertRoot(
                    path: homeDirectory.appendingPathComponent(relative, isDirectory: true).path,
                    adapterId: adapter.id,
                    into: &rootByPath
                )
            }
            for relative in adapter.deepGlobalSkillRoots {
                let base = homeDirectory.appendingPathComponent(relative, isDirectory: true)
                guard FileManager.default.fileExists(atPath: base.path) else { continue }
                for packageParent in deepSkillRootPaths(under: base) {
                    upsertRoot(path: packageParent, adapterId: adapter.id, into: &rootByPath)
                }
            }
        }

        // Always include shared ~/.agents/skills when present (cross-client).
        let agentsURL = homeDirectory.appendingPathComponent(".agents/skills", isDirectory: true)
        if FileManager.default.fileExists(atPath: agentsURL.path), rootByPath[agentsURL.path] == nil {
            rootByPath[agentsURL.path] = SkillRootRecord(
                id: stableID("root", agentsURL.path),
                adapterIds: [],
                path: agentsURL.path
            )
        }

        // Project-scoped roots: only for user-added Projects (no full-disk crawl).
        for project in previous.projects {
            let projectURL = URL(fileURLWithPath: project.rootPath, isDirectory: true)
            for relative in AdapterRegistry.allProjectSkillRoots {
                let url = projectURL.appendingPathComponent(relative, isDirectory: true)
                let path = url.path
                guard FileManager.default.fileExists(atPath: path) else { continue }
                if rootByPath[path] == nil {
                    rootByPath[path] = SkillRootRecord(
                        id: stableID("root", path),
                        adapterIds: [],
                        path: path,
                        scope: "project",
                        projectId: project.id
                    )
                }
            }
        }

        var locations: [LocationRecord] = []
        let previousByPath = Dictionary(uniqueKeysWithValues: previous.locations.map { ($0.onDiskPath, $0) })
        for root in rootByPath.values {
            for discovered in discoverSkills(in: root) {
                if let old = previousByPath[discovered.onDiskPath] {
                    var merged = discovered
                    merged.logicalSkillId = old.logicalSkillId
                    merged.appliedCommitSHA = old.appliedCommitSHA
                    merged.fileDigests = old.fileDigests
                    if let name = previous.logicalSkills.first(where: { $0.id == old.logicalSkillId })?.displayName {
                        merged.displayName = name
                    }
                    locations.append(merged)
                } else {
                    locations.append(discovered)
                }
            }
        }
        locations.sort { $0.onDiskPath < $1.onDiskPath }

        let next = SidecarSnapshot(
            skillRoots: rootByPath.values.sorted { $0.path < $1.path },
            locations: locations,
            projects: previous.projects,
            sources: previous.sources,
            logicalSkills: previous.logicalSkills
        )
        let changed = next != previous
        try SidecarStore.save(next, to: sidecarRoot)

        return ScanResult(
            skillsFound: locations.count,
            rootsFound: next.skillRoots.count,
            detectedAdapterIds: detected.sorted(),
            inventoryChanged: changed
        )
    }

    private func detectAdapters() -> Set<String> {
        var found = Set<String>()
        let fm = FileManager.default
        for adapter in AdapterRegistry.v1 {
            let byDetect = adapter.detectRelativePaths.contains {
                fm.fileExists(atPath: homeDirectory.appendingPathComponent($0).path)
            }
            let byRoot = adapter.globalSkillRoots
                .filter { $0 != ".agents/skills" }
                .contains {
                fm.fileExists(atPath: homeDirectory.appendingPathComponent($0).path)
            }
            if byDetect || byRoot {
                found.insert(adapter.id)
            }
        }
        return found
    }

    private func upsertRoot(
        path: String,
        adapterId: String,
        into rootByPath: inout [String: SkillRootRecord]
    ) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        if var existing = rootByPath[path] {
            if !existing.adapterIds.contains(adapterId) {
                existing.adapterIds.append(adapterId)
                existing.adapterIds.sort()
                rootByPath[path] = existing
            }
        } else {
            rootByPath[path] = SkillRootRecord(
                id: stableID("root", path),
                adapterIds: [adapterId],
                path: path
            )
        }
    }

    /// Parents of skill packages found under a deep tree (e.g. `…/plugins/…/skills`).
    private func deepSkillRootPaths(under base: URL) -> [String] {
        var parents = Set<String>()
        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            guard item.lastPathComponent == "SKILL.md" else { continue }
            let package = item.deletingLastPathComponent()
            parents.insert(package.deletingLastPathComponent().path)
        }
        return parents.sorted()
    }

    private func discoverSkills(in root: SkillRootRecord) -> [LocationRecord] {
        let fm = FileManager.default
        let rootURL = URL(fileURLWithPath: root.path, isDirectory: true)
        guard let contents = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [LocationRecord] = []
        for item in contents {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue else {
                continue
            }
            let skillMD = item.appendingPathComponent("SKILL.md")
            guard fm.fileExists(atPath: skillMD.path) else { continue }
            let name = displayName(from: skillMD, fallback: item.lastPathComponent)
            results.append(
                LocationRecord(
                    id: stableID("loc", item.path),
                    skillRootId: root.id,
                    onDiskPath: item.path,
                    displayName: name,
                    logicalSkillId: nil
                )
            )
        }
        return results
    }

    private func displayName(from skillMD: URL, fallback: String) -> String {
        guard let text = try? String(contentsOf: skillMD, encoding: .utf8),
              text.hasPrefix("---"),
              let end = text.range(of: "\n---", range: text.index(after: text.startIndex)..<text.endIndex)
        else {
            return fallback
        }
        let front = text[text.index(text.startIndex, offsetBy: 3)..<end.lowerBound]
        for line in front.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            if parts.count == 2, parts[0] == "name", !parts[1].isEmpty {
                return Self.unquoteYAMLScalar(parts[1])
            }
        }
        return fallback
    }

    static func unquoteYAMLScalar(_ raw: String) -> String {
        guard raw.count >= 2 else { return raw }
        if (raw.hasPrefix("\"") && raw.hasSuffix("\""))
            || (raw.hasPrefix("'") && raw.hasSuffix("'"))
        {
            return String(raw.dropFirst().dropLast())
        }
        return raw
    }

    private func stableID(_ prefix: String, _ path: String) -> String {
        "\(prefix):\(path)"
    }

    private func provenance(
        locationId: String,
        in snap: SidecarSnapshot
    ) throws -> (LocationRecord, LogicalSkillRecord, SkillSourceRecord) {
        guard let loc = snap.locations.first(where: { $0.id == locationId }) else {
            throw UpdateReviewError.locationNotFound
        }
        guard let logicalId = loc.logicalSkillId,
              let logical = snap.logicalSkills.first(where: { $0.id == logicalId }),
              let source = snap.sources.first(where: { $0.id == logical.sourceId })
        else {
            throw UpdateReviewError.noProvenance
        }
        return (loc, logical, source)
    }

    private func resolveRootPath(_ rootId: String, into snap: inout SidecarSnapshot) throws -> String {
        guard let root = writableRootRecords(in: snap).first(where: { $0.id == rootId }) else {
            throw InstallError.rootNotFound(rootId)
        }
        if let existing = snap.skillRoots.first(where: { $0.id == rootId }) {
            return existing.path
        }
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: root.path, isDirectory: true),
            withIntermediateDirectories: true
        )
        snap.skillRoots.append(root)
        return root.path
    }

    private func discoverPackages(in root: URL) -> [(path: String, name: String)] {
        var results: [(path: String, name: String)] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            guard item.lastPathComponent == "SKILL.md" else { continue }
            let dir = item.deletingLastPathComponent()
            results.append((
                SkillTreeIO.relativePath(of: dir, under: root),
                displayName(from: item, fallback: dir.lastPathComponent)
            ))
        }
        return results
    }

    /// Soft cap for loading text into the in-app editor buffer (~512 KiB).
    public static var textBufferLimitBytes: Int { SkillTreeIO.textBufferLimitBytes }

    public static func fileDigests(ofTree root: URL) throws -> [FileDigestRecord] {
        try SkillTreeIO.fileDigests(ofTree: root)
    }

    public func listSkillFiles(at skillRootPath: String) throws -> [SkillFileEntry] {
        try SkillTreeIO.listFiles(at: skillRootPath)
    }

    public func readTextFile(at skillRootPath: String, relativePath: String) throws -> SkillFileContent {
        try SkillTreeIO.readText(at: skillRootPath, relativePath: relativePath)
    }

    public func writeTextFile(at skillRootPath: String, relativePath: String, content: String) throws {
        try SkillTreeIO.writeText(at: skillRootPath, relativePath: relativePath, content: content)
    }

    public func absoluteFileURL(skillRootPath: String, relativePath: String) throws -> URL {
        try SkillTreeIO.absoluteFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
    }
}

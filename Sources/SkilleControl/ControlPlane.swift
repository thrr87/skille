import Foundation

public struct ScanResult: Equatable, Sendable {
    public let skillsFound: Int
    public let rootsFound: Int
    public let detectedAdapterIds: [String]
    public let inventoryChanged: Bool

    public init(
        skillsFound: Int,
        rootsFound: Int,
        detectedAdapterIds: [String],
        inventoryChanged: Bool
    ) {
        self.skillsFound = skillsFound
        self.rootsFound = rootsFound
        self.detectedAdapterIds = detectedAdapterIds
        self.inventoryChanged = inventoryChanged
    }
}

/// Primary control-plane seam: UI and tests drive Skille through this API.
/// Inject `sidecarRoot` and `homeDirectory` (temp dirs in tests).
public struct ControlPlane: Sendable {
    public let sidecarRoot: URL
    public let homeDirectory: URL

    public init(
        sidecarRoot: URL,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        self.sidecarRoot = sidecarRoot
        self.homeDirectory = homeDirectory
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
                isFromProject: locs.contains { roots[$0.skillRootId]?.scope == "project" }
            )
        let locations = locs.map { loc in
            let root = roots[loc.skillRootId]
            return LocationSummary(
                id: loc.id,
                onDiskPath: loc.onDiskPath,
                skillRootPath: root?.path ?? "",
                adapterIds: root?.adapterIds ?? []
            )
        }
        .sorted { $0.onDiskPath < $1.onDiskPath }
        return SkillDetail(summary: summary, locations: locations)
    }

    private func skillSummaries(from snap: SidecarSnapshot) -> [SkillSummary] {
        let roots = Dictionary(uniqueKeysWithValues: snap.skillRoots.map { ($0.id, $0) })
        // Group by logicalSkillId when present; otherwise one row per orphan location.
        var grouped: [String: [LocationRecord]] = [:]
        for loc in snap.locations {
            let key = loc.logicalSkillId ?? loc.id
            grouped[key, default: []].append(loc)
        }
        return grouped.map { key, locs in
            let sorted = locs.sorted { $0.onDiskPath < $1.onDiskPath }
            let fromProject = sorted.contains { roots[$0.skillRootId]?.scope == "project" }
            return SkillSummary(
                id: key,
                displayName: sorted[0].displayName,
                locationCount: sorted.count,
                isOrphan: sorted.allSatisfy { $0.logicalSkillId == nil },
                hasUpdate: false,
                isDirty: false,
                isFromProject: fromProject
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    @discardableResult
    public func scan() throws -> ScanResult {
        let previous = try SidecarStore.load(from: sidecarRoot)
        let detected = detectAdapters()
        var rootByPath: [String: SkillRootRecord] = [:]

        for adapter in AdapterRegistry.v1 where detected.contains(adapter.id) {
            for relative in adapter.globalSkillRoots {
                let url = homeDirectory.appendingPathComponent(relative, isDirectory: true)
                let path = url.path
                guard FileManager.default.fileExists(atPath: path) else { continue }
                if var existing = rootByPath[path] {
                    if !existing.adapterIds.contains(adapter.id) {
                        existing.adapterIds.append(adapter.id)
                        existing.adapterIds.sort()
                        rootByPath[path] = existing
                    }
                } else {
                    rootByPath[path] = SkillRootRecord(
                        id: stableID("root", path),
                        adapterIds: [adapter.id],
                        path: path
                    )
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
        for root in rootByPath.values {
            locations.append(contentsOf: discoverSkills(in: root))
        }
        locations.sort { $0.onDiskPath < $1.onDiskPath }

        let next = SidecarSnapshot(
            skillRoots: rootByPath.values.sorted { $0.path < $1.path },
            locations: locations,
            projects: previous.projects
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
            let byRoot = adapter.globalSkillRoots.contains {
                fm.fileExists(atPath: homeDirectory.appendingPathComponent($0).path)
            }
            if byDetect || byRoot {
                found.insert(adapter.id)
            }
        }
        return found
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
                return parts[1]
            }
        }
        return fallback
    }

    private func stableID(_ prefix: String, _ path: String) -> String {
        "\(prefix):\(path)"
    }
}

public struct SkillSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let locationCount: Int
    public let isOrphan: Bool
    public let hasUpdate: Bool
    public let isDirty: Bool
    public let isFromProject: Bool

    public init(
        id: String,
        displayName: String,
        locationCount: Int = 1,
        isOrphan: Bool = true,
        hasUpdate: Bool = false,
        isDirty: Bool = false,
        isFromProject: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.locationCount = locationCount
        self.isOrphan = isOrphan
        self.hasUpdate = hasUpdate
        self.isDirty = isDirty
        self.isFromProject = isFromProject
    }
}

public struct LocationSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let onDiskPath: String
    public let skillRootPath: String
    public let adapterIds: [String]

    public init(id: String, onDiskPath: String, skillRootPath: String, adapterIds: [String]) {
        self.id = id
        self.onDiskPath = onDiskPath
        self.skillRootPath = skillRootPath
        self.adapterIds = adapterIds
    }
}

public struct SkillDetail: Equatable, Sendable {
    public let summary: SkillSummary
    public let locations: [LocationSummary]

    public init(summary: SkillSummary, locations: [LocationSummary]) {
        self.summary = summary
        self.locations = locations
    }
}

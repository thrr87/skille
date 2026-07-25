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
        return snap.locations.map { loc in
            SkillSummary(
                id: loc.id,
                displayName: loc.displayName,
                locationCount: 1,
                isOrphan: loc.logicalSkillId == nil,
                hasUpdate: false,
                isDirty: false
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

        var locations: [LocationRecord] = []
        for root in rootByPath.values {
            locations.append(contentsOf: discoverSkills(in: root))
        }
        locations.sort { $0.onDiskPath < $1.onDiskPath }

        let next = SidecarSnapshot(
            skillRoots: rootByPath.values.sorted { $0.path < $1.path },
            locations: locations
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

    public init(
        id: String,
        displayName: String,
        locationCount: Int = 1,
        isOrphan: Bool = true,
        hasUpdate: Bool = false,
        isDirty: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.locationCount = locationCount
        self.isOrphan = isOrphan
        self.hasUpdate = hasUpdate
        self.isDirty = isDirty
    }
}

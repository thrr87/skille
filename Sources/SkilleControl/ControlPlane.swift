import Foundation
import CryptoKit

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
        return snap.sources
            .map {
                SkillSourceSummary(
                    id: $0.id,
                    displayName: $0.displayName,
                    normalizedUrl: $0.normalizedUrl,
                    branch: $0.branch
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
        // Prefer existing scanned roots; ensure ~/.agents/skills is offered when any adapter supports it.
        var options: [InstallRootOption] = snap.skillRoots
            .filter { $0.scope == "global" }
            .map {
                InstallRootOption(
                    id: $0.id,
                    path: $0.path,
                    isDefaultSuggestion: $0.path.hasSuffix("/.agents/skills")
                )
            }
        let agentsPath = homeDirectory.appendingPathComponent(".agents/skills", isDirectory: true).path
        if !options.contains(where: { $0.path == agentsPath }) {
            let id = stableID("root", agentsPath)
            options.append(
                InstallRootOption(id: id, path: agentsPath, isDefaultSuggestion: true)
            )
        }
        return options.sorted {
            if $0.isDefaultSuggestion != $1.isDefaultSuggestion { return $0.isDefaultSuggestion }
            return $0.path < $1.path
        }
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
                let rootPath: String
                if let existing = snap.skillRoots.first(where: { $0.id == rootId }) {
                    rootPath = existing.path
                } else if rootId == stableID("root", homeDirectory.appendingPathComponent(".agents/skills").path) {
                    rootPath = homeDirectory.appendingPathComponent(".agents/skills").path
                    try fm.createDirectory(
                        at: URL(fileURLWithPath: rootPath, isDirectory: true),
                        withIntermediateDirectories: true
                    )
                    snap.skillRoots.append(
                        SkillRootRecord(id: rootId, adapterIds: [], path: rootPath)
                    )
                } else {
                    throw InstallError.rootNotFound(rootId)
                }

                let dest = URL(fileURLWithPath: rootPath, isDirectory: true)
                    .appendingPathComponent(folderName, isDirectory: true)
                    .standardizedFileURL
                if fm.fileExists(atPath: dest.path) {
                    try fm.removeItem(at: dest)
                }
                try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.copyItem(at: from, to: dest)

                let digests = try Self.fileDigests(ofTree: dest)
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
                isFromProject: locs.contains { roots[$0.skillRootId]?.scope == "project" }
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

    private func discoverPackages(in root: URL) -> [(path: String, name: String)] {
        var results: [(path: String, name: String)] = []
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            guard item.lastPathComponent == "SKILL.md" else { continue }
            let dir = item.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
            let dirPath = dir.path
            let rel: String
            if dirPath == rootPath {
                rel = "."
            } else if dirPath.hasPrefix(rootPath + "/") {
                rel = String(dirPath.dropFirst(rootPath.count + 1))
            } else {
                rel = dir.lastPathComponent
            }
            let name = displayName(from: item, fallback: dir.lastPathComponent)
            results.append((rel, name))
        }
        return results
    }

    public static func fileDigests(ofTree root: URL) throws -> [FileDigestRecord] {
        var digests: [FileDigestRecord] = []
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            let data = try Data(contentsOf: item)
            let hash = SHA256.hash(data: data)
            let hex = hash.map { String(format: "%02x", $0) }.joined()
            let itemPath = item.resolvingSymlinksInPath().standardizedFileURL.path
            let rel: String
            if itemPath.hasPrefix(rootPath + "/") {
                rel = String(itemPath.dropFirst(rootPath.count + 1))
            } else {
                rel = item.lastPathComponent
            }
            digests.append(FileDigestRecord(relPath: rel, sha256: hex))
        }
        return digests.sorted { $0.relPath < $1.relPath }
    }

    /// Soft cap for loading text into the in-app editor buffer (~512 KiB).
    public static let textBufferLimitBytes = 512 * 1024

    public func listSkillFiles(at skillRootPath: String) throws -> [SkillFileEntry] {
        let root = URL(fileURLWithPath: skillRootPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let rootPath = root.path
        guard FileManager.default.fileExists(atPath: rootPath) else {
            throw EditorError.rootMissing
        }
        var entries: [SkillFileEntry] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
                  !isDir.boolValue
            else { continue }
            let itemPath = item.resolvingSymlinksInPath().standardizedFileURL.path
            let rel: String
            if itemPath.hasPrefix(rootPath + "/") {
                rel = String(itemPath.dropFirst(rootPath.count + 1))
            } else {
                rel = item.lastPathComponent
            }
            entries.append(SkillFileEntry(relativePath: rel))
        }
        return entries.sorted { $0.relativePath < $1.relativePath }
    }

    public func readTextFile(at skillRootPath: String, relativePath: String) throws -> SkillFileContent {
        let url = try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0

        if !Self.looksLikeText(url: url) {
            return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .nonText)
        }
        if size > Self.textBufferLimitBytes {
            return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .tooLarge)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .text(text))
    }

    public func writeTextFile(at skillRootPath: String, relativePath: String, content: String) throws {
        let url = try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    public func absoluteFileURL(skillRootPath: String, relativePath: String) throws -> URL {
        try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
    }

    private func resolvedFileURL(skillRootPath: String, relativePath: String) throws -> URL {
        let root = URL(fileURLWithPath: skillRootPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = root.path
        guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else {
            throw EditorError.pathEscape
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EditorError.fileMissing
        }
        return url
    }

    private static func looksLikeText(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExts: Set<String> = [
            "md", "txt", "json", "yml", "yaml", "toml", "swift", "py", "js", "ts",
            "sh", "zsh", "bash", "css", "html", "xml", "csv", "svg", "gitignore",
        ]
        if textExts.contains(ext) || url.lastPathComponent == "SKILL.md" {
            return true
        }
        if ext.isEmpty {
            // Heuristic: no NUL in first 512 bytes
            guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? handle.close() }
            let sample = handle.readData(ofLength: 512)
            return !sample.contains(0)
        }
        return false
    }
}

public enum InstallError: Error, Equatable {
    case sourceNotFound
    case packageNotFound(String)
    case rootNotFound(String)
}

public enum EditorError: Error, Equatable {
    case rootMissing
    case fileMissing
    case pathEscape
}

public struct SkillFileEntry: Identifiable, Equatable, Sendable {
    public var id: String { relativePath }
    public let relativePath: String

    public init(relativePath: String) {
        self.relativePath = relativePath
    }
}

public enum SkillFileKind: Equatable, Sendable {
    case text(String)
    case nonText
    case tooLarge
}

public struct SkillFileContent: Equatable, Sendable {
    public let relativePath: String
    public let byteSize: Int
    public let kind: SkillFileKind

    public init(relativePath: String, byteSize: Int, kind: SkillFileKind) {
        self.relativePath = relativePath
        self.byteSize = byteSize
        self.kind = kind
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
    public let appliedCommitSHA: String?
    public let fileDigests: [FileDigestRecord]

    public init(
        id: String,
        onDiskPath: String,
        skillRootPath: String,
        adapterIds: [String],
        appliedCommitSHA: String? = nil,
        fileDigests: [FileDigestRecord] = []
    ) {
        self.id = id
        self.onDiskPath = onDiskPath
        self.skillRootPath = skillRootPath
        self.adapterIds = adapterIds
        self.appliedCommitSHA = appliedCommitSHA
        self.fileDigests = fileDigests
    }
}

public struct InstallRootOption: Identifiable, Equatable, Sendable {
    public let id: String
    public let path: String
    public let isDefaultSuggestion: Bool

    public init(id: String, path: String, isDefaultSuggestion: Bool) {
        self.id = id
        self.path = path
        self.isDefaultSuggestion = isDefaultSuggestion
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

public struct SkillSourceSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let normalizedUrl: String
    public let branch: String

    public init(id: String, displayName: String, normalizedUrl: String, branch: String) {
        self.id = id
        self.displayName = displayName
        self.normalizedUrl = normalizedUrl
        self.branch = branch
    }
}

public enum PackageInstallStatus: String, Equatable, Sendable {
    case notInstalled
    case installed
}

public struct SourcePackage: Identifiable, Equatable, Sendable {
    public var id: String { pathInRepo }
    public let pathInRepo: String
    public let displayName: String
    public let installStatus: PackageInstallStatus

    public init(pathInRepo: String, displayName: String, installStatus: PackageInstallStatus) {
        self.pathInRepo = pathInRepo
        self.displayName = displayName
        self.installStatus = installStatus
    }
}

public struct SourceDetail: Equatable, Sendable {
    public let summary: SkillSourceSummary
    public let packages: [SourcePackage]

    public init(summary: SkillSourceSummary, packages: [SourcePackage]) {
        self.summary = summary
        self.packages = packages
    }
}

import Foundation

public struct SkillRootRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var adapterIds: [String]
    public var path: String
    public var scope: String
    public var projectId: String?

    public init(
        id: String,
        adapterIds: [String],
        path: String,
        scope: String = "global",
        projectId: String? = nil
    ) {
        self.id = id
        self.adapterIds = adapterIds
        self.path = path
        self.scope = scope
        self.projectId = projectId
    }
}

public struct LocationRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var skillRootId: String
    public var onDiskPath: String
    public var displayName: String
    public var logicalSkillId: String?
    public var appliedCommitSHA: String?
    public var fileDigests: [FileDigestRecord]

    public init(
        id: String,
        skillRootId: String,
        onDiskPath: String,
        displayName: String,
        logicalSkillId: String? = nil,
        appliedCommitSHA: String? = nil,
        fileDigests: [FileDigestRecord] = []
    ) {
        self.id = id
        self.skillRootId = skillRootId
        self.onDiskPath = onDiskPath
        self.displayName = displayName
        self.logicalSkillId = logicalSkillId
        self.appliedCommitSHA = appliedCommitSHA
        self.fileDigests = fileDigests
    }
}

public struct FileDigestRecord: Codable, Equatable, Sendable {
    public var relPath: String
    public var sha256: String

    public init(relPath: String, sha256: String) {
        self.relPath = relPath
        self.sha256 = sha256
    }
}

public struct LogicalSkillRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var sourceId: String
    public var skillPathInRepo: String
    public var displayName: String

    public init(id: String, sourceId: String, skillPathInRepo: String, displayName: String) {
        self.id = id
        self.sourceId = sourceId
        self.skillPathInRepo = skillPathInRepo
        self.displayName = displayName
    }
}

public struct ProjectRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var rootPath: String
    public var addedAt: Date

    public init(id: String, rootPath: String, addedAt: Date = Date()) {
        self.id = id
        self.rootPath = rootPath
        self.addedAt = addedAt
    }
}

public struct SkillSourceRecord: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var normalizedUrl: String
    public var branch: String
    public var displayName: String
    public var lastFetchAt: Date
    public var cachePath: String
    public var commitSHA: String

    public init(
        id: String,
        normalizedUrl: String,
        branch: String,
        displayName: String,
        lastFetchAt: Date = Date(),
        cachePath: String,
        commitSHA: String
    ) {
        self.id = id
        self.normalizedUrl = normalizedUrl
        self.branch = branch
        self.displayName = displayName
        self.lastFetchAt = lastFetchAt
        self.cachePath = cachePath
        self.commitSHA = commitSHA
    }
}

struct SidecarSnapshot: Codable, Equatable {
    var skillRoots: [SkillRootRecord] = []
    var locations: [LocationRecord] = []
    var projects: [ProjectRecord] = []
    var sources: [SkillSourceRecord] = []
    var logicalSkills: [LogicalSkillRecord] = []
}

enum SidecarStore {
    private static let fileName = "library.json"

    static func load(from root: URL) throws -> SidecarSnapshot {
        let url = root.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return SidecarSnapshot()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SidecarSnapshot.self, from: data)
    }

    static func save(_ snapshot: SidecarSnapshot, to root: URL) throws {
        let url = root.appendingPathComponent(fileName)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }
}

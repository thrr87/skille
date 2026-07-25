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

    public init(
        id: String,
        skillRootId: String,
        onDiskPath: String,
        displayName: String,
        logicalSkillId: String? = nil
    ) {
        self.id = id
        self.skillRootId = skillRootId
        self.onDiskPath = onDiskPath
        self.displayName = displayName
        self.logicalSkillId = logicalSkillId
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

struct SidecarSnapshot: Codable, Equatable {
    var skillRoots: [SkillRootRecord] = []
    var locations: [LocationRecord] = []
    var projects: [ProjectRecord] = []
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

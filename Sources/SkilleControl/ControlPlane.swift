import Foundation

/// Primary control-plane seam: UI and tests drive Skille through this API.
/// Inject `sidecarRoot` (temp dir in tests; Application Support in the app).
public struct ControlPlane: Sendable {
    public let sidecarRoot: URL

    public init(sidecarRoot: URL) throws {
        self.sidecarRoot = sidecarRoot
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
        []
    }
}

public struct SkillSummary: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

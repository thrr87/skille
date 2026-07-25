import Foundation

public protocol GitFetching: Sendable {
    /// Materialize `url`@`branch` into `destination` (a cache directory).
    /// Returns the resolved commit SHA (or a stub token in tests).
    func fetch(url: String, branch: String, into destination: URL) throws -> String
}

/// Production fetch via `git clone --depth 1`.
public struct ProcessGitFetch: GitFetching {
    public init() {}

    public func fetch(url: String, branch: String, into destination: URL) throws -> String {
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let clone = Process()
        clone.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        clone.arguments = [
            "clone", "--depth", "1", "--branch", branch, url, destination.path,
        ]
        try clone.run()
        clone.waitUntilExit()
        guard clone.terminationStatus == 0 else {
            throw GitFetchError.cloneFailed(status: clone.terminationStatus)
        }

        let rev = Process()
        rev.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        rev.arguments = ["-C", destination.path, "rev-parse", "HEAD"]
        let pipe = Pipe()
        rev.standardOutput = pipe
        try rev.run()
        rev.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let sha = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard rev.terminationStatus == 0, !sha.isEmpty else {
            throw GitFetchError.cloneFailed(status: rev.terminationStatus)
        }
        return sha
    }
}

/// Test double: copies a local fixture directory into the cache (no network).
/// `commitSHA` is mutable so tests can simulate a newer remote tip.
public final class FixtureGitFetch: GitFetching, @unchecked Sendable {
    public let fixtureRoot: URL
    public var commitSHA: String

    public init(fixtureRoot: URL, commitSHA: String = "deadbeef") {
        self.fixtureRoot = fixtureRoot
        self.commitSHA = commitSHA
    }

    public func fetch(url: String, branch: String, into destination: URL) throws -> String {
        _ = url
        _ = branch
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.copyItem(at: fixtureRoot, to: destination)
        return commitSHA
    }
}

public enum GitFetchError: Error, Equatable {
    case cloneFailed(status: Int32)
}

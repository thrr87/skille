import Foundation
import Testing
@testable import SkilleControl

struct SkillSourceTests {
    @Test func failedFetchLeavesSidecarUnchanged() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("stable-source", isDirectory: true)
        try writePackage(at: repo.appendingPathComponent("stable"), name: "stable")
        let git = ToggleGitFetch(fixtureRoot: repo)
        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: git
        )
        let source = try plane.addSource(url: "https://example.com/stable.git")
        let sidecar = fixture.sidecar.appendingPathComponent("library.json")
        let sidecarBefore = try Data(contentsOf: sidecar)
        git.shouldFail = true

        #expect(throws: GitFetchError.cloneFailed(status: 1)) {
            try plane.addSource(url: "https://example.com/stable.git")
        }
        #expect(try Data(contentsOf: sidecar) == sidecarBefore)
        #expect(plane.listSources() == [source])
        #expect(plane.sourceDetail(id: source.id)?.packages.map(\.displayName) == ["stable"])
    }

    @Test func sourceDetailReportsEveryInstalledLocationFromProvenance() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("locations", isDirectory: true)
        try writePackage(at: repo.appendingPathComponent("deploy"), name: "deploy")
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        let source = try plane.addSource(url: "https://example.com/locations.git")
        _ = try plane.scan()
        let roots = plane.availableInstallRoots().filter {
            $0.path.hasSuffix("/.agents/skills") || $0.path.hasSuffix("/.cursor/skills")
        }
        #expect(roots.count == 2)

        try plane.install(
            sourceId: source.id,
            packagePaths: ["deploy"],
            skillRootIds: roots.map(\.id)
        )
        #expect(
            plane.sourceDetail(id: source.id)?.packages.first?.installedLocations.count == 2
        )
        _ = try plane.scan()

        let package = try #require(plane.sourceDetail(id: source.id)?.packages.first)
        #expect(package.installStatus == .installed)
        #expect(package.installedLocations.count == 2)
        #expect(Set(package.installedLocations.map(\.onDiskPath)).count == 2)
        #expect(
            package.installedLocations.contains {
                $0.skillRootPath.hasSuffix("/.cursor/skills")
                    && $0.adapterIds.contains("cursor")
            }
        )
        #expect(
            package.installedLocations.contains {
                $0.skillRootPath.hasSuffix("/.agents/skills")
            }
        )
    }

    @Test func addSourceListsPackagesFromFixtureRepo() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("repo-fixture", isDirectory: true)
        try writePackage(at: repo.appendingPathComponent("skills/alpha"), name: "alpha")
        try writePackage(at: repo.appendingPathComponent("skills/beta"), name: "beta")

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        let source = try plane.addSource(url: "https://example.com/skills.git", branch: "main")
        #expect(plane.listSources().count == 1)
        #expect(source.branch == "main")

        let detail = try #require(plane.sourceDetail(id: source.id))
        #expect(detail.packages.count == 2)
        #expect(detail.packages.map(\.pathInRepo).sorted() == ["skills/alpha", "skills/beta"])
        #expect(detail.packages.allSatisfy { $0.installStatus == .notInstalled })
    }

    @Test func addSourceDefaultsBranchToMain() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("single", isDirectory: true)
        try writePackage(at: repo.appendingPathComponent("solo-skill"), name: "solo-skill")

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        let source = try plane.addSource(url: "https://example.com/solo.git")
        #expect(source.branch == "main")
        #expect(plane.sourceDetail(id: source.id)?.packages.count == 1)
    }

    private func writePackage(at dir: URL, name: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try """
        ---
        name: \(name)
        description: fixture
        ---
        # \(name)
        """.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }
}

private final class ToggleGitFetch: GitFetching, @unchecked Sendable {
    let fixtureRoot: URL
    var shouldFail = false

    init(fixtureRoot: URL) {
        self.fixtureRoot = fixtureRoot
    }

    func fetch(url: String, branch: String, into destination: URL) throws -> String {
        _ = url
        _ = branch
        if shouldFail {
            try FileManager.default.createDirectory(
                at: destination,
                withIntermediateDirectories: true
            )
            try "partial".write(
                to: destination.appendingPathComponent("partial"),
                atomically: true,
                encoding: .utf8
            )
            throw GitFetchError.cloneFailed(status: 1)
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.copyItem(at: fixtureRoot, to: destination)
        return "deadbeef"
    }
}

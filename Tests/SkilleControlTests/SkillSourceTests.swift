import Foundation
import Testing
@testable import SkilleControl

struct SkillSourceTests {
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

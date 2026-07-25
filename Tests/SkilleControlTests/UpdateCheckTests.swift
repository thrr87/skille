import Foundation
import Testing
@testable import SkilleControl

struct UpdateCheckTests {
    @Test func cleanInstallHasNoBadges() throws {
        let env = try InstalledFixture(tip: "sha1")
        defer { env.cleanup() }

        let plane = env.plane
        _ = try plane.checkUpdates()
        let skill = try #require(plane.listSkills().first)
        #expect(skill.hasUpdate == false)
        #expect(skill.isDirty == false)
    }

    @Test func newerRemoteTipMarksUpdate() throws {
        let env = try InstalledFixture(tip: "sha1")
        defer { env.cleanup() }

        env.git.commitSHA = "sha2"
        let result = try env.plane.checkUpdates()
        #expect(result.updatesFound >= 1)

        let skill = try #require(env.plane.listSkills().first)
        #expect(skill.hasUpdate == true)
        #expect(skill.isDirty == false)
    }

    @Test func localEditMarksDirty() throws {
        let env = try InstalledFixture(tip: "sha1")
        defer { env.cleanup() }

        let skillMD = env.installedSkill.appendingPathComponent("SKILL.md")
        try "# changed locally\n".write(to: skillMD, atomically: true, encoding: .utf8)

        _ = try env.plane.checkUpdates()
        let skill = try #require(env.plane.listSkills().first)
        #expect(skill.isDirty == true)
        #expect(skill.hasUpdate == false)
    }
}

/// Shared install-from-fixture setup for update/dirty tests.
struct InstalledFixture {
    let fixture: TestFixture
    let git: FixtureGitFetch
    let plane: ControlPlane
    let installedSkill: URL

    init(tip: String) throws {
        fixture = try TestFixture()
        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let pkg = repo.appendingPathComponent("skills/handy")
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try "---\nname: handy\ndescription: d\n---\n# Handy\n".write(
            to: pkg.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agents = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)

        git = FixtureGitFetch(fixtureRoot: repo, commitSHA: tip)
        plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: git
        )
        let source = try plane.addSource(url: "https://example.com/lib.git", branch: "main")
        _ = try plane.scan()
        let rootID = try #require(
            plane.availableInstallRoots().first { $0.path.hasSuffix("/.agents/skills") }?.id
        )
        try plane.install(
            sourceId: source.id,
            packagePaths: ["skills/handy"],
            skillRootIds: [rootID]
        )
        installedSkill = agents.appendingPathComponent("handy")
    }

    func cleanup() { fixture.cleanup() }
}

import Foundation
import Testing
@testable import SkilleControl

struct InstallTests {
    @Test func installCopiesPackageAndRecordsProvenance() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let pkg = repo.appendingPathComponent("skills/handy")
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try "---\nname: handy\ndescription: d\n---\n# Handy\n".write(
            to: pkg.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try "note".write(to: pkg.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agentsRoot = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: agentsRoot, withIntermediateDirectories: true)

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo, commitSHA: "abc123")
        )
        let source = try plane.addSource(url: "https://example.com/lib.git", branch: "main")
        _ = try plane.scan()

        let roots = plane.availableInstallRoots()
        #expect(roots.contains { $0.path.hasSuffix("/.agents/skills") && $0.isDefaultSuggestion })

        let rootID = try #require(roots.first { $0.path.hasSuffix("/.agents/skills") }?.id)
        try plane.install(
            sourceId: source.id,
            packagePaths: ["skills/handy"],
            skillRootIds: [rootID]
        )

        let installed = agentsRoot.appendingPathComponent("handy/SKILL.md")
        #expect(FileManager.default.fileExists(atPath: installed.path))
        #expect(FileManager.default.fileExists(atPath: agentsRoot.appendingPathComponent("handy/notes.txt").path))

        let skills = plane.listSkills()
        #expect(skills.count == 1)
        #expect(skills[0].isOrphan == false)
        #expect(skills[0].displayName == "handy")

        let detail = try #require(plane.skillDetail(id: skills[0].id))
        #expect(detail.locations.count == 1)
        #expect(detail.locations[0].appliedCommitSHA == "abc123")
        #expect(detail.locations[0].fileDigests.count >= 2)
    }

    @Test func installIntoTwoRootsGroupsAsOneLogicalSkill() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let pkg = repo.appendingPathComponent("one")
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try "# one\n".write(to: pkg.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor/skills"),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".agents/skills"),
            withIntermediateDirectories: true
        )

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        let source = try plane.addSource(url: "https://example.com/one.git")
        _ = try plane.scan()
        let rootIds = plane.availableInstallRoots().map(\.id)
        #expect(rootIds.count >= 2)

        try plane.install(sourceId: source.id, packagePaths: ["one"], skillRootIds: rootIds)

        let skills = plane.listSkills()
        #expect(skills.count == 1)
        #expect(skills[0].locationCount == 2)
        #expect(skills[0].isOrphan == false)
    }
}

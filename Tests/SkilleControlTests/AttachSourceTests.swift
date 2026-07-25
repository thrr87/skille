import Foundation
import Testing
@testable import SkilleControl

struct AttachSourceTests {
    @Test func attachCreatesLogicalSkillForOrphan() throws {
        let env = try OrphanFixture()
        defer { env.cleanup() }

        let skill = try #require(env.plane.listSkills().first)
        #expect(skill.isOrphan)

        try env.plane.attachSource(
            locationId: skill.id,
            url: "https://example.com/skills.git",
            branch: "main",
            pathInRepo: "skills/orphan-skill",
            confirmJoin: false
        )

        let after = try #require(env.plane.listSkills().first)
        #expect(after.isOrphan == false)
        #expect(after.displayName == "orphan-skill")
    }

    @Test func attachJoinsExistingLogicalSkillWhenConfirmed() throws {
        let env = try OrphanFixture()
        defer { env.cleanup() }

        // Install same provenance into another root first
        try FileManager.default.createDirectory(
            at: env.fixture.home.appendingPathComponent(".cursor/skills"),
            withIntermediateDirectories: true
        )
        _ = try env.plane.scan()
        let source = try env.plane.addSource(url: "https://example.com/skills.git", branch: "main")
        let roots = env.plane.availableInstallRoots()
        let cursorRoot = try #require(roots.first { $0.path.hasSuffix("/.cursor/skills") }?.id)
        try env.plane.install(
            sourceId: source.id,
            packagePaths: ["skills/orphan-skill"],
            skillRootIds: [cursorRoot]
        )

        let orphan = try #require(env.plane.listSkills().first { $0.isOrphan })
        let preview = try env.plane.previewAttachSource(
            locationId: orphan.id,
            url: "https://example.com/skills.git",
            branch: "main",
            pathInRepo: "skills/orphan-skill"
        )
        guard case let .joinExisting(logicalId, _) = preview else {
            Issue.record("expected joinExisting")
            return
        }

        #expect(throws: AttachSourceError.confirmationRequired) {
            try env.plane.attachSource(
                locationId: orphan.id,
                url: "https://example.com/skills.git",
                branch: "main",
                pathInRepo: "skills/orphan-skill",
                confirmJoin: false
            )
        }

        try env.plane.attachSource(
            locationId: orphan.id,
            url: "https://example.com/skills.git",
            branch: "main",
            pathInRepo: "skills/orphan-skill",
            confirmJoin: true
        )

        let skills = env.plane.listSkills()
        #expect(skills.count == 1)
        #expect(skills[0].id == logicalId)
        #expect(skills[0].locationCount == 2)
        #expect(skills[0].isOrphan == false)
    }
}

struct OrphanFixture {
    let fixture: TestFixture
    let plane: ControlPlane
    let git: FixtureGitFetch

    init() throws {
        fixture = try TestFixture()
        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let pkg = repo.appendingPathComponent("skills/orphan-skill")
        try FileManager.default.createDirectory(at: pkg, withIntermediateDirectories: true)
        try """
        ---
        name: orphan-skill
        description: orphan
        ---
        # Orphan
        """.write(to: pkg.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agents = fixture.home.appendingPathComponent(".agents/skills/orphan-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: pkg.appendingPathComponent("SKILL.md"),
            to: agents.appendingPathComponent("SKILL.md")
        )

        git = FixtureGitFetch(fixtureRoot: repo, commitSHA: "attach1")
        plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: git
        )
        _ = try plane.scan()
    }

    func cleanup() { fixture.cleanup() }
}

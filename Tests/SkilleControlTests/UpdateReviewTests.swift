import Foundation
import Testing
@testable import SkilleControl

struct UpdateReviewTests {
    @Test func acceptAppliesRemoteWhenClean() throws {
        let env = try ReviewFixture()
        defer { env.cleanup() }

        try env.bumpRemote(content: "# Handy v2\n")
        _ = try env.plane.checkUpdates()

        let review = try env.plane.prepareUpdateReview(locationId: env.locationId)
        #expect(review.isDirty == false)
        #expect(review.files.contains { $0.relativePath == "SKILL.md" && $0.status == .modified })

        try env.plane.acceptUpdate(locationId: env.locationId, discardLocal: false)
        let disk = try String(contentsOf: env.skillMD, encoding: .utf8)
        #expect(disk == "# Handy v2\n")
        let skill = try #require(env.plane.listSkills().first)
        #expect(skill.hasUpdate == false)
        #expect(skill.isDirty == false)
    }

    @Test func rejectLeavesDiskUnchanged() throws {
        let env = try ReviewFixture()
        defer { env.cleanup() }

        try env.bumpRemote(content: "# Handy v2\n")
        _ = try env.plane.checkUpdates()
        _ = try env.plane.prepareUpdateReview(locationId: env.locationId)
        try env.plane.rejectUpdate(locationId: env.locationId)

        let disk = try String(contentsOf: env.skillMD, encoding: .utf8)
        #expect(disk.contains("# Handy"))
        #expect(!disk.contains("v2"))
        #expect(env.plane.listSkills().first?.hasUpdate == true)
    }

    @Test func dirtyBlocksAcceptUntilDiscard() throws {
        let env = try ReviewFixture()
        defer { env.cleanup() }

        try "# local edit\n".write(to: env.skillMD, atomically: true, encoding: .utf8)
        try env.bumpRemote(content: "# Handy v2\n")
        _ = try env.plane.checkUpdates()

        let review = try env.plane.prepareUpdateReview(locationId: env.locationId)
        #expect(review.isDirty == true)

        #expect(throws: UpdateReviewError.dirtyRequiresDiscard) {
            try env.plane.acceptUpdate(locationId: env.locationId, discardLocal: false)
        }

        try env.plane.acceptUpdate(locationId: env.locationId, discardLocal: true)
        let disk = try String(contentsOf: env.skillMD, encoding: .utf8)
        #expect(disk == "# Handy v2\n")
        #expect(env.plane.listSkills().first?.isDirty == false)
    }
}

struct ReviewFixture {
    let fixture: TestFixture
    let git: FixtureGitFetch
    let plane: ControlPlane
    let repoPackage: URL
    let skillMD: URL
    let locationId: String
    let sourceId: String

    init() throws {
        fixture = try TestFixture()
        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        repoPackage = repo.appendingPathComponent("skills/handy")
        try FileManager.default.createDirectory(at: repoPackage, withIntermediateDirectories: true)
        try "# Handy\n".write(
            to: repoPackage.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agents = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)

        git = FixtureGitFetch(fixtureRoot: repo, commitSHA: "sha1")
        plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: git
        )
        let source = try plane.addSource(url: "https://example.com/lib.git", branch: "main")
        sourceId = source.id
        _ = try plane.scan()
        let rootID = try #require(
            plane.availableInstallRoots().first { $0.path.hasSuffix("/.agents/skills") }?.id
        )
        try plane.install(
            sourceId: source.id,
            packagePaths: ["skills/handy"],
            skillRootIds: [rootID]
        )
        skillMD = agents.appendingPathComponent("handy/SKILL.md")
        locationId = try #require(plane.skillDetail(id: plane.listSkills()[0].id)?.locations.first?.id)
    }

    func bumpRemote(content: String) throws {
        try content.write(
            to: repoPackage.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        git.commitSHA = "sha2"
    }

    func cleanup() { fixture.cleanup() }
}

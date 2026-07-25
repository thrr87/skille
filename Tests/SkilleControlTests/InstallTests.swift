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

    @Test func writableRootOptionsCreateMissingGlobalAndProjectRoots() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let package = repo.appendingPathComponent("one", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "# one\n".write(
            to: package.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let project = fixture.root.appendingPathComponent("project", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        try plane.addProject(path: project.path)
        let source = try plane.addSource(url: "https://example.com/one.git")
        _ = try plane.scan()

        let roots = plane.availableInstallRoots()
        let globalPath = fixture.home.appendingPathComponent(".cursor/skills").path
        let projectPath = project.appendingPathComponent(".cursor/skills").path
        let global = try #require(roots.first { $0.path == globalPath })
        let scoped = try #require(roots.first { $0.path == projectPath })
        #expect(global.scope == "global")
        #expect(global.adapterIds == ["cursor"])
        #expect(scoped.scope == "project")
        #expect(scoped.adapterIds == ["cursor"])

        try plane.install(
            sourceId: source.id,
            packagePaths: ["one"],
            skillRootIds: [global.id, scoped.id]
        )

        #expect(FileManager.default.fileExists(atPath: "\(globalPath)/one/SKILL.md"))
        #expect(FileManager.default.fileExists(atPath: "\(projectPath)/one/SKILL.md"))
    }

    @Test func installRefusesAllConflictsBeforeChangingAnyDestination() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let package = repo.appendingPathComponent("handy", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "# New\n".write(
            to: package.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agentsRoot = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        let existing = agentsRoot.appendingPathComponent("handy", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        try "# Original\n".write(
            to: existing.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        let source = try plane.addSource(url: "https://example.com/handy.git")
        _ = try plane.scan()
        let roots = plane.availableInstallRoots()

        #expect(throws: InstallError.destinationConflict([existing.path])) {
            try plane.install(
                sourceId: source.id,
                packagePaths: ["handy"],
                skillRootIds: roots.map(\.id)
            )
        }

        #expect(
            try String(contentsOf: existing.appendingPathComponent("SKILL.md"), encoding: .utf8)
                == "# Original\n"
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: fixture.home.appendingPathComponent(".cursor/skills/handy").path
            )
        )
        #expect(plane.listSkills().allSatisfy { $0.isOrphan })

        try plane.install(
            sourceId: source.id,
            packagePaths: ["handy"],
            skillRootIds: roots.map(\.id),
            replaceExisting: true
        )

        #expect(
            try String(contentsOf: existing.appendingPathComponent("SKILL.md"), encoding: .utf8)
                == "# New\n"
        )
        let installed = try #require(plane.listSkills().first { !$0.isOrphan })
        #expect(installed.locationCount == roots.count)
        let hiddenArtifacts = try FileManager.default.contentsOfDirectory(atPath: agentsRoot.path)
            .filter { $0.hasPrefix(".skille-") }
        #expect(hiddenArtifacts.isEmpty)
    }

    @Test func failedConfirmedReplacementRestoresEveryOriginalTree() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let repo = fixture.root.appendingPathComponent("src", isDirectory: true)
        let package = repo.appendingPathComponent("handy", isDirectory: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try "# New\n".write(
            to: package.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agentsRoot = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        let existing = agentsRoot.appendingPathComponent("handy", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
        try "# Original\n".write(
            to: existing.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let project = fixture.root.appendingPathComponent("project", isDirectory: true)
        let readOnlyRoot = project.appendingPathComponent(".cursor/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: readOnlyRoot, withIntermediateDirectories: true)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o555],
            ofItemAtPath: readOnlyRoot.path
        )
        defer {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: readOnlyRoot.path
            )
        }

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home,
            git: FixtureGitFetch(fixtureRoot: repo)
        )
        try plane.addProject(path: project.path)
        let source = try plane.addSource(url: "https://example.com/handy.git")
        _ = try plane.scan()
        let roots = plane.availableInstallRoots()
        let global = try #require(roots.first { $0.path == agentsRoot.path })
        let scoped = try #require(roots.first { $0.path == readOnlyRoot.path })

        do {
            try plane.install(
                sourceId: source.id,
                packagePaths: ["handy"],
                skillRootIds: [global.id, scoped.id],
                replaceExisting: true
            )
            Issue.record("Install unexpectedly succeeded in a read-only Skill root")
        } catch {}

        #expect(
            try String(contentsOf: existing.appendingPathComponent("SKILL.md"), encoding: .utf8)
                == "# Original\n"
        )
        #expect(plane.listSkills().allSatisfy { $0.isOrphan })
    }
}

import Foundation
import Testing
@testable import SkilleControl

struct NewSkillTests {
    @Test func createSkillWritesValidAgentSkillsPackageAndScanFindsIt() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let agents = fixture.home.appendingPathComponent(".agents/skills", isDirectory: true)
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        let rootID = try #require(
            plane.availableInstallRoots().first { $0.path.hasSuffix("/.agents/skills") }?.id
        )

        try plane.createSkill(
            name: "my-skill",
            description: "Handles: \"quoted\" text\nUses café.",
            skillRootIds: [rootID]
        )

        let skillMD = agents.appendingPathComponent("my-skill/SKILL.md")
        let text = try String(contentsOf: skillMD, encoding: .utf8)
        #expect(text == """
        ---
        name: "my-skill"
        description: "Handles: \\"quoted\\" text\\nUses café."
        ---
        # my-skill

        Handles: "quoted" text
        Uses café.
        """)

        _ = try plane.scan()
        let skills = plane.listSkills()
        #expect(skills.contains { $0.displayName == "my-skill" && $0.isOrphan })
    }

    @Test func createSkillRejectsInvalidFrontmatterValuesBeforeWriting() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        let rootID = try #require(
            plane.availableInstallRoots().first { $0.path.hasSuffix("/.agents/skills") }?.id
        )

        for invalidName in [
            "", "Uppercase", "-leading", "trailing-", "two--hyphens", "under_score",
            String(repeating: "a", count: 65),
        ] {
            #expect(throws: AuthoringError.invalidName) {
                try plane.createSkill(
                    name: invalidName,
                    description: "Valid description",
                    skillRootIds: [rootID]
                )
            }
        }
        #expect(throws: AuthoringError.invalidDescription) {
            try plane.createSkill(name: "valid-name", description: "  \n", skillRootIds: [rootID])
        }
        #expect(
            FileManager.default.fileExists(
                atPath: fixture.home.appendingPathComponent(".agents/skills").path
            ) == false
        )
    }

    @Test func createSkillPreflightsEveryDestinationBeforeWriting() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        let roots = plane.availableInstallRoots()
        let agents = try #require(roots.first { $0.path.hasSuffix("/.agents/skills") })
        let cursor = try #require(roots.first { $0.path.hasSuffix("/.cursor/skills") })
        let conflict = URL(fileURLWithPath: cursor.path)
            .appendingPathComponent("new-skill", isDirectory: true)
        try FileManager.default.createDirectory(at: conflict, withIntermediateDirectories: true)
        try "original".write(
            to: conflict.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        #expect(throws: AuthoringError.alreadyExists(conflict.path)) {
            try plane.createSkill(
                name: "new-skill",
                description: "Valid description",
                skillRootIds: [agents.id, cursor.id]
            )
        }
        #expect(
            FileManager.default.fileExists(
                atPath: URL(fileURLWithPath: agents.path)
                    .appendingPathComponent("new-skill").path
            ) == false
        )
        #expect(
            try String(contentsOf: conflict.appendingPathComponent("SKILL.md"), encoding: .utf8)
                == "original"
        )
    }
}

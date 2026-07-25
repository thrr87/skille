import Foundation
import Testing
@testable import SkilleControl

struct NewSkillTests {
    @Test func createSkillWritesAgentSkillsScaffold() throws {
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
            description: "Does a thing",
            skillRootIds: [rootID]
        )

        let skillMD = agents.appendingPathComponent("my-skill/SKILL.md")
        let text = try String(contentsOf: skillMD, encoding: .utf8)
        #expect(text.contains("name: my-skill"))
        #expect(text.contains("description: Does a thing"))

        _ = try plane.scan()
        let skills = plane.listSkills()
        #expect(skills.contains { $0.displayName == "my-skill" && $0.isOrphan })
    }
}

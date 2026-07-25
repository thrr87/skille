import Foundation
import Testing
@testable import SkilleControl

struct ProjectsTests {
    @Test func scanIncludesSkillsFromAddedProjectOnly() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let project = fixture.root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeProjectSkill(at: project, relativeRoot: ".agents/skills", name: "proj-skill")

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        #expect(plane.listSkills().isEmpty)

        try plane.addProject(path: project.path)
        #expect(plane.listProjects().map(\.rootPath) == [project.path])

        let result = try plane.scan()
        #expect(result.skillsFound == 1)
        let skills = plane.listSkills()
        #expect(skills.count == 1)
        #expect(skills[0].displayName == "proj-skill")
        #expect(skills[0].isFromProject == true)
    }

    @Test func removeProjectDropsProjectSkillsOnRescan() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let project = fixture.root.appendingPathComponent("repo", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        try writeProjectSkill(at: project, relativeRoot: ".agents/skills", name: "temp")

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        try plane.addProject(path: project.path)
        _ = try plane.scan()
        #expect(plane.listSkills().count == 1)

        try plane.removeProject(id: plane.listProjects()[0].id)
        _ = try plane.scan()
        #expect(plane.listProjects().isEmpty)
        #expect(plane.listSkills().isEmpty)
    }

    private func writeProjectSkill(at project: URL, relativeRoot: String, name: String) throws {
        let dir = project
            .appendingPathComponent(relativeRoot, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "# \(name)\n".write(
            to: dir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }
}

import Foundation
import Testing
@testable import SkilleControl

struct SkillsInspectorTests {
    @Test func skillDetailListsLocationPaths() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        try fixture.writeSkill(relativeRoot: ".cursor/skills", name: "inspect-me", body: "# Hi\n")

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        let skills = plane.listSkills()
        #expect(skills.count == 1)

        let detail = try #require(plane.skillDetail(id: skills[0].id))
        #expect(detail.locations.count == 1)
        #expect(detail.locations[0].onDiskPath.hasSuffix("/.cursor/skills/inspect-me"))
        #expect(detail.summary.locationCount == detail.locations.count)
        #expect(detail.summary.isOrphan == true)
        #expect(detail.summary.adapterIds.contains("cursor"))
        #expect(detail.locations[0].adapterIds.contains("cursor"))
    }

    @Test func skillDetailClearsAfterRescanRemovesSkill() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )
        try fixture.writeSkill(relativeRoot: ".cursor/skills", name: "gone", body: "# Bye\n")

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        _ = try plane.scan()
        let id = try #require(plane.listSkills().first?.id)
        #expect(plane.skillDetail(id: id) != nil)

        try FileManager.default.removeItem(
            at: fixture.home.appendingPathComponent(".cursor/skills/gone")
        )
        _ = try plane.scan()

        #expect(plane.skillDetail(id: id) == nil)
        #expect(plane.listSkills().isEmpty)
    }
}

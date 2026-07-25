import Foundation
import Testing
@testable import SkilleControl

/// Temp-filesystem convention: unique temp dirs for home + sidecar;
/// never touch real Application Support or the real user home in unit tests.
struct ScanTests {
    @Test func scanDiscoversOrphanUnderGlobalAgentsSkills() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try fixture.writeSkill(
            relativeRoot: ".agents/skills",
            name: "demo-skill",
            body: """
            ---
            name: demo-skill
            description: A fixture skill
            ---
            # Demo
            """
        )
        // Presence secondary: skill root alone is enough for shared .agents
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home
        )
        let result = try plane.scan()

        #expect(result.skillsFound == 1)
        #expect(result.inventoryChanged == true)

        let skills = plane.listSkills()
        #expect(skills.count == 1)
        #expect(skills[0].displayName == "demo-skill")
        #expect(skills[0].isOrphan == true)
        #expect(skills[0].locationCount == 1)
    }

    @Test func scanDetectsAdapterViaConfigHomeEvenWithoutSkills() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".claude"),
            withIntermediateDirectories: true
        )

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home
        )
        let result = try plane.scan()

        #expect(result.detectedAdapterIds.contains("claude-code"))
        #expect(result.skillsFound == 0)
    }

    @Test func rescanUnchangedReportsNoInventoryChange() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        try fixture.writeSkill(relativeRoot: ".cursor/skills", name: "alpha", body: "# Alpha\n")
        try FileManager.default.createDirectory(
            at: fixture.home.appendingPathComponent(".cursor"),
            withIntermediateDirectories: true
        )

        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home
        )
        _ = try plane.scan()
        let second = try plane.scan()

        #expect(second.inventoryChanged == false)
        #expect(plane.listSkills().count == 1)
    }
}

struct TestFixture {
    let root: URL
    let home: URL
    let sidecar: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skille-fixture-\(UUID().uuidString)", isDirectory: true)
        home = root.appendingPathComponent("home", isDirectory: true)
        sidecar = root.appendingPathComponent("sidecar", isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sidecar, withIntermediateDirectories: true)
    }

    func writeSkill(relativeRoot: String, name: String, body: String) throws {
        let dir = home
            .appendingPathComponent(relativeRoot, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try body.write(
            to: dir.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}

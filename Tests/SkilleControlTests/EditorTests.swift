import Foundation
import Testing
@testable import SkilleControl

struct EditorTests {
    @Test func listAndReadWriteTextOnDisk() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skill = fixture.root.appendingPathComponent("skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try "# Hello\n".write(
            to: skill.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.createDirectory(
            at: skill.appendingPathComponent("refs"),
            withIntermediateDirectories: true
        )
        try "note".write(
            to: skill.appendingPathComponent("refs/note.txt"),
            atomically: true,
            encoding: .utf8
        )

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        let entries = try plane.listSkillFiles(at: skill.path)
        #expect(entries.map(\.relativePath).sorted() == ["SKILL.md", "refs/note.txt"])

        let loaded = try plane.readTextFile(at: skill.path, relativePath: "SKILL.md")
        guard case let .text(content) = loaded.kind else {
            Issue.record("expected text kind")
            return
        }
        #expect(content == "# Hello\n")

        try plane.writeTextFile(at: skill.path, relativePath: "SKILL.md", content: "# Edited\n")
        let disk = try String(
            contentsOf: skill.appendingPathComponent("SKILL.md"),
            encoding: .utf8
        )
        #expect(disk == "# Edited\n")
    }

    @Test func oversizedTextIsNotBuffered() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skill = fixture.root.appendingPathComponent("skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        let big = String(repeating: "a", count: ControlPlane.textBufferLimitBytes + 1)
        try big.write(to: skill.appendingPathComponent("big.txt"), atomically: true, encoding: .utf8)

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        let loaded = try plane.readTextFile(at: skill.path, relativePath: "big.txt")
        guard case .tooLarge = loaded.kind else {
            Issue.record("expected tooLarge")
            return
        }
    }

    @Test func binaryFileIsNonText() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skill = fixture.root.appendingPathComponent("skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try Data([0x00, 0x01, 0x02, 0xFF]).write(to: skill.appendingPathComponent("blob.bin"))

        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        let loaded = try plane.readTextFile(at: skill.path, relativePath: "blob.bin")
        guard case .nonText = loaded.kind else {
            Issue.record("expected nonText")
            return
        }
    }
}

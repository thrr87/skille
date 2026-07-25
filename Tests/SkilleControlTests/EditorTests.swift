import Foundation
import Testing
@testable import SkilleControl

struct EditorTests {
    @Test func dirtyNavigationRequiresSaveDiscardOrCancel() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skill = fixture.root.appendingPathComponent("skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        let file = skill.appendingPathComponent("SKILL.md")
        try "original".write(to: file, atomically: true, encoding: .utf8)
        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)

        var saved = EditorSession(controlPlane: plane)
        try saved.open(skillRootPath: skill.path, relativePath: "SKILL.md")
        saved.buffer = "saved"
        #expect(saved.requestNavigation() == false)
        #expect(saved.hasPendingNavigation)
        #expect(try saved.resolveNavigation(.save))
        #expect(try String(contentsOf: file, encoding: .utf8) == "saved")
        #expect(saved.isDirty == false)

        try "original".write(to: file, atomically: true, encoding: .utf8)
        var discarded = EditorSession(controlPlane: plane)
        try discarded.open(skillRootPath: skill.path, relativePath: "SKILL.md")
        discarded.buffer = "discarded"
        #expect(discarded.requestNavigation() == false)
        #expect(try discarded.resolveNavigation(.discard))
        #expect(try String(contentsOf: file, encoding: .utf8) == "original")
        #expect(discarded.buffer == "original")

        var cancelled = EditorSession(controlPlane: plane)
        try cancelled.open(skillRootPath: skill.path, relativePath: "SKILL.md")
        cancelled.buffer = "keep visible"
        #expect(cancelled.requestNavigation() == false)
        #expect(try cancelled.resolveNavigation(.cancel) == false)
        #expect(cancelled.buffer == "keep visible")
        #expect(cancelled.relativePath == "SKILL.md")
        #expect(cancelled.isDirty)
    }

    @Test func failedNavigationSaveKeepsDirtyBufferOpen() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }

        let skill = fixture.root.appendingPathComponent("skill", isDirectory: true)
        try FileManager.default.createDirectory(at: skill, withIntermediateDirectories: true)
        try "original".write(
            to: skill.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )
        let plane = try ControlPlane(sidecarRoot: fixture.sidecar, homeDirectory: fixture.home)
        var session = EditorSession(controlPlane: plane)
        try session.open(skillRootPath: skill.path, relativePath: "SKILL.md")
        session.buffer = "must survive"
        #expect(session.requestNavigation() == false)
        try FileManager.default.removeItem(at: skill)

        #expect(throws: (any Error).self) {
            try session.resolveNavigation(.save)
        }
        #expect(session.buffer == "must survive")
        #expect(session.relativePath == "SKILL.md")
        #expect(session.isDirty)
        #expect(session.hasPendingNavigation)
    }

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

import Foundation
import Testing
@testable import SkilleControl

/// Temp-filesystem convention: every control-plane test builds a unique
/// temporary sidecar root via `FileManager.default.temporaryDirectory`,
/// constructs `ControlPlane(sidecarRoot:)`, and cleans up in defer.
/// No real Application Support and no real git in unit tests.
struct ControlPlaneTests {
    @Test func opensEmptySidecarAndListsNoSkills() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("skille-test-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let plane = try ControlPlane(sidecarRoot: root)

        #expect(FileManager.default.fileExists(atPath: root.path))
        #expect(plane.listSkills().isEmpty)
        #expect(plane.sidecarRoot == root)
    }

    @Test func defaultSidecarRootLivesUnderApplicationSupport() {
        let url = ControlPlane.defaultSidecarRoot()
        #expect(url.path.contains("Application Support"))
        #expect(url.lastPathComponent == "Skille")
    }

    @Test func savedLibraryMarksThatInitialScanWasAccepted() throws {
        let fixture = try TestFixture()
        defer { fixture.cleanup() }
        let plane = try ControlPlane(
            sidecarRoot: fixture.sidecar,
            homeDirectory: fixture.home
        )

        #expect(plane.hasSavedLibrary == false)
        _ = try plane.scan()
        #expect(plane.hasSavedLibrary)
    }
}

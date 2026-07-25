import SwiftUI
import SkilleControl

@main
struct SkilleApp: App {
    private let controlPlane: ControlPlane

    init() {
        // ponytail: fatal on sidecar create is fine for v1 launch; surface error UI when install/scan land
        controlPlane = try! ControlPlane(sidecarRoot: ControlPlane.defaultSidecarRoot())
    }

    var body: some Scene {
        WindowGroup {
            LibraryShell(controlPlane: controlPlane)
        }
        .defaultSize(width: 960, height: 640)
    }
}

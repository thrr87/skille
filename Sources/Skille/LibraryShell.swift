import SwiftUI
import SkilleControl

/// Main window: Sources | Skills | Projects. Skills is home.
struct LibraryShell: View {
    let controlPlane: ControlPlane
    @State private var tab: LibraryTab = .skills

    var body: some View {
        TabView(selection: $tab) {
            SourcesStub()
                .tabItem { Label("Sources", systemImage: "shippingbox") }
                .tag(LibraryTab.sources)
            SkillsHome(skills: controlPlane.listSkills())
                .tabItem { Label("Skills", systemImage: "square.stack.3d.up") }
                .tag(LibraryTab.skills)
            ProjectsStub()
                .tabItem { Label("Projects", systemImage: "folder") }
                .tag(LibraryTab.projects)
        }
        .frame(minWidth: 720, minHeight: 480)
        .toolbar {
            ToolbarItemGroup {
                Button("Scan") {}
                    .disabled(true)
                Button("Add Source") {}
                    .disabled(true)
                Button("New Skill") {}
                    .disabled(true)
            }
        }
    }
}

private enum LibraryTab: Hashable {
    case sources, skills, projects
}

struct SkillsHome: View {
    let skills: [SkillSummary]

    var body: some View {
        if skills.isEmpty {
            SkillsEmptyState()
        } else {
            Text("Skills")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct SkillsEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No skills yet")
                    .font(.title2.weight(.semibold))
                Text("Scan finds skills already on disk, or add a Skill Source and a Project to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }
            HStack(spacing: 12) {
                Button("Add Source") {}
                    .disabled(true)
                Button("Add Project") {}
                    .disabled(true)
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct SourcesStub: View {
    var body: some View {
        ContentUnavailableView(
            "Sources",
            systemImage: "shippingbox",
            description: Text("Add a Skill Source to install from git.")
        )
    }
}

private struct ProjectsStub: View {
    var body: some View {
        ContentUnavailableView(
            "Projects",
            systemImage: "folder",
            description: Text("Add a project folder to include its skill roots.")
        )
    }
}

#Preview {
    LibraryShell(
        controlPlane: try! ControlPlane(
            sidecarRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("skille-preview")
        )
    )
}

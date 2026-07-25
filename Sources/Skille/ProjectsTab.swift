import SwiftUI
import AppKit
import SkilleControl

struct ProjectsTab: View {
    let controlPlane: ControlPlane
    var onChanged: () -> Void
    @State private var projects: [ProjectRecord] = []

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("No projects", systemImage: "folder")
                    } description: {
                        Text("Add a project folder to include its skill roots in Scan.")
                    } actions: {
                        Button("Add Project…", action: add)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(projects) { project in
                            HStack {
                                Text(project.rootPath)
                                    .font(.body.monospaced())
                                    .textSelection(.enabled)
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    remove(project)
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(project.rootPath)
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add…", action: add)
                        .accessibilityLabel("Add project")
                }
            }
        }
        .onAppear { reload() }
    }

    private func reload() {
        projects = controlPlane.listProjects()
    }

    private func add() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add Project"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? controlPlane.addProject(path: url.path)
        reload()
        onChanged()
    }

    private func remove(_ project: ProjectRecord) {
        try? controlPlane.removeProject(id: project.id)
        reload()
        onChanged()
    }
}

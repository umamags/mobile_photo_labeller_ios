import SwiftUI

/// Lists saved projects. Tap one to open it; swipe to delete. Deleting removes only the project,
/// never the photos and videos in the library.
struct ProjectListView: View {
    let onOpen: (MovieProject) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var projects: [MovieProject] = []
    @State private var pendingDelete: MovieProject?
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            List {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No projects yet",
                        systemImage: "folder",
                        description: Text("Save a project from Create Video to see it here.")
                    )
                }
                ForEach(projects) { project in
                    Button {
                        onOpen(project)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                            Text("\(project.clips.count) items · \(project.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            pendingDelete = project
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task { reload() }
            .alert("Delete project?", isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ), presenting: pendingDelete) { project in
                Button("Delete", role: .destructive) { delete(project) }
                Button("Cancel", role: .cancel) {}
            } message: { project in
                Text("“\(project.name)” will be removed. Its photos and videos stay in your library.")
            }
            .alert("Projects", isPresented: Binding(
                get: { errorText != nil },
                set: { if !$0 { errorText = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText ?? "")
            }
        }
    }

    private func reload() {
        do {
            projects = try ProjectStore.loadAll()
        } catch {
            errorText = "Could not read your projects: \(error.localizedDescription)"
        }
    }

    private func delete(_ project: MovieProject) {
        do {
            try ProjectStore.delete(id: project.id)
            reload()
        } catch {
            errorText = "Could not delete the project: \(error.localizedDescription)"
        }
    }
}

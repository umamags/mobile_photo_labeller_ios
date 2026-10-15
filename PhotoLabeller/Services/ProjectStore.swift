import Foundation

/// Saves projects to one JSON file in Application Support.
enum ProjectStore {
    private static var fileURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appendingPathComponent("projects.json")
    }

    /// All saved projects, most recently updated first.
    static func loadAll() throws -> [MovieProject] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([MovieProject].self, from: data).sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Adds the project, or replaces the saved one with the same id.
    static func save(_ project: MovieProject) throws {
        var projects = try loadAll()
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
        try write(projects)
    }

    static func delete(id: UUID) throws {
        var projects = try loadAll()
        projects.removeAll { $0.id == id }
        try write(projects)
    }

    private static func write(_ projects: [MovieProject]) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(projects)
        try data.write(to: fileURL, options: .atomic)
    }
}

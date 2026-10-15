import SwiftUI

/// Screens that can be pushed from the home page.
enum Utility: Hashable {
    case photoLabeller
    case createMovie
}

/// Owns the navigation so any screen can return to the home page.
struct RootView: View {
    @State private var path: [Utility] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                onOpenPhotoLabeller: { path.append(.photoLabeller) },
                onCreateMovie: { path.append(.createMovie) }
            )
            .navigationDestination(for: Utility.self) { utility in
                switch utility {
                case .photoLabeller:
                    EditorView {
                        path.removeAll()
                    }
                case .createMovie:
                    MovieMakerView {
                        path.removeAll()
                    }
                }
            }
        }
    }
}

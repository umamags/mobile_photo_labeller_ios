import SwiftUI

/// Screens that can be pushed from the home page.
enum Utility: Hashable {
    case photoLabeller
}

/// Owns the navigation so any screen can return to the home page.
struct RootView: View {
    @State private var path: [Utility] = []

    var body: some View {
        NavigationStack(path: $path) {
            HomeView {
                path.append(.photoLabeller)
            }
            .navigationDestination(for: Utility.self) { utility in
                switch utility {
                case .photoLabeller:
                    EditorView {
                        path.removeAll()
                    }
                }
            }
        }
    }
}

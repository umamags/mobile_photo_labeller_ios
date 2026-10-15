import SwiftUI

struct HomeView: View {
    let onOpenPhotoLabeller: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Text("Welcome to my utils")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Button(action: onOpenPhotoLabeller) {
                Label("Photo Labeller", systemImage: "text.below.photo")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .frame(maxWidth: 420)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}

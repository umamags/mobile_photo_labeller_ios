import SwiftUI

/// Edits the label for one photo or video. The label is drawn over that item in the movie.
struct LabelEditorView: View {
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String

    init(initialText: String, onSave: @escaping (String) -> Void) {
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Label (optional)", text: $text, axis: .vertical)
                        .lineLimit(1...3)
                } footer: {
                    Text("Shown over this photo or video in the movie. Leave empty for no label.")
                }
            }
            .navigationTitle("Label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

import SwiftUI

/// Text, font, colour and size controls for the label.
struct LabelControls: View {
    @Binding var label: TextLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Text")
                TextField("Type your label", text: $label.text)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Font")
                Picker("Font", selection: $label.font) {
                    ForEach(LabelFont.allCases) { font in
                        Text(font.name).tag(font)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Text colour")
                HStack(spacing: 10) {
                    ForEach(LabelColor.allCases) { option in
                        Swatch(
                            color: option.color,
                            isSelected: label.textColor == option
                        ) {
                            label.textColor = option
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Background colour")
                HStack(spacing: 10) {
                    ForEach(LabelBackground.allCases) { option in
                        Swatch(
                            color: option.color,
                            isSelected: label.background == option
                        ) {
                            label.background = option
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                sectionTitle("Size")
                Slider(value: $label.sizeRatio, in: TextLabel.sizeRange)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// A round colour button. A `nil` colour shows a "no background" symbol.
private struct Swatch: View {
    let color: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color ?? Color(.secondarySystemBackground))
                .frame(width: 34, height: 34)
                .overlay {
                    if color == nil {
                        Image(systemName: "nosign")
                            .foregroundStyle(.secondary)
                    }
                }
                .overlay {
                    Circle()
                        .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.4),
                                lineWidth: isSelected ? 3 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(color == nil ? "No background" : "Colour")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

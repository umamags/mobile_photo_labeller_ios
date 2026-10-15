import SwiftUI

enum LabelFont: String, CaseIterable, Identifiable {
    case standard, bold, rounded, serif, monospaced

    var id: Self { self }

    var name: String {
        switch self {
        case .standard: return "Standard"
        case .bold: return "Bold"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Mono"
        }
    }

    func font(size: CGFloat) -> Font {
        switch self {
        case .standard: return .system(size: size)
        case .bold: return .system(size: size, weight: .bold)
        case .rounded: return .system(size: size, weight: .semibold, design: .rounded)
        case .serif: return .system(size: size, design: .serif)
        case .monospaced: return .system(size: size, design: .monospaced)
        }
    }
}

enum LabelColor: String, CaseIterable, Identifiable {
    case white, black, red, yellow, green, blue, purple

    var id: Self { self }

    var color: Color {
        switch self {
        case .white: return .white
        case .black: return .black
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        }
    }
}

enum LabelBackground: String, CaseIterable, Identifiable {
    case none, translucentBlack, black, white, yellow, red, blue

    var id: Self { self }

    /// `nil` means no background at all.
    var color: Color? {
        switch self {
        case .none: return nil
        case .translucentBlack: return .black.opacity(0.5)
        case .black: return .black
        case .white: return .white
        case .yellow: return .yellow
        case .red: return .red
        case .blue: return .blue
        }
    }
}

/// The text label placed on a photo.
///
/// Sizes and positions are fractions of the photo's width/height, so the
/// on-screen preview and the exported full-resolution image always match.
struct TextLabel: Equatable {
    var text = "Your label"
    var font: LabelFont = .bold
    var textColor: LabelColor = .white
    var background: LabelBackground = .translucentBlack
    /// Font size as a fraction of the photo width.
    var sizeRatio: CGFloat = 0.06
    /// Top-left corner of the label, each value 0...1.
    var position = CGPoint(x: 0.1, y: 0.1)

    static let sizeRange: ClosedRange<CGFloat> = 0.02...0.2
}

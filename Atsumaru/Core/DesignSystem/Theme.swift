import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case slate, midnight, dusk, graphite, plum, ash, jade
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .slate: "Slate"
        case .midnight: "Midnight"
        case .dusk: "Dusk"
        case .graphite: "Graphite"
        case .plum: "Plum"
        case .ash: "Ash"
        case .jade: "Jade"
        }
    }
    var accent: Color {
        switch self {
        case .slate: .indigo
        case .midnight: .blue
        case .dusk: .purple
        case .graphite: .gray
        case .plum: .pink
        case .ash: .orange
        case .jade: .green
        }
    }
}
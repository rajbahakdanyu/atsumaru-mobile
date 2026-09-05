import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case slate, midnight, dusk, graphite, plum, ash, jade
    var id: String { rawValue }
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
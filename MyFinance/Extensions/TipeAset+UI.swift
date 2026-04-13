import SwiftUI

extension TipeAset {
    var color: Color {
        switch self {
        case .saham:     return Color(hex: "#22C55E")   // green
        case .kripto:    return Color(hex: "#F97316")   // orange
        case .reksadana: return Color(hex: "#3B82F6")   // blue
        case .emas:      return Color(hex: "#EAB308")   // yellow
        }
    }

    var iconName: String {
        switch self {
        case .saham:     return "chart.xyaxis.line"
        case .kripto:    return "bitcoinsign.circle.fill"
        case .reksadana: return "building.columns.fill"
        case .emas:      return "dollarsign.circle.fill"
        }
    }
}

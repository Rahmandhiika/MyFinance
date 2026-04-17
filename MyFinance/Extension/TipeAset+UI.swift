import SwiftUI

extension TipeAset {
    var color: Color {
        switch self {
        case .saham:     return Color(hex: "#22C55E")   // green
        case .sahamAS:   return Color(hex: "#F97316")   // orange
        case .reksadana: return Color(hex: "#3B82F6")   // blue
        case .valas:     return Color(hex: "#06B6D4")   // cyan
        case .emas:      return Color(hex: "#EAB308")   // yellow
        case .deposito:  return Color(hex: "#A78BFA")   // purple
        }
    }

    var iconName: String {
        switch self {
        case .saham:     return "chart.xyaxis.line"
        case .sahamAS:   return "chart.line.uptrend.xyaxis"
        case .reksadana: return "building.columns.fill"
        case .valas:     return "dollarsign.arrow.circlepath"
        case .emas:      return "circle.fill"
        case .deposito:  return "building.2.fill"
        }
    }
}

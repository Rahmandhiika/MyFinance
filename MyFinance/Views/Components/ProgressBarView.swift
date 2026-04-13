import SwiftUI

struct ProgressBarView: View {
    let progress: Double  // 0.0 to 1.0+
    let color: Color
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progress > 1.0 ? Color.red : color)
                    .frame(width: min(geo.size.width * progress, geo.size.width), height: height)
            }
        }
        .frame(height: height)
    }
}

import SwiftUI
import Charts

struct MarketOverviewCard: View {
    @Environment(\.appTheme) private var theme
    @State private var service = MarketIndexService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(theme.accent)
                    Text("MARKET")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)
                        .tracking(0.5)
                }
                Spacer()
                if let updated = service.lastUpdated {
                    Text(updated.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary.opacity(0.5))
                }
                Button {
                    Task { await service.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(service.isLoading ? theme.textSecondary.opacity(0.4) : theme.textSecondary)
                        .rotationEffect(.degrees(service.isLoading ? 360 : 0))
                        .animation(
                            service.isLoading
                                ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                                : .default,
                            value: service.isLoading
                        )
                }
                .disabled(service.isLoading)
            }

            // Index cards side by side
            HStack(spacing: 10) {
                indexCard(data: service.ihsg, placeholder: "IHSG", flag: "🇮🇩")
                indexCard(data: service.sp500, placeholder: "S&P 500", flag: "🇺🇸")
            }
        }
        .padding(16)
        .background(theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(theme.cardBorder, lineWidth: 1))
        .task { await service.refresh() }
    }

    // MARK: - Single Index Card

    @ViewBuilder
    private func indexCard(data: MarketIndexData?, placeholder: String, flag: String) -> some View {
        let positiveColor = Color(hex: "#22C55E")
        let negativeColor = Color(hex: "#FF6B6B")
        let changeColor   = data.map { $0.isPositive ? positiveColor : negativeColor } ?? theme.textSecondary

        VStack(alignment: .leading, spacing: 6) {
            // Name row
            HStack(spacing: 5) {
                Text(flag).font(.caption)
                Text(data?.name ?? placeholder)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
                Spacer()
            }

            if let data {
                // Price
                Text(data.priceFormatted)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // Change badge
                HStack(spacing: 3) {
                    Image(systemName: data.isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 9, weight: .bold))
                    Text(data.changePctFormatted)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(changeColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(changeColor.opacity(0.12))
                .clipShape(Capsule())

                // Mini chart
                if data.chartPoints.count >= 2 {
                    miniChart(points: data.chartPoints, color: changeColor)
                }
            } else {
                // Skeleton / loading state
                skeletonView
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.bgApp)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator, lineWidth: 1))
    }

    // MARK: - Mini Chart

    private func miniChart(points: [Double], color: Color) -> some View {
        let minVal = points.min() ?? 0
        let maxVal = points.max() ?? 1
        let padding = (maxVal - minVal) * 0.1

        return Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { idx, val in
                AreaMark(
                    x: .value("i", idx),
                    y: .value("v", val)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [color.opacity(0.25), color.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("i", idx),
                    y: .value("v", val)
                )
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 1.5))
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (minVal - padding)...(maxVal + padding))
        .frame(height: 44)
    }

    // MARK: - Skeleton

    private var skeletonView: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.separator)
                .frame(width: 80, height: 18)
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.separator)
                .frame(width: 50, height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.separator)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .opacity(service.isLoading ? 0.6 : 0.3)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: service.isLoading)
    }
}

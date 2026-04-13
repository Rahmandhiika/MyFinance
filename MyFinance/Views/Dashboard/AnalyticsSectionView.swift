import SwiftUI

struct AnalyticsSectionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analitik")
                .font(.headline)
                .padding(.horizontal)

            Text("Coming soon")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
        }
    }
}

import SwiftUI

struct IkonColorPicker: View {
    @Binding var selectedIkon: String
    @Binding var selectedWarna: String
    @Binding var ikonCustom: String

    let presetIkons = [
        "fork.knife", "car.fill", "house.fill", "cross.case.fill",
        "tshirt.fill", "bag.fill", "airplane.departure", "gamecontroller.fill",
        "lightbulb.fill", "cup.and.saucer.fill", "music.note",
        "heart.fill", "phone.fill", "briefcase.fill", "film.fill",
        "storefront.fill", "gift.fill", "leaf.fill", "building.2.fill",
        "dollarsign.circle.fill", "wallet.bifold.fill", "oval.fill",
        "arrow.left.arrow.right.circle.fill", "percent", "chart.xyaxis.line",
        "dollarsign.arrow.circlepath"
    ]

    let presetWarnas = [
        "#22C55E", "#F87171", "#93C5FD", "#FBBF24", "#C4B5FD",
        "#86EFAC", "#F9A8D4", "#FB923C", "#A78BFA",
        "#67E8F9", "#4ADE80", "#EF4444"
    ]

    let columns = [GridItem(.adaptive(minimum: 44))]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Emoji custom
            VStack(alignment: .leading, spacing: 6) {
                Text("IKON CUSTOM")
                    .font(.caption)
                    .foregroundStyle(.gray)
                TextField("Ketik emoji di sini...", text: $ikonCustom)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }

            // Icon grid
            VStack(alignment: .leading, spacing: 6) {
                Text("IKON")
                    .font(.caption)
                    .foregroundStyle(.gray)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(presetIkons, id: \.self) { ikon in
                        ZStack {
                            Circle()
                                .fill(selectedIkon == ikon ? Color(hex: selectedWarna) : Color.white.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: ikon)
                                .foregroundStyle(selectedIkon == ikon ? .white : .gray)
                                .font(.system(size: 16))
                            if selectedIkon == ikon {
                                Circle()
                                    .stroke(Color(hex: selectedWarna), lineWidth: 2)
                                    .frame(width: 44, height: 44)
                            }
                        }
                        .onTapGesture { selectedIkon = ikon }
                    }
                }
            }

            // Color palette
            VStack(alignment: .leading, spacing: 6) {
                Text("WARNA")
                    .font(.caption)
                    .foregroundStyle(.gray)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 8) {
                    ForEach(presetWarnas, id: \.self) { warna in
                        ZStack {
                            Circle()
                                .fill(Color(hex: warna))
                                .frame(width: 40, height: 40)
                            if selectedWarna == warna {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .onTapGesture { selectedWarna = warna }
                    }
                }
            }
        }
    }
}

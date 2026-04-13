import SwiftUI

struct PocketChipPicker: View {
    let pockets: [Pocket]
    @Binding var selected: Pocket?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(pockets) { pocket in
                    PocketChip(pocket: pocket, isSelected: selected?.id == pocket.id)
                        .onTapGesture { selected = selected?.id == pocket.id ? nil : pocket }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

struct PocketChip: View {
    let pocket: Pocket
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let logo = pocket.logo, let uiImage = UIImage(data: logo) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(hex: "#22C55E").opacity(0.3))
                    .frame(width: 18, height: 18)
                    .overlay(
                        Text(String(pocket.nama.prefix(1)))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(hex: "#22C55E"))
                    )
            }
            Text(pocket.nama)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .black : .white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color(hex: "#22C55E") : Color.white.opacity(0.1))
        .clipShape(Capsule())
    }
}

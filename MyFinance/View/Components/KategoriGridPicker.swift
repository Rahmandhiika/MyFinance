import SwiftUI
import SwiftData

struct KategoriGridPicker: View {
    let kategoris: [Kategori]
    @Binding var selected: Kategori?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(kategoris) { kategori in
                KategoriCell(kategori: kategori, isSelected: selected?.id == kategori.id)
                    .onTapGesture { selected = selected?.id == kategori.id ? nil : kategori }
            }
        }
    }
}

struct KategoriCell: View {
    let kategori: Kategori
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color(hex: kategori.warna) : Color(hex: kategori.warna).opacity(0.2))
                    .frame(width: 52, height: 52)

                if let emoji = kategori.ikonCustom, !emoji.isEmpty {
                    Text(emoji).font(.title3)
                } else {
                    Image(systemName: kategori.ikon)
                        .foregroundStyle(isSelected ? .white : Color(hex: kategori.warna))
                        .font(.body)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: kategori.warna) : .clear, lineWidth: 2)
            )

            Text(kategori.nama)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

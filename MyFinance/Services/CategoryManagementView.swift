import SwiftUI
import SwiftData

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]
    
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var newCategoryType: CategoryTransactionType = .expense
    @State private var newCategoryIcon = "tag.fill"
    @State private var categoryToDelete: Category?
    
    private let availableIcons = [
        "tag.fill", "cart.fill", "fork.knife", "car.fill", "house.fill",
        "heart.fill", "gift.fill", "gamecontroller.fill", "book.fill",
        "flag.fill", "star.fill", "sparkles", "crown.fill"
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(categories.filter { $0.isDefault }) { category in
                        CategoryRow(category: category, isDefault: true)
                    }
                } header: {
                    Text("Kategori Default")
                }
                
                Section {
                    if categories.filter({ !$0.isDefault }).isEmpty {
                        Text("Belum ada kategori custom")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(categories.filter { !$0.isDefault }) { category in
                            CategoryRow(category: category, isDefault: false)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        categoryToDelete = category
                                    } label: {
                                        Label("Hapus", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    Text("Kategori Custom")
                }
            }
            .navigationTitle("Kelola Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                addCategorySheet
            }
            .alert("Hapus Kategori?", isPresented: .constant(categoryToDelete != nil)) {
                Button("Hapus", role: .destructive) {
                    if let cat = categoryToDelete {
                        context.delete(cat)
                        try? context.save()
                        categoryToDelete = nil
                    }
                }
                Button("Batal", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                if let cat = categoryToDelete {
                    Text("Kategori '\(cat.name)' akan dihapus permanen.")
                }
            }
        }
    }
    
    private var addCategorySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nama Kategori", text: $newCategoryName)
                    
                    Picker("Tipe", selection: $newCategoryType) {
                        Text("Pemasukan").tag(CategoryTransactionType.income)
                        Text("Pengeluaran").tag(CategoryTransactionType.expense)
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("Icon", selection: $newCategoryIcon) {
                        ForEach(availableIcons, id: \.self) { icon in
                            HStack {
                                Image(systemName: icon)
                                Text(icon.replacingOccurrences(of: ".fill", with: ""))
                            }
                            .tag(icon)
                        }
                    }
                    
                    HStack {
                        Spacer()
                        Image(systemName: newCategoryIcon)
                            .font(.system(size: 48))
                            .foregroundStyle(.blue)
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Tambah Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") {
                        showAddCategory = false
                        resetForm()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan") {
                        saveCategory()
                    }
                    .disabled(newCategoryName.isEmpty)
                }
            }
        }
    }
    
    private func saveCategory() {
        let category = Category(
            name: newCategoryName,
            transactionType: newCategoryType,
            icon: newCategoryIcon,
            colorHex: newCategoryType == .income ? "#34C759" : "#FF3B30",
            isDefault: false
        )
        context.insert(category)
        try? context.save()
        
        showAddCategory = false
        resetForm()
    }
    
    private func resetForm() {
        newCategoryName = ""
        newCategoryType = .expense
        newCategoryIcon = "tag.fill"
    }
}

struct CategoryRow: View {
    let category: Category
    let isDefault: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.title3)
                .foregroundStyle(category.transactionType == .income ? .green : .red)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.subheadline)
                Text(category.transactionType == .income ? "Pemasukan" : "Pengeluaran")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if isDefault {
                Text("Default")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

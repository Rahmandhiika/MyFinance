import SwiftData
import Foundation

// MARK: - Seeding (user profile + kategori pocket defaults)

extension ModelContainerService {

    /// Dipanggil saat app pertama buka — hanya seed jika belum ada data.
    /// `executeAutoTransaksi` di-defer ke background Task agar tidak memblokir
    /// synchronous launch path dan HomeView bisa muncul secepat mungkin.
    func ensureUserProfile() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if count == 0 {
            context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
            save(context)
        }
        ensureKategoriPocket()
        Task { self.executeAutoTransaksi() }
    }

    /// Dipanggil setelah reset — selalu seed ulang dari nol
    func seedAll() {
        let context = container.mainContext
        context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
        let defaults = [
            "Rekening Bank",
            "Bank Digital",
            "E-Wallet",
            "Dompet",
            "Kartu Kredit/PayLater",
            "Lainnya"
        ]
        for (index, nama) in defaults.enumerated() {
            context.insert(KategoriPocket(nama: nama, urutan: index))
        }
        save(context)
    }

    func ensureKategoriPocket() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<KategoriPocket>())) ?? 0
        guard count == 0 else { return }
        let defaults = [
            "Rekening Bank", "Bank Digital", "E-Wallet",
            "Dompet", "Kartu Kredit/PayLater", "Lainnya"
        ]
        for (index, nama) in defaults.enumerated() {
            context.insert(KategoriPocket(nama: nama, urutan: index))
        }
        save(context)
    }
}

import SwiftData
import Foundation

@MainActor
class ModelContainerService {
    static let shared = ModelContainerService()
    let container: ModelContainer

    private init() {
        let schema = Schema([
            Pocket.self,
            KategoriPocket.self,
            Transaksi.self,
            TransferInternal.self,
            Kategori.self,
            Target.self,
            SimpanKeTarget.self,
            Aset.self,
            Anggaran.self,
            Langganan.self,
            PembayaranLangganan.self,
            UserProfile.self
        ])

        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("myfinance.store")

        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Dipanggil saat app pertama buka — hanya seed jika belum ada data
    func ensureUserProfile() {
        let context = container.mainContext
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if count == 0 {
            context.insert(UserProfile(nama: "Dika", greetingText: "Halo"))
            try? context.save()
        }
        ensureKategoriPocket()
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
        try? context.save()
    }

    private func ensureKategoriPocket() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<KategoriPocket>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
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
            try? context.save()
        }
    }
}

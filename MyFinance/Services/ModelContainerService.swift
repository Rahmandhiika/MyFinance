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
            TransaksiOtomatis.self,
            UserProfile.self
        ])

        let storeURL = URL.applicationSupportDirectory
            .appendingPathComponent("myfinance-v6.store")

        let config = ModelConfiguration(schema: schema, url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func ensureUserProfile() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<UserProfile>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let profile = UserProfile(nama: "Dika", greetingText: "Halo")
            context.insert(profile)
            try? context.save()
        }
        ensureKategoriPocket()
    }

    private func ensureKategoriPocket() {
        let context = container.mainContext
        let descriptor = FetchDescriptor<KategoriPocket>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        if count == 0 {
            let defaults = ["Rekening Bank", "E-Wallet", "E-Money", "Dompet", "Kartu Kredit/PayLater", "Akun Brand", "Lainnya"]
            for nama in defaults {
                context.insert(KategoriPocket(nama: nama))
            }
            try? context.save()
        }
    }
}

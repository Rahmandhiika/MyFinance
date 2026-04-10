import SwiftData
import Foundation

class ModelContainerService {
    static let shared = ModelContainerService()
    let container: ModelContainer

    private init() {
        let schema = Schema([
            Pocket.self,
            UpdateSaldo.self,
            Expense.self,
            Income.self,
            TransferInternal.self,
            KategoriExpense.self,
            KategoriIncome.self,
            ExpenseTerjadwal.self,
            IncomeTerjadwal.self,
            TransferInternalTerjadwal.self,
            Debitur.self,
            Kreditur.self,
            BudgetBulanan.self,
            RencanaAnggaranTahunan.self,
            Goal.self,
            RiwayatMencicilMenabung.self,
            InvestasiHolding.self,
            FGI.self,
            AsetNonFinansial.self,
            KategoriAset.self,
            UserProfile.self,
            DanaDaruratConfig.self,
        ])

        let config = ModelConfiguration(isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    @MainActor
    func ensureUserProfile() {
        let context = container.mainContext
        let desc = FetchDescriptor<UserProfile>()
        let count = (try? context.fetchCount(desc)) ?? 0
        if count == 0 {
            context.insert(UserProfile())
            try? context.save()
        }
    }
}

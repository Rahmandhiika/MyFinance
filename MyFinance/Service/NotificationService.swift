import UserNotifications
import Foundation

// MARK: - Notification Service

/// Mengelola semua local push notification — deposito jatuh tempo + budget alert.
@Observable @MainActor
final class NotificationService {
    static let shared = NotificationService()

    var isAuthorized = false

    private init() {}

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            isAuthorized = settings.authorizationStatus == .authorized
            return
        }
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            print("⚠️ NotificationService: gagal request permission — \(error)")
        }
    }

    // MARK: - Deposito Maturity

    /// Schedule 2 notifikasi: 7 hari sebelum dan 1 hari sebelum jatuh tempo.
    func scheduleDepositoReminder(aset: Aset) {
        guard aset.tipe == .deposito,
              let jatuhTempo = aset.jatuhTempoDeposito else { return }

        let center = UNUserNotificationCenter.current()
        let nama   = aset.nama
        let nominal = aset.nominalDeposito?.idrFormatted ?? ""

        // Hapus notifikasi lama untuk aset ini dulu
        cancelDepositoReminder(asetID: aset.id)

        let reminders: [(days: Int, identifier: String)] = [
            (7, "deposito-7d-\(aset.id)"),
            (1, "deposito-1d-\(aset.id)")
        ]

        for reminder in reminders {
            guard let triggerDate = Calendar.current.date(
                byAdding: .day, value: -reminder.days, to: jatuhTempo),
                  triggerDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Deposito Jatuh Tempo"
            content.body = "\(nama) (\(nominal)) jatuh tempo \(reminder.days == 1 ? "besok" : "dalam \(reminder.days) hari"). Pertimbangkan perpanjangan atau pencairan."
            content.sound = .default

            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: reminder.identifier,
                content: content,
                trigger: trigger
            )
            center.add(request) { error in
                if let error { print("⚠️ NotificationService: deposito schedule gagal — \(error)") }
            }
        }
    }

    func cancelDepositoReminder(asetID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "deposito-7d-\(asetID)",
                "deposito-1d-\(asetID)"
            ]
        )
    }

    // MARK: - Budget Alert

    /// Cek semua anggaran vs pengeluaran bulan ini.
    /// Kirim notifikasi jika ada yang ≥ 80% tapi belum pernah notif bulan ini.
    func checkBudgetAlerts(anggaran: [Anggaran], transaksiBuilanIni: [Transaksi]) {
        guard isAuthorized else { return }
        let center = UNUserNotificationCenter.current()
        let cal    = Calendar.current
        let now    = Date()
        let monthKey = "\(cal.component(.year, from: now))-\(cal.component(.month, from: now))"

        for a in anggaran {
            guard a.nominal > 0 else { continue }
            let used = transaksiBuilanIni.filter { t in
                t.tipe == .pengeluaran &&
                (a.kategori == nil || t.kategori?.id == a.kategori?.id)
            }.reduce(Decimal(0)) { $0 + $1.nominal }

            let prog = (used / a.nominal as NSDecimalNumber).doubleValue
            guard prog >= 0.8 else { continue }

            let alertKey = "budget-alerted-\(a.id)-\(monthKey)"
            guard UserDefaults.standard.string(forKey: alertKey) == nil else { continue }

            let katNama  = a.kategori?.nama ?? "Semua Kategori"
            let pctStr   = String(format: "%.0f%%", prog * 100)
            let content  = UNMutableNotificationContent()
            content.title = prog >= 1.0 ? "Budget \(katNama) Melebihi Batas! 🚨" : "Budget \(katNama) \(pctStr) Terpakai ⚠️"
            content.body  = prog >= 1.0
                ? "Pengeluaran \(katNama) sudah melewati budget \(a.nominal.idrFormatted) bulan ini."
                : "Kamu sudah menggunakan \(pctStr) dari budget \(a.nominal.idrFormatted) untuk \(katNama)."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: alertKey,
                content: content,
                trigger: nil   // segera
            )
            center.add(request) { error in
                if error == nil {
                    UserDefaults.standard.set("sent", forKey: alertKey)
                }
            }
        }
    }
}

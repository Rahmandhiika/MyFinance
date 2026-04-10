import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleTerjadwalReminder(id: UUID, nama: String, setiapTanggal: Int, nominal: Double?) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Pengingat: \(nama)"
        if let nominal {
            content.body = "Jatuh tempo hari ini. Nominal: Rp \(Int(nominal))"
        } else {
            content.body = "Jatuh tempo hari ini"
        }
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.day = setiapTanggal
        dateComponents.hour = 9
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
        center.add(request)
    }

    func cancelReminder(id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }
}

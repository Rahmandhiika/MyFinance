import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()
    private init() {}

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleDueDateReminders(for account: Account) {
        guard account.type == .credit, account.dueDate > 0 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            "due_\(account.id)_3", "due_\(account.id)_1"
        ])

        for daysBefore in [3, 1] {
            let content = UNMutableNotificationContent()
            content.title  = "Tagihan Jatuh Tempo"
            content.body   = "Tagihan \(account.name) jatuh tempo dalam \(daysBefore) hari. Sisa tagihan: \(account.usedLimit.idrFormatted)"
            content.sound  = .default

            var components        = DateComponents()
            let targetDay         = account.dueDate - daysBefore
            components.day        = targetDay > 0 ? targetDay : targetDay + 30
            components.hour       = 9
            components.minute     = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "due_\(account.id)_\(daysBefore)",
                content: content, trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelReminders(for accountID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            "due_\(accountID)_3", "due_\(accountID)_1"
        ])
    }
}

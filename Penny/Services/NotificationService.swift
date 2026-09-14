import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        do {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .denied:
                return false
            case .notDetermined:
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func refreshBillReminders(bills: [RecurringBill], enabled: Bool) async {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        for bill in bills where bill.isActive && bill.reminderEnabled {
            scheduleReminder(for: bill)
        }
    }

    private func scheduleReminder(for bill: RecurringBill) {
        let content = UNMutableNotificationContent()
        content.title = "Upcoming bill"
        content.body = "\(bill.name) is due soon."
        content.sound = .default

        var triggerDate = Calendar.current.date(
            byAdding: .day,
            value: -bill.reminderDaysBefore,
            to: bill.nextDueDate
        ) ?? bill.nextDueDate

        if triggerDate < Date.now {
            triggerDate = bill.nextDueDate
        }

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        var triggerComps = comps
        triggerComps.hour = 9

        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bill-\(bill.id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

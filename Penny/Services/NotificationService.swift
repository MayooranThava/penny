import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    /// Day the reminder should fire: `daysBefore` days before due, or the due
    /// date itself when that day is already in the past.
    /// Pure calendar math — safe off the main actor (and from sync tests).
    nonisolated static func reminderTriggerDate(
        dueDate: Date,
        daysBefore: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let candidate = calendar.date(
            byAdding: .day,
            value: -daysBefore,
            to: dueDate
        ) ?? dueDate
        return candidate < now ? dueDate : candidate
    }

    /// Calendar components for the local 9:00 notification on the trigger day.
    nonisolated static func reminderTriggerComponents(
        dueDate: Date,
        daysBefore: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateComponents {
        let triggerDate = reminderTriggerDate(
            dueDate: dueDate,
            daysBefore: daysBefore,
            now: now,
            calendar: calendar
        )
        var comps = calendar.dateComponents([.year, .month, .day, .hour], from: triggerDate)
        comps.hour = 9
        return comps
    }

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

    func refreshBillReminders(bills: [RecurringBill], enabled: Bool, currencyCode: String) async {
        center.removeAllPendingNotificationRequests()
        guard enabled else { return }
        let authorized = await requestAuthorizationIfNeeded()
        guard authorized else { return }

        for bill in bills where bill.isActive && bill.reminderEnabled {
            scheduleReminder(for: bill, currencyCode: currencyCode)
        }
    }

    private func scheduleReminder(for bill: RecurringBill, currencyCode: String) {
        let copy = PennyNotificationContent.billReminder(
            name: bill.name,
            individualAmount: nil,
            billsTotal: nil,
            currencyCode: currencyCode,
            isPrivate: PrivateModeStore.isEnabled,
            locale: .current
        )
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        let triggerComps = Self.reminderTriggerComponents(
            dueDate: bill.nextDueDate,
            daysBefore: bill.reminderDaysBefore
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "bill-\(bill.id.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

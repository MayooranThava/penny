import Foundation
import UserNotifications

/// Declares notification usage. Actual permission is requested in-app when reminders are enabled.
enum PennyAppInfo {
    static let displayName = "Penny"
    static let marketingVersion = "1.0.0"
    static let buildNumber = "1"
    static let privacySummary = "Penny stores financial data on-device only. No bank connections, analytics, or tracking in this prototype."
}

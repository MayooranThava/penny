import WidgetKit
import SwiftUI

@main
struct PennyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        SafeToSpendWidget()
        UpcomingReminderWidget()
        UpcomingBillsWidget()
        MonthlyBudgetWidget()
        SavingsGoalWidget()
    }
}

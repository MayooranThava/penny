import SwiftUI
import SwiftData

@main
struct PennyApp: App {
    @State private var session = AppSession()
    private let launch: LaunchState

    init() {
        do {
            let container = try PennyPersistence.makeContainer()
            launch = .ready(container)
        } catch {
            launch = .failed(error.localizedDescription)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch launch {
            case .ready(let container):
                RootView()
                    .environment(session)
                    .modelContainer(container)
            case .failed(let message):
                StorageErrorView(message: message)
            }
        }
    }

    private enum LaunchState {
        case ready(ModelContainer)
        case failed(String)
    }
}

struct StorageErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: PennySpacing.md) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(PennyColors.warning)
            Text("Penny can’t open local data")
                .font(PennyTypography.title)
            Text(message)
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PennyColors.background.ignoresSafeArea())
    }
}

struct RootView: View {
    @Query private var settingsList: [UserSettings]

    private var settings: UserSettings? { settingsList.first }
    private var hasOnboarded: Bool { settings?.hasCompletedOnboarding == true }

    var body: some View {
        Group {
            if hasOnboarded {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(settings?.appearance.colorScheme)
        .tint(PennyColors.brand)
    }
}

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @Query(filter: #Predicate<RecurringBill> { $0.isActive }) private var bills: [RecurringBill]
    @Query private var settingsList: [UserSettings]

    var body: some View {
        @Bindable var session = session
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ActivityView()
                .tabItem { Label("Activity", systemImage: "arrow.left.arrow.right") }

            BudgetView()
                .tabItem { Label("Budget", systemImage: "chart.pie.fill") }

            PlanView()
                .tabItem { Label("Plan", systemImage: "target") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $session.showAddTransaction) {
            AddTransactionView()
        }
        .task {
            let enabled = settingsList.first?.billRemindersEnabled ?? false
            await NotificationService.shared.refreshBillReminders(bills: Array(bills), enabled: enabled)
        }
    }
}

#Preview("Root Demo") {
    RootView()
        .environment(AppSession())
        .modelContainer(PennyPersistence.previewContainer())
}

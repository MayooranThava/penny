import SwiftUI
import SwiftData

@main
struct PennyApp: App {
    @State private var session = AppSession()
<<<<<<< HEAD
    @State private var container: ModelContainer?
    @State private var launchError: String?
    @State private var didStartLaunch = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Never leave a pure black window while storage boots.
                Color(red: 0.97, green: 0.96, blue: 0.94)
                    .ignoresSafeArea()

                content
            }
            .tint(PennyColors.brand)
            .task {
                await startIfNeeded()
=======
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
>>>>>>> origin/main
            }
        }
    }

<<<<<<< HEAD
    @ViewBuilder
    private var content: some View {
        if let launchError {
            StorageErrorView(message: launchError)
        } else if let container {
            RootView()
                .environment(session)
                .modelContainer(container)
        } else {
            LaunchSplashView()
        }
    }

    @MainActor
    private func startIfNeeded() async {
        guard !didStartLaunch else { return }
        didStartLaunch = true

        // Yield one frame so the splash paints before SwiftData opens.
        await Task.yield()

        do {
            container = try PennyPersistence.makeContainer()
        } catch {
            launchError = error.localizedDescription
        }
    }
}

struct LaunchSplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(Color(red: 0.12, green: 0.62, blue: 0.48))
                .symbolRenderingMode(.hierarchical)

            Text("Penny")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.12, green: 0.14, blue: 0.16))

            ProgressView()
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("Loading Penny")
=======
    private enum LaunchState {
        case ready(ModelContainer)
        case failed(String)
>>>>>>> origin/main
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
<<<<<<< HEAD

#Preview("Splash") {
    LaunchSplashView()
}
=======
>>>>>>> origin/main

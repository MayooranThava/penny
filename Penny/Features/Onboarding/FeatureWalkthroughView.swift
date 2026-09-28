import SwiftUI

/// Short, skippable spotlight tour shown after first setup.
struct FeatureWalkthroughView: View {
    @Binding var isPresented: Bool
    var onSelectTab: (AppSession.MainTab) -> Void
    var onFinished: () -> Void

    @State private var stepIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var steps: [Step] {
        [
            .init(
                tab: .home,
                title: "Safe to Spend",
                detail: "Your calm number for what’s left this month — based on income, bills, spending, and savings you enter."
            ),
            .init(
                tab: .activity,
                title: "Activity",
                detail: "Log income and expenses. Filter by month or category anytime."
            ),
            .init(
                tab: .budget,
                title: "Budget",
                detail: "Set category budgets and see healthy / near-limit / over at a glance."
            ),
            .init(
                tab: .plan,
                title: "Plan",
                detail: "Track bills (tap the checkmark when paid), goals, debt estimates, and forecasts."
            ),
            .init(
                tab: .settings,
                title: "Settings",
                detail: "Currency, reminders, accent themes, and exports live here. You’re always in control of your data."
            )
        ]
    }

    private var step: Step { steps[stepIndex] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture { /* absorb taps */ }

            VStack {
                Spacer()
                card
                    .padding(.horizontal, PennySpacing.screenPadding)
                    .padding(.bottom, 96)
            }
        }
        .transition(.opacity)
        .onAppear { onSelectTab(step.tab) }
        .onChange(of: stepIndex) { _, _ in
            onSelectTab(step.tab)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: PennySpacing.md) {
            HStack {
                Text("Quick tour")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
                Spacer()
                Text("\(stepIndex + 1) of \(steps.count)")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textTertiary)
            }

            Text(step.title)
                .font(PennyTypography.title)
                .foregroundStyle(PennyColors.textPrimary)

            Text(step.detail)
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: PennySpacing.sm) {
                Button("Skip") { finish() }
                    .buttonStyle(.pennySecondary)

                Button(isLast ? "Done" : "Next") {
                    if isLast {
                        finish()
                    } else {
                        withAnimation(PennyAnimation.prefer(PennyAnimation.standard, reduceMotion: reduceMotion)) {
                            stepIndex += 1
                        }
                        Haptics.light()
                    }
                }
                .buttonStyle(.pennyPrimary)
            }
        }
        .padding(PennySpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusXl, style: .continuous)
                .fill(PennyColors.surface)
                .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        )
    }

    private func finish() {
        Haptics.success()
        onFinished()
        isPresented = false
    }

    private struct Step: Identifiable {
        var id: AppSession.MainTab { tab }
        var tab: AppSession.MainTab
        var title: String
        var detail: String
    }
}

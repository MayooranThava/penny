import SwiftUI

/// Skippable spotlight tour that keeps the real page visible and highlights a target region.
struct FeatureWalkthroughView: View {
    @Binding var isPresented: Bool
    var anchors: [WalkthroughAnchorID: Anchor<CGRect>]
    var proxy: GeometryProxy
    var onSelectTab: (AppSession.MainTab) -> Void
    var onSelectPlanSegment: (PlanSegment?) -> Void
    var onHighlight: (WalkthroughAnchorID?) -> Void
    var onFinished: () -> Void

    @State private var stepIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var steps: [Step] {
        [
            .init(
                tab: .home,
                planSegment: nil,
                anchor: .safeToSpend,
                title: "Safe to Spend",
                detail: "This card is your calm leftover for the month — income minus bills, spending, and goal targets you enter."
            ),
            .init(
                tab: .home,
                planSegment: nil,
                anchor: .upcomingBills,
                title: "Bills on Home",
                detail: "Upcoming lists what’s due soon. When a bill’s date passes — like Rent on the 1st — Penny adds a small checkmark automatically. No to-do list to tap."
            ),
            .init(
                tab: .plan,
                planSegment: .bills,
                anchor: .addBill,
                title: "Add a bill",
                detail: "Open Plan → Bills and tap Add bill to track something like Internet or Phone. One bill at a time keeps Safe to Spend honest."
            )
        ]
    }

    private var step: Step { steps[stepIndex] }
    private var isLast: Bool { stepIndex >= steps.count - 1 }

    private var highlightRect: CGRect? {
        guard let anchor = anchors[step.anchor] else { return nil }
        return proxy[anchor].insetBy(dx: -8, dy: -8)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            spotlightMask
                .allowsHitTesting(true)
                .onTapGesture { /* absorb background taps */ }

            card
                .padding(.horizontal, PennySpacing.screenPadding)
                .padding(.bottom, 96)
        }
        .transition(.opacity)
        .onAppear { applyStep() }
        .onChange(of: stepIndex) { _, _ in applyStep() }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder
    private var spotlightMask: some View {
        let hole = highlightRect
        Canvas { context, size in
            let full = Path(CGRect(origin: .zero, size: size))
            context.fill(full, with: .color(.black.opacity(0.45)))
            if let hole {
                let rounded = Path(
                    roundedRect: hole,
                    cornerRadius: PennySpacing.radiusLg,
                    style: .continuous
                )
                context.blendMode = .destinationOut
                context.fill(rounded, with: .color(.white))
            }
        }
        .compositingGroup()
        .ignoresSafeArea()
        .overlay {
            if let hole {
                RoundedRectangle(cornerRadius: PennySpacing.radiusLg, style: .continuous)
                    .strokeBorder(PennyColors.brand.opacity(0.95), lineWidth: 2.5)
                    .frame(width: hole.width, height: hole.height)
                    .position(x: hole.midX, y: hole.midY)
                    .allowsHitTesting(false)
                    .shadow(color: PennyColors.brand.opacity(0.35), radius: 10)
            }
        }
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

    private func applyStep() {
        onSelectTab(step.tab)
        onSelectPlanSegment(step.planSegment)
        onHighlight(step.anchor)
    }

    private func finish() {
        Haptics.success()
        onHighlight(nil)
        onSelectPlanSegment(nil)
        onFinished()
        isPresented = false
    }

    private struct Step: Identifiable {
        var id: WalkthroughAnchorID { anchor }
        var tab: AppSession.MainTab
        var planSegment: PlanSegment?
        var anchor: WalkthroughAnchorID
        var title: String
        var detail: String
    }
}

import Foundation
import SwiftUI
import SwiftData
import UIKit

/// Copyable Shortcuts setup content shared by the guided UI.
enum ApplePayShortcutsGuide {
    static let actionName = "Log Wallet Purchase"
    static let searchTerm = "Penny"

    struct FieldMap: Identifiable, Equatable {
        let id: String
        let pennyParameter: String
        let shortcutInput: String
        let hint: String
        let isOptional: Bool

        var copyLine: String {
            "\(pennyParameter) ← \(shortcutInput)"
        }
    }

    static let fieldMaps: [FieldMap] = [
        .init(
            id: "amount",
            pennyParameter: "Amount",
            shortcutInput: "Amount",
            hint: "The Amount field from the Wallet tap, or Currency Amount",
            isOptional: false
        ),
        .init(
            id: "merchant",
            pennyParameter: "Merchant",
            shortcutInput: "Merchant or Name",
            hint: "Use Merchant. If that is empty, use Name",
            isOptional: false
        ),
        .init(
            id: "currency",
            pennyParameter: "Currency Code",
            shortcutInput: "Your Penny currency",
            hint: "Type the currency code from Penny Settings. Do not leave this as Ask Each Time.",
            isOptional: true
        ),
        .init(
            id: "card",
            pennyParameter: "Card Name",
            shortcutInput: "Card or Pass",
            hint: "Optional — which Wallet card was used",
            isOptional: true
        )
    ]

    /// Apple does not let Penny install Wallet automations. The prompt is a guide the user can follow or paste elsewhere.
    static func aiSetupPrompt(currencyCode: String) -> String {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return """
        Create an iPhone Shortcuts automation that logs Wallet taps into Penny.

        iOS 27 (do this first):
        1. Open Shortcuts. Touch and hold a shortcut and tap Edit. If a screen asks you to describe a change, tap Edit again.
        2. Add a Transaction trigger: When I tap, and include the cards you pay with. Tap the arrow beside the trigger, leave Automation on, and turn Confirm Before Run off.
        3. Tap the info button, then Privacy, and turn on Allow Running When Locked.
        4. Add the action from the Penny app: “\(actionName)”
           (Add Action → Apps → Penny — open Penny once first if it is missing)
        5. Map the Amount field: Shortcut Input → Amount (or Currency Amount).
        6. Map Merchant → Shortcut Input → Merchant. If Merchant is empty, use Name.
        7. Currency Code → type \(code) (do not leave as Ask Each Time).
        8. Card Name → Shortcut Input → Card or Pass (optional).
        9. Save.

        iOS 26 (if you do not see Confirm Before Run):
        1. Shortcuts → Automation → New Automation.
        2. Trigger: Transaction / Wallet → When I tap → include your cards.
        3. Run Immediately, turn Ask Before Running off, and turn Show When Run off.
        4. Add the same Penny action. Map Amount, Merchant (or Name), Currency Code, and Card Name the same way.
        5. Save.

        You can paste this into an AI assistant of your choice and ask it to walk you through Shortcuts. Anything you paste into another app follows that app's terms.

        Goal: Wallet taps can log expenses in Penny without asking first.
        """
    }

    static func pennyCurrencyCode(stored: String?, locale: Locale = .current) -> String {
        let trimmed = (stored ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed.uppercased() }
        if let code = locale.currency?.identifier, !code.isEmpty {
            return code.uppercased()
        }
        return "CAD"
    }

    /// Plain text the user can paste into Notes or keep beside Shortcuts.
    static var cheatSheetText: String {
        var lines: [String] = [
            "Penny · optional Wallet capture",
            "",
            "Skip this entirely if you prefer logging expenses by hand.",
            "",
            "Easiest assist: copy the prompt from Penny Settings and paste it into an AI assistant of your choice. Anything you paste into another app follows that app's terms.",
            "",
            "Note: Apple does not allow apps (or shared links) to install Wallet tap automations for you — you still approve the automation once.",
            "",
            "Before Shortcuts: open Penny once (so iOS registers its actions).",
            "",
            "iOS 27 first:",
            "1. Shortcuts → touch and hold a shortcut → Edit",
            "2. Transaction trigger → When I tap → your cards",
            "3. Leave Automation on · turn Confirm Before Run off",
            "4. Info button → Privacy → turn on Allow Running When Locked",
            "5. Add Action → Apps → Penny → \(actionName)",
            "6. Map the Amount field, then Merchant (or Name):",
            "",
            "iOS 26 if you do not see Confirm Before Run:",
            "Shortcuts → Automation → New Automation → Transaction / Wallet → When I tap.",
            "Run Immediately · turn off Ask Before Running · Show When Run off.",
            "Map the same Amount and Merchant fields.",
            ""
        ]
        for map in fieldMaps {
            let optionalTag = map.isOptional ? " (optional)" : ""
            lines.append("   \(map.copyLine)\(optionalTag)")
        }
        lines.append("")
        lines.append("Then return to Penny Settings and tap “I’ve finished the Shortcuts steps” if you want.")
        return lines.joined(separator: "\n")
    }
}

/// Pleasant companion guide for building the Wallet → Penny automation.
struct ApplePayCaptureSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var settingsList: [UserSettings]

    @State private var didOpenShortcuts = false
    @State private var checkedSteps: Set<String> = []
    @State private var copiedToken: String?
    @State private var appearHero = false

    private var settings: UserSettings? { settingsList.first }
    private var alreadyConfigured: Bool { settings?.applePayCaptureConfigured == true }
    private var pennyCurrencyCode: String {
        ApplePayShortcutsGuide.pennyCurrencyCode(stored: settings?.currencyCode)
    }

    private let checklist: [(id: String, title: String, detail: String)] = [
        ("open", "Open Penny once first", "iOS only lists Penny in Shortcuts after the app has launched."),
        ("trigger", "Add a Transaction trigger", "iOS 27: When I tap, and include the cards you pay with."),
        ("run", "Run without asking", "Turn Confirm Before Run off, and turn on Allow Running When Locked (info button → Privacy). On iOS 26, choose Run Immediately and turn off Ask Before Running."),
        ("action", "Add Log Wallet Purchase", "Add Action → Apps → Penny (or search the action name)."),
        ("map", "Map the Amount field", "Amount ← Amount or Currency Amount. Merchant ← Merchant, or Name if Merchant is empty.")
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: PennySpacing.xl) {
                        hero
                        easyAIPromptCard
                        progressStrip
                        cheatSheetCard
                        actionNameCard
                        mappingSection
                        checklistSection
                        limits
                            .padding(.bottom, 120)
                    }
                    .padding(PennySpacing.screenPadding)
                }
                .background(PennyColors.softBackgroundGradient.ignoresSafeArea())

                bottomBar
            }
            .navigationTitle("Wallet capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if alreadyConfigured {
                        Label("On", systemImage: "checkmark.circle.fill")
                            .font(PennyTypography.caption)
                            .foregroundStyle(PennyColors.brand)
                            .labelStyle(.titleAndIcon)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let copiedToken {
                    copiedBanner(copiedToken)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, PennySpacing.sm)
                }
            }
            .animation(PennyAnimation.prefer(PennyAnimation.emphasis, reduceMotion: reduceMotion), value: copiedToken)
            .onAppear {
                withAnimation(PennyAnimation.prefer(PennyAnimation.emphasis, reduceMotion: reduceMotion)) {
                    appearHero = true
                }
            }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            ZStack {
                Circle()
                    .fill(PennyColors.brandMuted)
                    .frame(width: 72, height: 72)
                    .scaleEffect(appearHero ? 1 : 0.86)
                Image(systemName: "wallet.pass.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(PennyColors.brand)
                    .symbolRenderingMode(.hierarchical)
                    .opacity(appearHero ? 1 : 0)
                    .offset(y: appearHero ? 0 : 6)
            }

            Text("Optional Wallet capture")
                .font(PennyTypography.largeTitle)
                .foregroundStyle(PennyColors.textPrimary)

            Text("You don’t need this for Penny to work. Apple won’t let any app install a Wallet automation for you — copy the prompt below into an AI assistant of your choice, or follow the checklist. Anything you paste into another app follows that app's terms.")
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Progress

    private var progressStrip: some View {
        let done = checkedSteps.count
        let total = checklist.count
        return VStack(alignment: .leading, spacing: PennySpacing.xs) {
            HStack {
                Text("Your checklist")
                    .font(PennyTypography.overline)
                    .foregroundStyle(PennyColors.textTertiary)
                    .textCase(.uppercase)
                Spacer()
                Text("\(done) of \(total)")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.brand)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(PennyColors.secondarySurface)
                    Capsule()
                        .fill(PennyColors.brand)
                        .frame(width: total == 0 ? 0 : geo.size.width * CGFloat(done) / CGFloat(total))
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checklist progress, \(done) of \(total) complete")
    }

    // MARK: - Easiest path

    private var easyAIPromptCard: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            Text("Easiest for you & friends")
                .font(PennyTypography.overline)
                .foregroundStyle(PennyColors.textTertiary)
                .textCase(.uppercase)

            Text("Copy AI prompt")
                .font(PennyTypography.bodyEmphasized)
                .foregroundStyle(PennyColors.textPrimary)

            Text("Paste into an AI assistant of your choice and ask it to walk you through Shortcuts. Anything you paste into another app follows that app's terms. Shared shortcut links can’t install Wallet tap automations — Apple requires each person to approve that trigger once.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                copy(
                    ApplePayShortcutsGuide.aiSetupPrompt(currencyCode: pennyCurrencyCode),
                    token: "AI prompt copied"
                )
            } label: {
                Label("Copy AI prompt", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pennyPrimary)
        }
        .padding(PennySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    // MARK: - Cheat sheet

    private var cheatSheetCard: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Copy the whole guide")
                        .font(PennyTypography.bodyEmphasized)
                        .foregroundStyle(PennyColors.textPrimary)
                    Text("Paste into Notes if you want it beside Shortcuts.")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.textSecondary)
                }
                Spacer(minLength: PennySpacing.sm)
                Button {
                    copy(ApplePayShortcutsGuide.cheatSheetText, token: "Guide copied")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(PennyTypography.caption)
                }
                .buttonStyle(.borderedProminent)
                .tint(PennyColors.brand)
            }
        }
        .padding(PennySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelBackground)
    }

    // MARK: - Action name

    private var actionNameCard: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            Text("Action to add")
                .font(PennyTypography.overline)
                .foregroundStyle(PennyColors.textTertiary)
                .textCase(.uppercase)

            copyRow(
                title: ApplePayShortcutsGuide.actionName,
                subtitle: "In Shortcuts: Add Action → Apps → Penny → this action. Searching only “Penny” often fails — use Apps.",
                copyValue: ApplePayShortcutsGuide.actionName,
                token: "Action name copied"
            )

            copyRow(
                title: "Search: \(ApplePayShortcutsGuide.searchTerm)",
                subtitle: "Quick search term for the Actions list.",
                copyValue: ApplePayShortcutsGuide.searchTerm,
                token: "Search term copied"
            )
        }
    }

    // MARK: - Field mapping

    private var mappingSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            HStack {
                Text("Field mapping")
                    .font(PennyTypography.sectionHeading)
                    .foregroundStyle(PennyColors.textPrimary)
                Spacer()
                Button {
                    let all = ApplePayShortcutsGuide.fieldMaps.map(\.copyLine).joined(separator: "\n")
                    copy(all, token: "All mappings copied")
                } label: {
                    Label("Copy all", systemImage: "square.on.square")
                        .font(PennyTypography.caption)
                        .foregroundStyle(PennyColors.brand)
                }
            }

            Text("In each Penny parameter, tap the field → Shortcut Input → pick the matching value.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)

            ForEach(ApplePayShortcutsGuide.fieldMaps) { map in
                mappingRow(map)
            }
        }
    }

    private func mappingRow(_ map: ApplePayShortcutsGuide.FieldMap) -> some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            HStack(spacing: PennySpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(map.pennyParameter)
                        .font(PennyTypography.bodyEmphasized)
                        .foregroundStyle(PennyColors.textPrimary)
                    Text(map.hint)
                        .font(PennyTypography.footnote)
                        .foregroundStyle(PennyColors.textTertiary)
                }
                Spacer(minLength: 0)
                if map.isOptional {
                    Text("Optional")
                        .font(PennyTypography.footnote)
                        .foregroundStyle(PennyColors.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(PennyColors.secondarySurface))
                }
            }

            HStack(spacing: PennySpacing.xs) {
                mappingChip(label: "Penny", value: map.pennyParameter)
                Image(systemName: "arrow.left")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PennyColors.brand)
                    .accessibilityHidden(true)
                mappingChip(label: "Shortcuts", value: map.shortcutInput)
                Spacer(minLength: 0)
                Button {
                    copy(map.copyLine, token: "\(map.pennyParameter) mapping copied")
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.body.weight(.medium))
                        .foregroundStyle(PennyColors.brand)
                        .frame(width: PennySpacing.minTapTarget, height: PennySpacing.minTapTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Copy \(map.pennyParameter) mapping")
            }
        }
        .padding(PennySpacing.md)
        .background(panelBackground)
    }

    private func mappingChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(PennyColors.textTertiary)
            Text(value)
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusSm, style: .continuous)
                .fill(PennyColors.secondarySurface)
        )
    }

    // MARK: - Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            Text("Tap as you go")
                .font(PennyTypography.sectionHeading)
                .foregroundStyle(PennyColors.textPrimary)

            ForEach(checklist, id: \.id) { item in
                Button {
                    toggleStep(item.id)
                } label: {
                    HStack(alignment: .top, spacing: PennySpacing.sm) {
                        Image(systemName: checkedSteps.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(checkedSteps.contains(item.id) ? PennyColors.brand : PennyColors.textTertiary)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(PennyTypography.bodyEmphasized)
                                .foregroundStyle(PennyColors.textPrimary)
                                .multilineTextAlignment(.leading)
                            Text(item.detail)
                                .font(PennyTypography.caption)
                                .foregroundStyle(PennyColors.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(PennySpacing.md)
                    .background(panelBackground)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(checkedSteps.contains(item.id) ? [.isSelected] : [])
            }
        }
    }

    private var limits: some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            Text("What gets captured")
                .font(PennyTypography.bodyEmphasized)
                .foregroundStyle(PennyColors.textPrimary)
            Text("Apple Pay / Wallet taps on iPhone or Watch. Not full Apple Card online history, and not chip-only card taps that never hit Wallet. Everything stays on this device.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: PennySpacing.sm) {
            Button {
                dismiss()
            } label: {
                Text(alreadyConfigured ? "Done" : "Close — maybe later")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pennyPrimary)

            Button {
                openShortcutsAutomationBuilder()
                markStep("open")
            } label: {
                Label(
                    didOpenShortcuts ? "Reopen Shortcuts" : "Open Shortcuts (optional)",
                    systemImage: "arrow.up.forward.app.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pennySecondary)

            if !alreadyConfigured {
                Button {
                    markConfiguredAndClose()
                } label: {
                    Text("I’ve finished the Shortcuts steps")
                        .font(PennyTypography.callout)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(PennyColors.brand)
                .disabled(settings == nil)
            }
        }
        .padding(.horizontal, PennySpacing.screenPadding)
        .padding(.top, PennySpacing.sm)
        .padding(.bottom, PennySpacing.md)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: -4)
        )
    }

    // MARK: - Shared pieces

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: PennySpacing.radiusLg, style: .continuous)
            .fill(PennyColors.surface)
            .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
    }

    private func copyRow(title: String, subtitle: String, copyValue: String, token: String) -> some View {
        HStack(alignment: .center, spacing: PennySpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PennyTypography.bodyEmphasized)
                    .foregroundStyle(PennyColors.textPrimary)
                Text(subtitle)
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            }
            Spacer(minLength: 0)
            Button {
                copy(copyValue, token: token)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(PennyColors.brandMuted)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(PennySpacing.md)
        .background(panelBackground)
    }

    private func copiedBanner(_ text: String) -> some View {
        Text(text)
            .font(PennyTypography.caption)
            .foregroundStyle(PennyColors.textOnBrand)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(PennyColors.brand))
            .shadow(color: PennyColors.brand.opacity(0.25), radius: 8, y: 4)
            .accessibilityAddTraits(.updatesFrequently)
    }

    private func copy(_ value: String, token: String) {
        UIPasteboard.general.string = value
        Haptics.success()
        withAnimation(PennyAnimation.prefer(PennyAnimation.quick, reduceMotion: reduceMotion)) {
            copiedToken = token
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            withAnimation(PennyAnimation.prefer(PennyAnimation.quick, reduceMotion: reduceMotion)) {
                if copiedToken == token { copiedToken = nil }
            }
        }
    }

    private func toggleStep(_ id: String) {
        Haptics.light()
        withAnimation(PennyAnimation.prefer(PennyAnimation.quick, reduceMotion: reduceMotion)) {
            if checkedSteps.contains(id) {
                checkedSteps.remove(id)
            } else {
                checkedSteps.insert(id)
            }
        }
    }

    private func markStep(_ id: String) {
        withAnimation(PennyAnimation.prefer(PennyAnimation.quick, reduceMotion: reduceMotion)) {
            checkedSteps.insert(id)
        }
    }

    private func markConfiguredAndClose() {
        settings?.applePayCaptureConfigured = true
        modelContext.saveOrSurfaceError()
        Haptics.success()
        dismiss()
    }

    private func openShortcutsAutomationBuilder() {
        guard let url = URL(string: "shortcuts://") else { return }
        openURL(url)
        didOpenShortcuts = true
        Haptics.light()
    }
}

#Preview {
    ApplePayCaptureSetupView()
        .modelContainer(PennyPersistence.previewContainer())
}

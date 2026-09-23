import SwiftUI
import SwiftData

/// Guided Wallet automation setup.
///
/// Apple blocks third-party apps from creating Personal Automations. The closest
/// UX is: Penny opens Shortcuts at “create automation”, then the user finishes
/// a short checklist and taps Done.
struct ApplePayCaptureSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]

    @State private var didOpenShortcuts = false
    @State private var showOpenFailed = false

    private var settings: UserSettings? { settingsList.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PennySpacing.lg) {
                    header
                    honestyCallout
                    steps
                    openButton
                    markDoneButton
                    limits
                }
                .padding(PennySpacing.screenPadding)
            }
            .background(PennyColors.background.ignoresSafeArea())
            .navigationTitle("Apple Pay capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn’t open Shortcuts", isPresented: $showOpenFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Open the Shortcuts app manually, tap Automation, then New Automation.")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(PennyColors.brand)
                .symbolRenderingMode(.hierarchical)
            Text("Log Apple Pay taps in Penny")
                .font(PennyTypography.title)
                .foregroundStyle(PennyColors.textPrimary)
            Text("When you tap to pay, Shortcuts can send the amount and merchant into Penny automatically.")
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
        }
    }

    private var honestyCallout: some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            Text("One approval in Shortcuts")
                .font(PennyTypography.bodyEmphasized)
                .foregroundStyle(PennyColors.textPrimary)
            Text("Apple doesn’t let apps create Wallet automations for you. Penny opens the builder — you choose Wallet / Transaction, set Run Immediately, add “Log Apple Pay Purchase”, map the fields, and tap Done.")
                .font(PennyTypography.callout)
                .foregroundStyle(PennyColors.textSecondary)
        }
        .padding(PennySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: PennySpacing.radiusLg, style: .continuous)
                .fill(PennyColors.surface)
        )
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: PennySpacing.sm) {
            stepRow(number: 1, title: "Open the automation builder", detail: "Use the button below. It jumps to Shortcuts → New Automation.")
            stepRow(number: 2, title: "Choose Wallet / Transaction", detail: "On iOS 17–18 look for Transaction. On newer iOS it may say Wallet. Pick When I tap, then select your cards.")
            stepRow(number: 3, title: "Run Immediately", detail: "Turn on Run Immediately and turn off Ask Before Running / Notify When Run so taps stay quiet.")
            stepRow(number: 4, title: "Add Penny’s action", detail: "Create New Shortcut → search “Penny” → Log Apple Pay Purchase.")
            stepRow(number: 5, title: "Map Shortcut Input", detail: "Amount ← Currency Amount · Merchant ← Name · Currency Code ← Currency Code · Card Name ← Card or Pass (optional).")
        }
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: PennySpacing.sm) {
            Text("\(number)")
                .font(PennyTypography.bodyEmphasized)
                .foregroundStyle(PennyColors.brand)
                .frame(width: 28, height: 28)
                .background(Circle().fill(PennyColors.brand.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(PennyTypography.bodyEmphasized)
                    .foregroundStyle(PennyColors.textPrimary)
                Text(detail)
                    .font(PennyTypography.caption)
                    .foregroundStyle(PennyColors.textSecondary)
            }
        }
    }

    private var openButton: some View {
        Button {
            openShortcutsAutomationBuilder()
        } label: {
            Label(
                didOpenShortcuts ? "Open Shortcuts again" : "Create automation in Shortcuts",
                systemImage: "arrow.up.forward.app"
            )
        }
        .buttonStyle(.pennyPrimary)
    }

    private var markDoneButton: some View {
        Button {
            settings?.applePayCaptureConfigured = true
            try? modelContext.save()
            Haptics.success()
            dismiss()
        } label: {
            Text(settings?.applePayCaptureConfigured == true ? "Setup already marked complete" : "I’ve finished setup")
        }
        .buttonStyle(.pennySecondary)
        .disabled(settings == nil)
    }

    private var limits: some View {
        VStack(alignment: .leading, spacing: PennySpacing.xs) {
            Text("What this captures")
                .font(PennyTypography.bodyEmphasized)
            Text("Works for Apple Pay / Wallet taps (phone or watch). It does not pull full Apple Card online history, and physical chip-only taps that never hit Wallet won’t appear. Everything stays on this device.")
                .font(PennyTypography.caption)
                .foregroundStyle(PennyColors.textSecondary)
        }
        .padding(.top, PennySpacing.sm)
    }

    private func openShortcutsAutomationBuilder() {
        let candidates = [
            URL(string: "shortcuts://create-automation"),
            URL(string: "shortcuts://automations"),
            URL(string: "shortcuts://")
        ].compactMap { $0 }

        guard let first = candidates.first else {
            showOpenFailed = true
            return
        }

        openURL(first)
        didOpenShortcuts = true
        Haptics.light()
    }
}

#Preview {
    ApplePayCaptureSetupView()
        .modelContainer(PennyPersistence.previewContainer())
}

import Foundation
import Observation
import WidgetKit

enum PrivateModeStore {
    static var record: PrivateModeRecord {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite) else {
            return .fresh
        }
        return PrivateModeStorage.load(from: defaults)
    }

    static var isEnabled: Bool {
        record.isEnabled
    }
}

protocol PrivateWidgetReloading: Sendable {
    func reload(kinds: [String])
}

struct WidgetKitPrivateReloader: PrivateWidgetReloading {
    func reload(kinds: [String]) {
        for kind in kinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}

/// In-memory mirror of the App Group flag. Toggling writes UserDefaults and
/// reloads total widgets. It does not save SwiftData or rebuild the snapshot.
@MainActor
@Observable
final class PrivateModeController {
    private(set) var isEnabled: Bool
    private(set) var settings: PrivateModeRecord
    private(set) var animationsSuppressed: Bool
    private let reloader: any PrivateWidgetReloading
    /// When set, this controller reads and writes only this store. The shared
    /// app controller leaves it nil and follows the active suite on each call.
    private let pinnedDefaults: UserDefaults?
    var reloadCoalescer = PrivateWidgetReloadCoalescer()
    private var reloadTask: Task<Void, Never>?

    init(
        defaults: UserDefaults? = nil,
        reloader: any PrivateWidgetReloading = WidgetKitPrivateReloader()
    ) {
        self.reloader = reloader
        self.pinnedDefaults = defaults
        let loaded = (defaults ?? Self.currentDefaults()).map { PrivateModeStorage.load(from: $0) } ?? .fresh
        settings = loaded
        isEnabled = loaded.isEnabled
        animationsSuppressed = false
    }

    static let shared = PrivateModeController()

    static func currentDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite)
    }

    /// Widgets read this. Missing flag means totals stay visible.
    nonisolated static var isEnabledInDefaults: Bool {
        PrivateModeStore.isEnabled
    }

    func toggle() {
        let enabled = resolvedDefaults().map { PrivateModeStorage.load(from: $0).isEnabled } ?? false
        setEnabled(!enabled)
    }

    private func resolvedDefaults() -> UserDefaults? {
        pinnedDefaults ?? Self.currentDefaults()
    }

    func setEnabled(_ newValue: Bool) {
        var record = settings
        let changed = record.isEnabled != newValue
        record.isEnabled = newValue
        commit(record, reload: PrivateWidgetKinds.totalAndUpcomingBills, changed: changed)
    }

    func setHidden(_ kind: PrivateAmountKind, _ hidden: Bool) {
        var record = settings
        guard record.visibility.hides(kind) != hidden else { return }
        switch kind {
        case .totals: record.visibility.hideTotals = hidden
        case .transactions: record.visibility.hideTransactions = hidden
        case .bills: record.visibility.hideBills = hidden
        case .widgets: record.visibility.hideWidgets = hidden
        }
        commit(record, reload: PrivateWidgetReloadCoalescer.widgetKinds(affectedBy: kind), changed: true)
    }

    func acknowledgeUpgradeNote() {
        guard let defaults = resolvedDefaults() else {
            settings.upgradeNotePending = false
            return
        }
        settings = PrivateModeStorage.acknowledgeUpgradeNote(in: defaults)
        isEnabled = settings.isEnabled
    }

    func masks(_ site: PrivateTotalSite) -> Bool {
        if site.rawValue.hasPrefix("widget") {
            return settings.masksWidgetTotals()
        }
        return settings.masks(.totals)
    }

    func masks(_ kind: PrivateAmountKind) -> Bool {
        settings.masks(kind)
    }

    private func commit(_ record: PrivateModeRecord, reload kinds: [String], changed: Bool) {
        settings = record
        isEnabled = record.isEnabled
        if let defaults = resolvedDefaults() {
            PrivateModeStorage.save(record, to: defaults)
        }
        guard changed else { return }
        reloadCoalescer.noteChange(kinds: kinds, at: Date())
        let delay = reloadCoalescer.debounce
        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, !Task.isCancelled else { return }
            let due = self.reloadCoalescer.takeDueReload(at: Date().addingTimeInterval(0.05))
            if let due {
                self.reloader.reload(kinds: due)
            }
        }
    }

    func refreshFromDefaults() {
        if let defaults = resolvedDefaults() {
            settings = PrivateModeStorage.load(from: defaults)
        }
        isEnabled = settings.isEnabled
    }

    func noteScenePhase(_ phase: PrivateScenePhase) {
        if AppSwitcherPrivacy.suppressAnimation(phase: phase) {
            animationsSuppressed = true
        } else if phase == .active {
            animationsSuppressed = false
        }
        refreshFromDefaults()
    }
}

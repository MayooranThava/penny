import Foundation
import Observation
import WidgetKit

enum PrivateModeStore {
    static var isEnabled: Bool {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshotStore.activeDefaultsSuite) else {
            return false
        }
        return PrivateModeDefaults.isEnabled(in: defaults)
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
    private(set) var animationsSuppressed: Bool
    private let reloader: any PrivateWidgetReloading
    var reloadCoalescer = PrivateWidgetReloadCoalescer()
    private var reloadTask: Task<Void, Never>?

    init(reloader: any PrivateWidgetReloading = WidgetKitPrivateReloader()) {
        self.reloader = reloader
        let defaults = Self.currentDefaults()
        isEnabled = defaults.map { PrivateModeDefaults.isEnabled(in: $0) } ?? false
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
        setEnabled(!Self.isEnabledInDefaults)
    }

    func setEnabled(_ newValue: Bool) {
        let changed = newValue != Self.isEnabledInDefaults
        if let defaults = Self.currentDefaults() {
            PrivateModeDefaults.setEnabled(newValue, in: defaults)
        }
        isEnabled = newValue
        guard changed else { return }
        // The flag is already stored, so a widget that renders now masks totals.
        // Timeline reloads wait until taps stop, and the last flag wins.
        reloadCoalescer.noteChange(at: Date())
        let delay = reloadCoalescer.debounce
        reloadTask?.cancel()
        reloadTask = Task { @MainActor [weak self] in
            let nanoseconds = UInt64(max(delay, 0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, !Task.isCancelled else { return }
            // A slightly early wake still counts as the end of the quiet period.
            let kinds = self.reloadCoalescer.takeDueReload(at: Date().addingTimeInterval(0.05))
            if let kinds {
                self.reloader.reload(kinds: kinds)
            }
        }
    }

    func refreshFromDefaults() {
        isEnabled = Self.isEnabledInDefaults
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

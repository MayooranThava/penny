import Foundation
import os
import SwiftData

/// Thrown only from tests. SwiftData updates a row when a second insert reuses its
/// unique id, so a duplicate insert does not fail `save()`.
struct PennyForcedSaveFailure: Error, Sendable, LocalizedError {
    var errorDescription: String? { "The save could not be written." }
}

enum PennySaveTesting {
    /// When set, `saveOrSurfaceError()` throws this and does not call `save()`.
    @TaskLocal static var forcedError: PennyForcedSaveFailure?
}

/// One app-wide message when a SwiftData save fails. Views show it as a banner.
@MainActor
@Observable
final class PennySaveReporter {
    static let shared = PennySaveReporter()

    private(set) var message: String?

    func report(_ error: Error) {
        let detail = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if detail.isEmpty {
            message = "Couldn’t save your changes."
        } else {
            message = "Couldn’t save your changes. \(detail)"
        }
        PennyLog.persistence.error("Save failed: \(error.localizedDescription, privacy: .public)")
    }

    func dismiss() {
        message = nil
    }
}

extension ModelContext {
    /// Saves, and on failure shows the shared banner instead of dropping the error.
    @discardableResult
    @MainActor
    func saveOrSurfaceError() -> Bool {
        do {
            if let forced = PennySaveTesting.forcedError {
                throw forced
            }
            try save()
            return true
        } catch {
            PennySaveReporter.shared.report(error)
            return false
        }
    }
}

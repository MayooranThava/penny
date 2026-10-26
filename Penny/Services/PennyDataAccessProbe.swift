import Foundation

/// Counts SwiftData saves and snapshot rebuilds while a test toggles private mode.
final class PennyDataAccessCounter: @unchecked Sendable {
    var saves = 0
    var fetches = 0
}

enum PennyDataAccessProbe {
    @TaskLocal static var counter: PennyDataAccessCounter?
}

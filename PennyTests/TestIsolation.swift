import Foundation
import Testing
@testable import Penny

enum PennyTestIsolationError: Error, CustomStringConvertible {
    case defaultsSuiteUnavailable(String)

    var description: String {
        switch self {
        case .defaultsSuiteUnavailable(let name):
            return "Could not open UserDefaults suite \(name)"
        }
    }
}

/// Gives each test a unique SwiftData directory and UserDefaults suite.
///
/// Pure calculation suites still run in parallel. SwiftData suites are marked
/// `.serialized` because container setup is process-global. The macOS job also
/// passes `-parallel-testing-enabled YES` so separate suites can run together.
struct IsolatedTestResourcesTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func provideScope(
        for test: Test,
        testCase: Test.Case?,
        performing function: @Sendable () async throws -> Void
    ) async throws {
        let defaultsSuite = "PennyTests.\(UUID().uuidString)"
        let storeName = "PennyTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: defaultsSuite) else {
            throw PennyTestIsolationError.defaultsSuiteUnavailable(defaultsSuite)
        }
        defaults.removePersistentDomain(forName: defaultsSuite)
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent(storeName, isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
            try? FileManager.default.removeItem(at: directory)
        }
        try await WidgetSnapshotStore.$defaultsSuiteOverride.withValue(defaultsSuite) {
            try await PennyPersistence.$isolatedStoreName.withValue(storeName) {
                try await function()
            }
        }
    }
}

extension Trait where Self == IsolatedTestResourcesTrait {
    static var isolatedTestResources: Self { Self() }
}

/// A throwaway UserDefaults suite. Tests that touch Private mode or the widget
/// snapshot must use this instead of the shared App Group.
struct PennyTestDefaults {
    let name: String
    let defaults: UserDefaults

    init() throws {
        let name = "penny.test.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            throw PennyTestIsolationError.defaultsSuiteUnavailable(name)
        }
        defaults.removePersistentDomain(forName: name)
        self.name = name
        self.defaults = defaults
    }

    func remove() {
        defaults.removePersistentDomain(forName: name)
    }
}

func withPennyTestDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let box = try PennyTestDefaults()
    defer { box.remove() }
    try WidgetSnapshotStore.$defaultsSuiteOverride.withValue(box.name) {
        try body(box.defaults)
    }
}

@MainActor
func withPennyTestDefaults(_ body: (UserDefaults) async throws -> Void) async throws {
    let box = try PennyTestDefaults()
    defer { box.remove() }
    try await WidgetSnapshotStore.$defaultsSuiteOverride.withValue(box.name) {
        try await body(box.defaults)
    }
}

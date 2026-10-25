import Foundation
import Testing

/// Anchor so tests can find the PennyTests bundle (the host app bundle is not the test bundle).
final class MigrationFixtureAnchor {}

/// Reserved upgrade gate. PR 2 replaces the body with a v1.0.4 store open,
/// a no-data-lost assertion, and a timing check on about 5,000 transactions.
/// CI runs this suite because it runs the whole PennyTests target with no filter.
@Suite("Migration", .serialized, .isolatedTestResources)
struct MigrationTests {
    @Test("reservedUpgradeCheckRunsInCI")
    func reservedUpgradeCheckRunsInCI() throws {
        let bundle = Bundle(for: MigrationFixtureAnchor.self)
        let candidates = [
            bundle.url(forResource: "Fixtures", withExtension: nil),
            bundle.resourceURL?.appendingPathComponent("Fixtures"),
            bundle.bundleURL.appendingPathComponent("Fixtures"),
        ].compactMap { $0 }
        let fixtures = candidates.first { FileManager.default.fileExists(atPath: $0.path) }
        let folder = try #require(fixtures, "PennyTests must bundle Migration/Fixtures. See PennyTests/Migration/README.md.")
        let readme = folder.appendingPathComponent("README.txt")
        #expect(FileManager.default.fileExists(atPath: readme.path))
    }
}

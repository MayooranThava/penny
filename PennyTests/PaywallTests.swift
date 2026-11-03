import Foundation
import StoreKit
import Testing
@testable import Penny

/// Paywall copy and the product-load failure state.
@Suite("Paywall", .isolatedTestResources)
struct PaywallTests {
    private static let unavailable = "Purchases are unavailable right now. Please try again later."

    @Test("No paywall or product display string contains forever")
    func paywallAndProductStringsDoNotSayForever() throws {
        let built = [
            PaywallCopy.purchasesUnavailable,
            PaywallCopy.priceSubtitle(displayPrice: "$4.99"),
            PaywallCopy.priceSubtitle(displayPrice: "CA$12.00")
        ]
        #expect(PaywallCopy.priceSubtitle(displayPrice: "$4.99") == "$4.99 · one-time purchase")
        var literals: [String] = []
        for url in try appSwiftSources() {
            let source = try String(contentsOf: url, encoding: .utf8)
            literals.append(contentsOf: stringLiterals(in: source))
        }
        #expect(!literals.isEmpty)
        for text in literals + built {
            #expect(
                !text.localizedCaseInsensitiveContains("forever"),
                "Display string contains forever: \(text)"
            )
        }
    }

    @Test("A failed product load shows that purchases are unavailable")
    @MainActor
    func failedProductLoadShowsUnavailableMessage() async throws {
        let failed = StoreManager(
            loadProductsFromStore: { _ in throw FailedProductLoad() },
            observeTransactionUpdates: false
        )
        await failed.loadProducts()
        #expect(failed.isLoadingProducts == false)
        #expect(failed.products.isEmpty)
        #expect(failed.purchasesUnavailableMessage == Self.unavailable)

        let empty = StoreManager(
            loadProductsFromStore: { _ in [] },
            observeTransactionUpdates: false
        )
        await empty.loadProducts()
        #expect(empty.isLoadingProducts == false)
        #expect(empty.products.isEmpty)
        #expect(empty.purchasesUnavailableMessage == Self.unavailable)

        let paywall = try String(contentsOf: settingsViewURL(), encoding: .utf8)
        #expect(paywall.contains("if let message = store.purchasesUnavailableMessage"))
        #expect(paywall.contains("Text(message)"))
        #expect(!paywall.localizedCaseInsensitiveContains("forever"))
    }

    private func appSwiftSources() throws -> [URL] {
        let root = repoRoot()
        var files: [URL] = []
        for name in ["Penny", "PennyWidgets"] {
            let directory = root.appendingPathComponent(name, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey]
            ) else {
                throw PaywallTestError.missingDirectory(name)
            }
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                files.append(url)
            }
        }
        if files.isEmpty { throw PaywallTestError.missingDirectory("Penny") }
        return files
    }

    private func settingsViewURL() -> URL {
        repoRoot()
            .appendingPathComponent("Penny/Features/Settings/SettingsView.swift")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Double-quoted and triple-quoted literals, including interpolated ones.
    private func stringLiterals(in source: String) -> [String] {
        var values: [String] = []
        var index = source.startIndex
        while index < source.endIndex {
            if source[index] != "\"" {
                index = source.index(after: index)
                continue
            }
            let rest = source[index...]
            if rest.hasPrefix("\"\"\"") {
                let start = source.index(index, offsetBy: 3)
                guard let end = source[start...].range(of: "\"\"\"") else { break }
                values.append(String(source[start..<end.lowerBound]))
                index = end.upperBound
                continue
            }
            var cursor = source.index(after: index)
            var literal = ""
            var closed = false
            while cursor < source.endIndex {
                let character = source[cursor]
                if character == "\\" {
                    cursor = source.index(after: cursor)
                    if cursor < source.endIndex {
                        literal.append(source[cursor])
                        cursor = source.index(after: cursor)
                    }
                    continue
                }
                if character == "\"" {
                    closed = true
                    cursor = source.index(after: cursor)
                    break
                }
                if character == "\n" { break }
                literal.append(character)
                cursor = source.index(after: cursor)
            }
            if closed { values.append(literal) }
            index = cursor
        }
        return values
    }
}

private struct FailedProductLoad: Error {}

private enum PaywallTestError: Error {
    case missingDirectory(String)
}

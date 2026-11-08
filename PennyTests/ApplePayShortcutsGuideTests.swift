import Foundation
import Testing
@testable import Penny

@Suite("ApplePayShortcutsGuide", .isolatedTestResources)
struct ApplePayShortcutsGuideTests {

    @Test("Cheat sheet includes action name and every field map")
    func cheatSheetContent() {
        let text = ApplePayShortcutsGuide.cheatSheetText
        #expect(text.contains(ApplePayShortcutsGuide.actionName))
        #expect(text.contains("Transaction"))
        #expect(text.contains("Run Immediately"))
        for map in ApplePayShortcutsGuide.fieldMaps {
            #expect(text.contains(map.copyLine))
        }
    }

    @Test("Field maps stay in the expected Shortcuts order")
    func fieldMapOrder() {
        #expect(ApplePayShortcutsGuide.fieldMaps.map(\.id) == ["amount", "merchant", "currency", "card"])
        #expect(ApplePayShortcutsGuide.fieldMaps.last?.isOptional == true)
    }

    @Test("AI prompt mentions Penny action and Wallet trigger")
    func aiPromptContent() {
        let prompt = ApplePayShortcutsGuide.aiSetupPrompt(currencyCode: "USD")
        #expect(prompt.contains(ApplePayShortcutsGuide.actionName))
        #expect(prompt.contains("Wallet"))
        #expect(prompt.contains("type USD"))
        #expect(!prompt.contains("type CAD"))
        #expect(prompt.contains("Apps → Penny"))
        #expect(prompt.contains("Goal: Wallet taps can log expenses in Penny without asking first."))
        #expect(prompt.contains("iOS 27"))
        #expect(prompt.contains("Allow Running When Locked"))
        #expect(prompt.contains("Confirm Before Run"))
        #expect(prompt.contains("Amount"))
        #expect(prompt.contains("iOS 26"))
    }

    @Test("Setup prompt and HTML do not name an AI product")
    func promptDoesNotNameAnAIProduct() throws {
        let banned = [
            "ChatGPT", "Claude", "Apple Intelligence", "Gemini", "Copilot", "Grok", "Perplexity", "Bard"
        ]
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let prompt = ApplePayShortcutsGuide.aiSetupPrompt(currencyCode: "CAD")
        let sheet = ApplePayShortcutsGuide.cheatSheetText
        let html = try String(
            contentsOf: root.appendingPathComponent("docs/wallet-capture.html"),
            encoding: .utf8
        )
        let setup = try String(
            contentsOf: root.appendingPathComponent("Penny/Features/Settings/ApplePayCaptureSetupView.swift"),
            encoding: .utf8
        )
        #expect(html.contains("Goal: Wallet taps can log expenses in Penny without asking first."))
        #expect(prompt.contains("Goal: Wallet taps can log expenses in Penny without asking first."))
        #expect(html.contains("use the currency your Penny account uses (for example CAD or USD)"))
        #expect(!html.contains("type CAD"))
        #expect(prompt.contains("type CAD"))
        #expect(prompt.contains("an AI assistant of your choice"))
        #expect(prompt.contains("Anything you paste into another app follows that app's terms."))
        #expect(setup.contains("shortcuts://"))
        #expect(!setup.contains("shortcuts://create-automation"))
        #expect(setup.contains("reloadTimelines") == false)
        for name in banned {
            #expect(!prompt.localizedCaseInsensitiveContains(name), "Prompt names \(name)")
            #expect(!sheet.localizedCaseInsensitiveContains(name), "Cheat sheet names \(name)")
            #expect(!html.localizedCaseInsensitiveContains(name), "HTML names \(name)")
            #expect(!setup.localizedCaseInsensitiveContains(name), "Setup view names \(name)")
        }
        for bannedWord in ["secure", "encrypted"] {
            #expect(!prompt.localizedCaseInsensitiveContains(bannedWord))
            #expect(!sheet.localizedCaseInsensitiveContains(bannedWord))
            #expect(!html.localizedCaseInsensitiveContains(bannedWord))
            #expect(!setup.localizedCaseInsensitiveContains(bannedWord))
        }
    }
}

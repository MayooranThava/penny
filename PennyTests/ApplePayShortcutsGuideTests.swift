import Foundation
import Testing
@testable import Penny

@Suite("ApplePayShortcutsGuide")
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
        let prompt = ApplePayShortcutsGuide.aiSetupPrompt
        #expect(prompt.contains(ApplePayShortcutsGuide.actionName))
        #expect(prompt.contains("Wallet"))
        #expect(prompt.contains("CAD"))
        #expect(prompt.contains("Apps → Penny"))
    }
}

import Foundation
import Testing
@testable import PennyCoreLogic

@Suite("ApplePayCaptureLogic")
struct ApplePayCaptureLogicTests {

    @Test("Rounds Wallet doubles to exact cents")
    func roundsWalletDoublesToCents() {
        #expect(ApplePayCaptureLogic.money(fromApplePayAmount: 0.1 + 0.2) == Decimal(string: "0.30"))
        #expect(ApplePayCaptureLogic.money(fromApplePayAmount: 19.99) == Decimal(string: "19.99"))
        #expect(ApplePayCaptureLogic.money(fromApplePayAmount: 0.01) == Decimal(string: "0.01"))
        #expect(ApplePayCaptureLogic.money(fromApplePayAmount: 10.2) == Decimal(string: "10.20"))
        #expect(ApplePayCaptureLogic.money(fromApplePayAmount: .nan) == 0)
        let draft = ApplePayCaptureLogic.makeDraft(amount: 0.1 + 0.2, merchant: "Cafe", currencyCode: "CAD", cardName: nil)
        #expect(draft?.amount == Decimal(string: "0.30"))
    }

    @Test("Rejects non-positive amounts")
    func rejectsInvalidAmount() {
        #expect(ApplePayCaptureLogic.makeDraft(amount: 0, merchant: "Cafe", currencyCode: "CAD", cardName: nil) == nil)
        #expect(ApplePayCaptureLogic.makeDraft(amount: -4, merchant: "Cafe", currencyCode: "CAD", cardName: nil) == nil)
    }

    @Test("Builds draft with merchant title and Food category")
    func buildsFoodDraft() {
        let draft = ApplePayCaptureLogic.makeDraft(
            amount: 5.85,
            merchant: "  Tim Hortons ",
            currencyCode: "cad",
            cardName: "Apple Card"
        )
        #expect(draft != nil)
        #expect(draft?.title == "Tim Hortons")
        #expect(draft?.amount == Decimal(string: "5.85"))
        #expect(draft?.categoryName == "Food")
        #expect(draft?.currencyCode == "CAD")
        #expect(draft?.cardName == "Apple Card")
        #expect(draft?.note.contains("Apple Pay") == true)
        #expect(draft?.externalIdentifier.hasPrefix("applepay:") == true)
    }

    @Test("Falls back to Apple Pay title when merchant missing")
    func missingMerchant() {
        let draft = ApplePayCaptureLogic.makeDraft(
            amount: 12,
            merchant: "   ",
            currencyCode: nil,
            cardName: nil
        )
        #expect(draft?.title == "Apple Pay")
        #expect(draft?.categoryName == "Other")
    }

    @Test("Suggests transportation for rideshare merchants")
    func transportationCategory() {
        #expect(ApplePayCaptureLogic.suggestCategory(for: "Uber Trip") == "Transportation")
        #expect(ApplePayCaptureLogic.suggestCategory(for: "Shell Gas") == "Transportation")
    }

    @Test("External IDs match inside the duplicate window and differ after it")
    func externalIDUsesTimeWindow() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let soon = date.addingTimeInterval(30)
        let later = date.addingTimeInterval(ApplePayCaptureLogic.duplicateWindow + 1)

        let a = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "21.30")!,
            merchant: "Uber",
            cardName: "Visa",
            date: date
        )
        let b = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "21.30")!,
            merchant: "uber",
            cardName: "Visa",
            date: soon
        )
        let c = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "21.30")!,
            merchant: "Uber",
            cardName: "Visa",
            date: later
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Merchant falls back from Merchant to Name, then Apple Pay")
    func merchantFallsBackToNameThenApplePay() {
        #expect(ApplePayCaptureLogic.merchantTitle(merchant: " Cafe ", name: "Other") == "Cafe")
        #expect(ApplePayCaptureLogic.merchantTitle(merchant: "  ", name: " Name Cafe ") == "Name Cafe")
        #expect(ApplePayCaptureLogic.merchantTitle(merchant: nil, name: nil) == "Apple Pay")
        let draft = ApplePayCaptureLogic.makeDraft(
            amount: 4,
            merchant: "",
            name: "Name Cafe",
            currencyCode: "CAD",
            cardName: nil
        )
        #expect(draft?.title == "Name Cafe")
    }

    @Test("Parses currency text in the Amount field")
    func parsesCurrencyAmountText() {
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "$12.34") == Decimal(string: "12.34"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "CA$4.50") == Decimal(string: "4.50"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "1,234.56") == Decimal(string: "1234.56"))
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "0") == nil)
        #expect(ApplePayCaptureLogic.money(fromShortcutAmount: "not money") == nil)
    }

    @Test("Duplicate check uses amount, merchant, and a short time window")
    func duplicateCheckUsesTimeWindow() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let amount = Decimal(string: "8.25")!
        #expect(ApplePayCaptureLogic.isDuplicate(
            amount: amount,
            merchant: "Cafe",
            date: start,
            existingAmount: amount,
            existingMerchant: "cafe",
            existingDate: start.addingTimeInterval(45)
        ))
        #expect(!ApplePayCaptureLogic.isDuplicate(
            amount: amount,
            merchant: "Cafe",
            date: start,
            existingAmount: amount,
            existingMerchant: "Cafe",
            existingDate: start.addingTimeInterval(ApplePayCaptureLogic.duplicateWindow + 5)
        ))
        #expect(!ApplePayCaptureLogic.isDuplicate(
            amount: amount,
            merchant: "Cafe",
            date: start,
            existingAmount: Decimal(string: "9.00")!,
            existingMerchant: "Cafe",
            existingDate: start
        ))
    }
}

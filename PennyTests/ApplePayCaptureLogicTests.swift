import Foundation
import Testing
@testable import Penny

@Suite("ApplePayCaptureLogic")
struct ApplePayCaptureLogicTests {

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

    @Test("External IDs match for the same tap details on the same day")
    func externalIDStable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let a = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "21.30")!,
            merchant: "Uber",
            cardName: "Visa",
            date: date,
            calendar: calendar
        )
        let b = ApplePayCaptureLogic.externalIdentifier(
            amount: Decimal(string: "21.30")!,
            merchant: "uber",
            cardName: "Visa",
            date: date,
            calendar: calendar
        )
        #expect(a == b)
    }
}

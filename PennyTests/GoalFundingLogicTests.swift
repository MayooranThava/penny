import Foundation
import Testing
@testable import Penny

@Suite("Goal funding from accounts")
struct GoalFundingLogicTests {

    @Test("Unallocated balance and clamps never exceed account room")
    func allocationMath() {
        let balance: Decimal = 6_800
        #expect(FinanceCalculator.totalAllocated(amounts: [900, 3_400]) == 4_300)
        #expect(
            FinanceCalculator.unallocatedBalance(
                accountBalance: balance,
                allocatedAmounts: [900, 3_400]
            ) == 2_500
        )

        let clamped = FinanceCalculator.clampedAllocation(
            requested: 5_000,
            accountBalance: balance,
            otherAllocatedOnAccount: 4_300
        )
        #expect(clamped == 2_500)

        let zeroRoom = FinanceCalculator.clampedAllocation(
            requested: 100,
            accountBalance: 1_000,
            otherAllocatedOnAccount: 1_000
        )
        #expect(zeroRoom == 0)
    }

    @Test("Funded amount per goal and effective current prefer the larger source")
    func fundedAndEffectiveCurrent() {
        let accountA = UUID()
        let accountB = UUID()
        let condo = UUID()
        let vacation = UUID()

        let links: [FinanceCalculator.GoalFundingLink] = [
            .init(accountID: accountA, goalID: condo, amount: 8_000),
            .init(accountID: accountB, goalID: condo, amount: 2_000),
            .init(accountID: accountB, goalID: vacation, amount: 900)
        ]

        #expect(FinanceCalculator.fundedAmount(forGoal: condo, links: links) == 10_000)
        #expect(FinanceCalculator.fundedAmount(forGoal: vacation, links: links) == 900)

        #expect(
            FinanceCalculator.effectiveGoalCurrent(manualCurrent: 12_000, fundedFromAccounts: 10_000)
                == 12_000
        )
        #expect(
            FinanceCalculator.effectiveGoalCurrent(manualCurrent: 7_500, fundedFromAccounts: 10_000)
                == 10_000
        )
    }

    @Test("AllocationsFitBalances rejects over-earmarking an account")
    func fitBalances() {
        let tfsa = UUID()
        let fhsa = UUID()
        let condo = UUID()
        let vacation = UUID()

        let balances: [UUID: Decimal] = [tfsa: 6_800, fhsa: 8_000]
        let ok: [FinanceCalculator.GoalFundingLink] = [
            .init(accountID: fhsa, goalID: condo, amount: 8_000),
            .init(accountID: tfsa, goalID: vacation, amount: 900),
            .init(accountID: tfsa, goalID: condo, amount: 3_400)
        ]
        #expect(FinanceCalculator.allocationsFitBalances(accountBalances: balances, links: ok))

        let over: [FinanceCalculator.GoalFundingLink] = [
            .init(accountID: tfsa, goalID: vacation, amount: 4_000),
            .init(accountID: tfsa, goalID: condo, amount: 4_000)
        ]
        #expect(!FinanceCalculator.allocationsFitBalances(accountBalances: balances, links: over))
    }

    @Test("Account types cover Canadian wrappers and liquid forecast membership")
    func accountTypeCatalog() {
        #expect(AccountType.tfsa.displayName == "TFSA")
        #expect(AccountType.fhsa.displayName == "FHSA")
        #expect(AccountType.nonRegistered.displayName == "Non-registered")
        #expect(AccountType.tfsa.isGoalFundingEligible)
        #expect(AccountType.fhsa.isGoalFundingEligible)
        #expect(!AccountType.creditCard.isGoalFundingEligible)
        #expect(AccountType.tfsa.countsTowardLiquidForecast)
        #expect(AccountType.fhsa.countsTowardLiquidForecast)
        #expect(!AccountType.creditCard.countsTowardLiquidForecast)
        #expect(PennyProductCatalog.freeTierAccountLimit == 3)
    }
}

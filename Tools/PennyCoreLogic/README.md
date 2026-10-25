# PennyCoreLogic

Foundation-only extract of Penny's calculation layer for CI / Linux validation.

This package mirrors:

- `FinanceCalculator`
- `InsightEngine`
- `MoneyFormatters`
- `DateHelpers`
- `ApplePayCaptureLogic`
- `CSVExportLogic`
- `BillPaymentCycle`

It is **not** used by the iOS app target. Keep sources in sync with `Penny/Services` and `Penny/Utilities` when changing business logic.

```bash
# Full suite
swift test

# Pre-release smoke only
swift test --filter "Release Sanity"
```

From the repo root, preferred gate:

```bash
./scripts/pre-release-sanity.sh
./scripts/check-core-logic-drift.py
```

The drift script fails when these sources diverge from `Penny/Services` and `Penny/Utilities`. It ignores `public`, `Sendable`, and memberwise initializers required by the Linux package. Two pre-existing diffs (`Decimal.from` stripping and Apple Pay `%.2f` rounding) stay in the app only until the data-safety PR; the script fails if those diffs change. See `docs/ci.md`.

# PennyCoreLogic

Foundation-only extract of Penny's calculation layer for CI / Linux validation.

This package mirrors:

- `FinanceCalculator`
- `InsightEngine`
- `MoneyFormatters`
- `DateHelpers`
- `ApplePayCaptureLogic`

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
```

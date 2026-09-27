#!/usr/bin/env bash
# Verify PennyProductCatalog IDs match Penny.storekit (and each other).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT/Penny/Services/AppSession.swift"
STOREKIT="$ROOT/Penny.storekit"

[[ -f "$CATALOG" ]] || { echo "Missing $CATALOG" >&2; exit 1; }
[[ -f "$STOREKIT" ]] || { echo "Missing $STOREKIT" >&2; exit 1; }

monthly="$(grep -oE 'com\.penny\.app\.pro\.month' "$CATALOG" | head -1)"
lifetime="$(grep -oE 'com\.penny\.app\.pro\.lifetime' "$CATALOG" | head -1)"

[[ "$monthly" == "com.penny.app.pro.month" ]] || {
  echo "Catalog monthly product ID missing/unexpected in AppSession.swift" >&2
  exit 1
}
[[ "$lifetime" == "com.penny.app.pro.lifetime" ]] || {
  echo "Catalog lifetime product ID missing/unexpected in AppSession.swift" >&2
  exit 1
}

python3 - "$STOREKIT" "$monthly" "$lifetime" <<'PY'
import json, sys
path, monthly, lifetime = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    data = json.load(f)
ids = set()
for product in data.get("products", []):
    if pid := product.get("productID"):
        ids.add(pid)
for group in data.get("subscriptionGroups", []):
    for sub in group.get("subscriptions", []):
        if pid := sub.get("productID"):
            ids.add(pid)
expected = {monthly, lifetime}
if ids != expected:
    print(f"StoreKit IDs {sorted(ids)} != catalog {sorted(expected)}", file=sys.stderr)
    sys.exit(1)
print(f"OK: {', '.join(sorted(expected))}")
PY

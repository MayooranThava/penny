#!/usr/bin/env python3
"""Pick the next TestFlight build number for Penny.

Prefers App Store Connect latest build + 1. Falls back to --fallback
(or GITHUB_RUN_NUMBER / 1) when ASC credentials are missing or the API fails.
"""

from __future__ import annotations

import argparse
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

try:
    import jwt  # PyJWT
except ImportError:
    print("Install PyJWT: python3 -m pip install PyJWT cryptography", file=sys.stderr)
    raise SystemExit(1)

API = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.mayooran.penny"


def env_optional(name: str) -> str:
    return os.environ.get(name, "").strip()


def make_token() -> str:
    issuer = env_optional("ASC_ISSUER_ID")
    key_id = env_optional("ASC_KEY_ID")
    private_key = env_optional("ASC_PRIVATE_KEY").replace("\\n", "\n")
    if not issuer or not key_id or not private_key:
        raise RuntimeError("ASC credentials incomplete")
    now = int(time.time())
    return jwt.encode(
        {
            "iss": issuer,
            "iat": now,
            "exp": now + 15 * 60,
            "aud": "appstoreconnect-v1",
        },
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api_get(path: str) -> dict[str, Any]:
    req = urllib.request.Request(
        f"{API}/{path.lstrip('/')}",
        headers={
            "Authorization": f"Bearer {make_token()}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json_loads(resp.read())


def json_loads(raw: bytes) -> dict[str, Any]:
    import json

    if not raw:
        return {}
    return json.loads(raw)


def latest_build_number() -> int | None:
    q = urllib.parse.quote(BUNDLE_ID)
    apps = api_get(f"apps?filter[bundleId]={q}&limit=1").get("data") or []
    if not apps:
        return None
    app_id = apps[0]["id"]
    builds = (
        api_get(
            f"builds?filter[app]={app_id}&sort=-version&limit=1"
            f"&filter[processingState]=PROCESSING,VALID,INVALID,FAILED"
        ).get("data")
        or []
    )
    if not builds:
        # Pre-release filter can be empty; try without processingState.
        builds = api_get(f"builds?filter[app]={app_id}&sort=-version&limit=5").get("data") or []
    highest = 0
    for build in builds:
        version = str((build.get("attributes") or {}).get("version") or "").strip()
        if version.isdigit():
            highest = max(highest, int(version))
    return highest or None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--fallback",
        type=int,
        default=int(os.environ.get("GITHUB_RUN_NUMBER") or "1"),
        help="Used when ASC is unreachable (default: GITHUB_RUN_NUMBER or 1)",
    )
    args = parser.parse_args()
    fallback = max(1, args.fallback)

    try:
        latest = latest_build_number()
        if latest is None:
            chosen = fallback
            print(f"No prior ASC builds; using {chosen}", file=sys.stderr)
        else:
            chosen = max(latest + 1, fallback)
            print(f"Latest ASC build={latest}; using {chosen}", file=sys.stderr)
    except (RuntimeError, urllib.error.HTTPError, urllib.error.URLError, KeyError) as exc:
        chosen = fallback
        print(f"ASC lookup failed ({exc}); using fallback {chosen}", file=sys.stderr)

    print(chosen)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

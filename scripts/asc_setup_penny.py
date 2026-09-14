#!/usr/bin/env python3
"""App Store Connect helpers for Penny (same auth pattern as Void Runner).

Env (required):
  ASC_ISSUER_ID   UUID from Users and Access → Integrations → App Store Connect API
  ASC_KEY_ID      e.g. AJ6G86WBA2
  ASC_PRIVATE_KEY full .p8 PEM contents (including BEGIN/END lines)

Usage:
  python3 scripts/asc_setup_penny.py status
  python3 scripts/asc_setup_penny.py ensure-bundle-id
  python3 scripts/asc_setup_penny.py ensure-bundle-id --identifier com.mayooran.penny

Note: Apple's public API cannot CREATE the App Store Connect app record.
After the Bundle ID exists, create the app once in the ASC website
(My Apps → + → New App), then uploads via scripts/archive-for-testflight.sh
appear under TestFlight.
"""

from __future__ import annotations

import argparse
import json
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
DEFAULT_BUNDLE_ID = "com.mayooran.penny"
DEFAULT_BUNDLE_NAME = "Penny"
DEFAULT_APP_NAME = "Penny"
TEAM_HINT = "2YJ478267N"


class AscError(Exception):
    def __init__(self, status: int, body: str):
        self.status = status
        self.body = body
        super().__init__(f"ASC HTTP {status}: {body[:800]}")


def env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(
            f"Missing {name}. Export ASC_ISSUER_ID, ASC_KEY_ID, and ASC_PRIVATE_KEY "
            "(same as Void Runner)."
        )
    return value


def make_token() -> str:
    issuer = env("ASC_ISSUER_ID")
    key_id = env("ASC_KEY_ID")
    private_key = env("ASC_PRIVATE_KEY").replace("\\n", "\n")
    now = int(time.time())
    payload = {
        "iss": issuer,
        "iat": now,
        "exp": now + 15 * 60,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api_request(method: str, path: str, body: dict[str, Any] | None = None) -> dict[str, Any] | None:
    url = path if path.startswith("http") else f"{API}/{path.lstrip('/')}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {make_token()}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            if not raw:
                return None
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        raise AscError(exc.code, exc.read().decode("utf-8", errors="replace")) from exc


def list_apps() -> list[dict[str, Any]]:
    result = api_request("GET", "apps?limit=50") or {}
    return list(result.get("data") or [])


def find_app_by_bundle(bundle_id: str) -> dict[str, Any] | None:
    q = urllib.parse.quote(bundle_id)
    result = api_request("GET", f"apps?filter[bundleId]={q}&limit=5") or {}
    data = result.get("data") or []
    return data[0] if data else None


def list_bundle_ids() -> list[dict[str, Any]]:
    result = api_request("GET", "bundleIds?limit=100") or {}
    return list(result.get("data") or [])


def find_bundle_id(identifier: str) -> dict[str, Any] | None:
    q = urllib.parse.quote(identifier)
    result = api_request("GET", f"bundleIds?filter[identifier]={q}&limit=5") or {}
    data = result.get("data") or []
    return data[0] if data else None


def create_bundle_id(identifier: str, name: str) -> dict[str, Any]:
    payload = {
        "data": {
            "type": "bundleIds",
            "attributes": {
                "identifier": identifier,
                "name": name,
                "platform": "IOS",
            },
        }
    }
    result = api_request("POST", "bundleIds", payload)
    assert result and result.get("data")
    return result["data"]


def cmd_status(_: argparse.Namespace) -> int:
    print(f"Team (signing): {TEAM_HINT}")
    print(f"Default bundle: {DEFAULT_BUNDLE_ID}")
    print()
    print("Apps:")
    for app in list_apps():
        attrs = app.get("attributes") or {}
        print(f"  - {attrs.get('name')}  bundle={attrs.get('bundleId')}  id={app.get('id')}")
    print()
    print("Bundle IDs (first page):")
    for bid in list_bundle_ids()[:30]:
        attrs = bid.get("attributes") or {}
        print(f"  - {attrs.get('identifier')}  name={attrs.get('name')}  id={bid.get('id')}")
    penny = find_app_by_bundle(DEFAULT_BUNDLE_ID)
    print()
    if penny:
        print(f"Penny app record FOUND id={penny['id']}")
    else:
        print(
            "Penny app record NOT found for "
            f"{DEFAULT_BUNDLE_ID}. Create it in App Store Connect → My Apps → + once "
            "the Bundle ID exists (API cannot create app records)."
        )
    return 0


def cmd_ensure_bundle_id(args: argparse.Namespace) -> int:
    identifier = args.identifier
    name = args.name
    existing = find_bundle_id(identifier)
    if existing:
        attrs = existing.get("attributes") or {}
        print(f"Bundle ID already exists: {attrs.get('identifier')} id={existing.get('id')}")
        return 0
    created = create_bundle_id(identifier, name)
    attrs = created.get("attributes") or {}
    print(f"Created Bundle ID: {attrs.get('identifier')} id={created.get('id')}")
    print(
        "Next: App Store Connect → My Apps → + → New App → iOS → select this Bundle ID → name Penny."
    )
    return 0


def find_build_by_number(app_id: str, build_number: str, wait_seconds: int) -> dict[str, Any] | None:
    deadline = time.time() + max(0, wait_seconds)
    while True:
        q = urllib.parse.quote(build_number)
        result = api_request(
            "GET",
            f"builds?filter[app]={app_id}&filter[version]={q}&limit=5&sort=-uploadedDate",
        ) or {}
        builds = list(result.get("data") or [])
        if builds:
            return builds[0]
        if time.time() >= deadline:
            return None
        print(f"Waiting for build {build_number} to appear in ASC…", flush=True)
        time.sleep(30)


def add_build_to_group(build_id: str, group_id: str) -> None:
    payload = {
        "data": [
            {
                "type": "builds",
                "id": build_id,
            }
        ]
    }
    api_request("POST", f"betaGroups/{group_id}/relationships/builds", payload)


def cmd_assign_build(args: argparse.Namespace) -> int:
    app = find_app_by_bundle(DEFAULT_BUNDLE_ID)
    if not app:
        print(f"App not found for {DEFAULT_BUNDLE_ID}", file=sys.stderr)
        return 1

    build = find_build_by_number(app["id"], str(args.build_number), args.wait_seconds)
    if not build:
        print(
            f"Build {args.build_number} not visible yet. "
            "Internal Testers still receive builds when automatic distribution is on.",
            file=sys.stderr,
        )
        return 2

    build_id = build["id"]
    attrs = build.get("attributes") or {}
    print(
        f"Found build id={build_id} version={attrs.get('version')} "
        f"processing={attrs.get('processingState')}"
    )

    group_ids: list[str] = []
    if args.internal_group_id:
        group_ids.append(args.internal_group_id)
    if args.external_group_id:
        group_ids.append(args.external_group_id)

    if not group_ids:
        print("No group IDs provided; nothing to assign.")
        return 0

    for group_id in group_ids:
        try:
            add_build_to_group(build_id, group_id)
            print(f"Assigned build to beta group {group_id}")
        except AscError as exc:
            # Already assigned / still processing / external needs review.
            print(f"Could not assign to {group_id}: {exc}", file=sys.stderr)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_status = sub.add_parser("status", help="List apps + bundle IDs; check for Penny")
    p_status.set_defaults(func=cmd_status)

    p_bundle = sub.add_parser("ensure-bundle-id", help="Create iOS Bundle ID if missing")
    p_bundle.add_argument("--identifier", default=DEFAULT_BUNDLE_ID)
    p_bundle.add_argument("--name", default=DEFAULT_BUNDLE_NAME)
    p_bundle.set_defaults(func=cmd_ensure_bundle_id)

    p_assign = sub.add_parser(
        "assign-build",
        help="Attach a processed build to TestFlight beta groups",
    )
    p_assign.add_argument("--build-number", required=True)
    p_assign.add_argument("--internal-group-id", default="")
    p_assign.add_argument("--external-group-id", default="")
    p_assign.add_argument(
        "--wait-seconds",
        type=int,
        default=120,
        help="How long to poll ASC for the new build (default 120)",
    )
    p_assign.set_defaults(func=cmd_assign_build)

    args = parser.parse_args()
    try:
        return args.func(args)
    except AscError as exc:
        print(exc, file=sys.stderr)
        if exc.status in {401, 403}:
            print(
                "Auth failed — check ASC_ISSUER_ID / ASC_KEY_ID / ASC_PRIVATE_KEY "
                "(Admin key required for Bundle ID create).",
                file=sys.stderr,
            )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

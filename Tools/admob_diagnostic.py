#!/usr/bin/env python3
"""Diagnose Gold Rush app-ads.txt verification from public and ASC metadata."""

import json
import os
import sys
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_preflight import first_error_detail, get, make_token  # noqa: E402

EXPECTED_MARKETING_URL = "https://killjoy00.github.io"


def public_listing(bundle_id: str) -> tuple[str | None, str | None]:
    url = "https://itunes.apple.com/lookup?" + urllib.parse.urlencode({"bundleId": bundle_id})
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = json.loads(response.read())
    results = payload.get("results") or []
    if not results:
        return None, None
    item = results[0]
    return item.get("version"), item.get("sellerUrl")


def main() -> int:
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    bundle_id = os.environ["BUNDLE_ID"]
    key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")

    version, seller_url = public_listing(bundle_id)
    print("PUBLIC APP STORE")
    print(f"  version:   {version or '(not found)'}")
    print(f"  sellerUrl: {seller_url or '(absent)'}")
    print("")

    token = make_token(key_path, key_id, issuer_id)
    status, payload = get(f"apps?filter[bundleId]={bundle_id}&limit=1", token)
    if status != 200 or not payload.get("data"):
        print(f"::error::Could not find app record (HTTP {status}): {first_error_detail(payload)}")
        return 1
    app_id = payload["data"][0]["id"]

    status, payload = get(f"apps/{app_id}/appStoreVersions?limit=50", token)
    if status != 200:
        print(f"::error::Could not list App Store versions (HTTP {status}): {first_error_detail(payload)}")
        return 1

    versions = payload.get("data") or []
    versions.sort(key=lambda item: item["attributes"].get("versionString", ""), reverse=True)

    print("APP STORE CONNECT")
    for item in versions:
        attributes = item["attributes"]
        version_string = attributes.get("versionString", "?")
        state = attributes.get("appStoreState", "UNKNOWN")
        loc_status, loc_payload = get(
            f"appStoreVersions/{item['id']}/appStoreVersionLocalizations?limit=50", token
        )
        if loc_status != 200:
            print(f"  {version_string} [{state}] localization read failed: HTTP {loc_status}")
            continue
        localization = next(
            (entry for entry in (loc_payload.get("data") or [])
             if entry["attributes"].get("locale") == "en-US"),
            None,
        )
        if not localization:
            print(f"  {version_string} [{state}] en-US localization: absent")
            continue
        loc = localization["attributes"]
        print(f"  {version_string} [{state}]")
        print(f"    marketingUrl: {loc.get('marketingUrl') or '(absent)'}")
        print(f"    supportUrl:   {loc.get('supportUrl') or '(absent)'}")

    print("")
    if seller_url != EXPECTED_MARKETING_URL:
        print(
            f"::error::Public sellerUrl is {seller_url or 'absent'}; "
            f"AdMob needs {EXPECTED_MARKETING_URL}."
        )
        return 2

    print(f"Public sellerUrl matches {EXPECTED_MARKETING_URL}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

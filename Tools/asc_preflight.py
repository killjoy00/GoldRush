#!/usr/bin/env python3
"""Ask App Store Connect what is actually missing before trying to ship.

`xcodebuild -exportArchive` reports signing problems as "Cloud signing
permission error" and "No profiles for '<bundle id>' were found", which covers
at least four unrelated causes: the API key lacking the role needed to create
signing assets, the bundle ID never being registered, the app record not
existing, or the key belonging to a different team. Each has a different fix and
the message distinguishes none of them.

This queries the API directly and names the cause. It runs before the archive,
so a misconfiguration costs seconds rather than a full signed build.

Deliberately no third-party imports: the runner has Python and openssl, and
requiring `pip install` in CI to diagnose a credentials problem would be its own
source of failure. The ES256 signature is produced by openssl and converted from
DER to the raw r||s form JWT requires using only the standard library.
"""

import base64
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"


def b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw_signature(der: bytes) -> bytes:
    """Convert an ECDSA DER signature to the fixed-width r||s JWT wants.

    openssl emits SEQUENCE { INTEGER r, INTEGER s }. DER integers are signed, so
    a value whose top bit is set carries a leading zero byte that has to come
    back off, and short values need left-padding to 32 bytes.
    """
    if not der or der[0] != 0x30:
        raise ValueError("signature is not a DER SEQUENCE")

    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)

    def read_int(pos: int) -> tuple[int, int]:
        if der[pos] != 0x02:
            raise ValueError("expected a DER INTEGER in the signature")
        length = der[pos + 1]
        value = der[pos + 2 : pos + 2 + length]
        return int.from_bytes(value, "big"), pos + 2 + length

    r, index = read_int(index)
    s, _ = read_int(index)
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def make_token(key_path: str, key_id: str, issuer_id: str) -> str:
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 600,
        "aud": "appstoreconnect-v1",
    }
    signing_input = (
        b64url(json.dumps(header, separators=(",", ":")).encode())
        + "."
        + b64url(json.dumps(payload, separators=(",", ":")).encode())
    )

    completed = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path],
        input=signing_input.encode(),
        capture_output=True,
    )
    if completed.returncode != 0:
        raise SystemExit(f"openssl could not sign with the key: {completed.stderr.decode().strip()}")

    return signing_input + "." + b64url(der_to_raw_signature(completed.stdout))


def get(path: str, token: str) -> tuple[int, dict]:
    request = urllib.request.Request(
        f"{API}/{path}", headers={"Authorization": f"Bearer {token}"}
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        body = error.read()
        try:
            return error.code, json.loads(body)
        except Exception:
            return error.code, {"raw": body.decode(errors="replace")[:400]}
    except Exception as error:  # network, DNS, TLS
        return 0, {"transport_error": str(error)}


def first_error_detail(payload: dict) -> str:
    errors = payload.get("errors") or []
    if not errors:
        return json.dumps(payload)[:300]
    error = errors[0]
    return f"{error.get('title', '?')} — {error.get('detail', '')}".strip()


def main() -> int:
    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    bundle_id = os.environ["BUNDLE_ID"]
    key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")

    if not os.path.exists(key_path):
        print(f"::error::API key not found at {key_path}")
        return 1

    token = make_token(key_path, key_id, issuer_id)
    problems: list[str] = []

    # 1. Does the key authenticate at all?
    status, payload = get("apps?limit=1", token)
    if status == 401:
        print("::error::App Store Connect rejected the API key (401 Unauthorized).")
        print("::error::The Key ID, Issuer ID and .p8 must all come from the SAME key.")
        print(f"::error::Apple said: {first_error_detail(payload)}")
        return 1
    if status == 0:
        print(f"::error::Could not reach App Store Connect: {payload.get('transport_error')}")
        return 1
    if status != 200:
        print(f"::error::Unexpected response listing apps (HTTP {status}): {first_error_detail(payload)}")
        return 1
    print("Authentication: OK — the API key is valid.")

    # 2. Is the bundle ID registered in the developer portal?
    status, payload = get(f"bundleIds?filter[identifier]={bundle_id}&limit=1", token)
    if status == 200 and payload.get("data"):
        entry = payload["data"][0]["attributes"]
        print(f"Bundle ID:      OK — '{bundle_id}' is registered (name: {entry.get('name')}).")
    elif status == 200:
        problems.append(
            f"The bundle ID '{bundle_id}' is NOT registered.\n"
            "  Fix: developer.apple.com/account -> Certificates, IDs & Profiles -> Identifiers\n"
            "       -> + -> App IDs -> App -> Explicit -> enter the bundle ID exactly -> Register."
        )
    else:
        print(f"::warning::Could not check bundle IDs (HTTP {status}): {first_error_detail(payload)}")

    # 3. Does the app record exist in App Store Connect?
    status, payload = get(f"apps?filter[bundleId]={bundle_id}&limit=1", token)
    if status == 200 and payload.get("data"):
        entry = payload["data"][0]["attributes"]
        print(f"App record:     OK — '{entry.get('name')}' exists (SKU: {entry.get('sku')}).")
    elif status == 200:
        problems.append(
            f"No app record exists for '{bundle_id}'.\n"
            "  Fix: appstoreconnect.apple.com/apps -> + -> New App, and pick that bundle ID.\n"
            "       Apple does not allow this step to be automated."
        )
    else:
        print(f"::warning::Could not check app records (HTTP {status}): {first_error_detail(payload)}")

    # 4. Can this key see signing certificates at all?
    status, payload = get("certificates?limit=200", token)
    certificates = payload.get("data", []) if status == 200 else []
    if status == 200:
        print(f"Signing access: OK — the key can read certificates ({len(certificates)} on the team).")
    elif status == 403:
        problems.append(
            "The API key is not permitted to read signing certificates (403).\n"
            "  Fix: the key's role must be Admin.\n"
            "       App Store Connect -> Users and Access -> Integrations -> Team Keys."
        )
    else:
        print(f"::warning::Could not check certificates (HTTP {status}): {first_error_detail(payload)}")

    # 5. Is there a DISTRIBUTION certificate? This is the specific thing export
    #    needs and archive does not. Archive happily signs with a development
    #    identity, so a team with only development certificates gets all the way
    #    to export before failing -- which is exactly the shape of
    #    "Cloud signing permission error" plus "No profiles were found".
    distribution_types = {"DISTRIBUTION", "IOS_DISTRIBUTION", "APPLE_DISTRIBUTION"}
    distribution = [
        c for c in certificates
        if (c.get("attributes") or {}).get("certificateType") in distribution_types
    ]
    if certificates:
        kinds = sorted({(c.get("attributes") or {}).get("certificateType", "?") for c in certificates})
        print(f"                Certificate types present: {', '.join(kinds)}")
    if distribution:
        print(f"Distribution:   OK — {len(distribution)} distribution certificate(s) exist.")
    else:
        problems.append(
            "The team has NO Apple Distribution certificate.\n"
            "  Archive succeeds without one (it signs for development), which is why\n"
            "  this only fails at the export step. Cloud signing tried to create one\n"
            "  and was refused -- that is the 'Cloud signing permission error'.\n"
            "  Cloud signing for distribution requires an ADMIN key. App Manager and\n"
            "  Developer keys can create development assets but not distribution ones,\n"
            "  which is why archive succeeds and only export fails.\n"
            "  Fix: App Store Connect -> Users and Access -> Integrations -> Team Keys\n"
            "       -> revoke the key -> generate a new one with Access: Admin\n"
            "       -> update the ASC_KEY_ID and ASC_KEY_P8 secrets.\n"
            "  Reference: https://developer.apple.com/forums/thread/698117"
        )

    # 6. Is there an App Store provisioning profile for this bundle ID?
    #
    #    When there is not, export falls back to cloud signing to create one --
    #    and that is gated on the key having the ADMIN role. App Manager is not
    #    enough, which is not obvious and is not something the API exposes: there
    #    is no endpoint that reports a key's own role, so this can only be
    #    flagged as the likely cause rather than detected.
    #    Apple's recovery text for the resulting error reads "You haven't been
    #    given access to cloud-managed distribution certificates."
    #    See https://developer.apple.com/forums/thread/698117
    status, payload = get("profiles?filter[profileType]=IOS_APP_STORE&limit=200", token)
    if status == 200:
        names = [(p.get("attributes") or {}).get("name", "") for p in payload.get("data", [])]
        matching = [n for n in names if bundle_id in n]
        if matching:
            print(f"Profile:        OK — App Store profile found: {matching[0]}")
        else:
            # Not a warning: cloud signing creates the profile on demand and
            # this is the normal path on a working Admin key, so flagging it
            # every run would be noise. The note matters only if export fails.
            print(f"Profile:        none stored — export will ask Apple to cloud sign one.")
            print("                If that fails with 'Cloud signing permission error', the")
            print("                API key's role is not Admin (App Manager is not enough).")
            print("                See https://developer.apple.com/forums/thread/698117")
    else:
        print(f"::warning::Could not check profiles (HTTP {status}): {first_error_detail(payload)}")

    # 7. Is Game Center enabled on the App ID? The app ships a
    #    com.apple.developer.game-center entitlement, and signing fails if the
    #    identifier does not carry the matching capability.
    #
    #    Asked for as an `include` on the bundleIds query rather than through the
    #    /bundleIds/{id}/bundleIdCapabilities relationship, which rejects the
    #    pagination parameters with a 400. One request instead of two, as well.
    status, payload = get(
        f"bundleIds?filter[identifier]={bundle_id}&include=bundleIdCapabilities&limit=1",
        token,
    )
    if status == 200 and payload.get("data"):
        enabled = {
            (item.get("attributes") or {}).get("capabilityType")
            for item in payload.get("included", [])
            if item.get("type") == "bundleIdCapabilities"
        }
        if "GAME_CENTER" in enabled:
            print("Game Center:    OK — enabled on the App ID.")
        else:
            print("Game Center:    not listed on the App ID.")
            print("                Automatic signing normally adds it during the archive.")
            print("                If signing fails, enable it at developer.apple.com/account")
            print("                -> Identifiers -> your App ID -> tick Game Center -> Save.")
    else:
        print(f"::warning::Could not read App ID capabilities (HTTP {status}).")

    if problems:
        print("")
        print(f"::error::App Store Connect preflight found {len(problems)} problem(s):")
        for number, problem in enumerate(problems, 1):
            for line_number, line in enumerate(problem.splitlines()):
                prefix = f"::error::{number}. " if line_number == 0 else "::error::   "
                print(prefix + line)
        return 1

    print("")
    print("Preflight passed: key, bundle ID, app record and signing access are all in place.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Push App Store listing copy from the repo into App Store Connect.

The listing text is the only part of shipping that lived nowhere: the binary,
the version and the release pipeline are all in git, but the description a user
actually reads was typed into a web form and never reviewed by anyone. This
puts it under the same review as the code, and makes "what does the store say"
answerable from a checkout.

Reads `docs/app-store/*.txt`, one file per field. A field whose file is absent
is left completely alone -- that is what makes the tool safe to run when only
the release notes changed, and means adding a field is creating a file rather
than editing this script.

Refuses to touch a version that is not editable, and defaults to a dry run that
prints a diff and writes nothing. `--apply` is the only thing that writes.

The JWT signing is imported from asc_preflight rather than copied: converting an
ECDSA DER signature to JWT's r||s form is fiddly enough that two copies would be
one too many.
"""

import argparse
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asc_preflight import API, first_error_detail, get, make_token  # noqa: E402

# Apple rejects anything longer, with a message that does not name the field.
# Checked here so the failure arrives before the network call and says which
# file is too long.
LIMITS = {
    "description": 4000,
    "whatsNew": 4000,
    "promotionalText": 170,
    "keywords": 100,
}

# One file per field. Absent file means "leave whatever is there alone".
FIELD_FILES = {
    "description": "description.txt",
    "whatsNew": "whats-new.txt",
    "promotionalText": "promotional-text.txt",
    "keywords": "keywords.txt",
}

# States where Apple still accepts metadata edits. Anything else -- live,
# in review, pending release -- is refused rather than attempted, because a
# half-applied edit to a released listing is not something a retry fixes.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
    "WAITING_FOR_REVIEW",
}


def patch(path: str, token: str, body: dict) -> tuple[int, dict]:
    request = urllib.request.Request(
        f"{API}/{path}",
        data=json.dumps(body).encode(),
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="PATCH",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.status, json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw)
        except Exception:
            return error.code, {"raw": raw.decode(errors="replace")[:400]}
    except Exception as error:
        return 0, {"transport_error": str(error)}


def load_fields(directory: str) -> dict[str, str]:
    """Read whichever field files exist. Missing files are simply skipped."""
    fields: dict[str, str] = {}
    for field, filename in FIELD_FILES.items():
        path = os.path.join(directory, filename)
        if not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as handle:
            # Trailing newlines are an artefact of the file, not the copy.
            fields[field] = handle.read().rstrip("\n")
    return fields


def check_lengths(fields: dict[str, str]) -> list[str]:
    problems = []
    for field, value in fields.items():
        limit = LIMITS[field]
        if len(value) > limit:
            problems.append(
                f"{FIELD_FILES[field]} is {len(value)} characters; "
                f"App Store Connect allows {limit} for {field}."
            )
    return problems


def show_diff(field: str, current: str, new: str) -> bool:
    """Print a readable before/after. Returns True when they differ."""
    if (current or "") == new:
        print(f"  {field}: unchanged")
        return False
    print(f"  {field}: WOULD CHANGE")
    print(f"    - {len(current or '')} chars currently")
    print(f"    + {len(new)} chars from {FIELD_FILES[field]}")
    current_lines = (current or "").splitlines()
    new_lines = new.splitlines()
    for index in range(max(len(current_lines), len(new_lines))):
        before = current_lines[index] if index < len(current_lines) else None
        after = new_lines[index] if index < len(new_lines) else None
        if before != after:
            if before is not None:
                print(f"    - {before}")
            if after is not None:
                print(f"    + {after}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version",
        required=True,
        help="Marketing version to update, e.g. 1.03. Must already exist in App Store Connect.",
    )
    parser.add_argument("--locale", default="en-US")
    parser.add_argument(
        "--dir",
        default=os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "docs", "app-store"),
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually write. Without this the run is a dry run and changes nothing.",
    )
    args = parser.parse_args()

    # Named rather than a KeyError traceback: this one gets run by hand more
    # often than the preflight does, and "ASC_ISSUER_ID is not set" is a more
    # useful thing to read than a stack trace.
    missing = [name for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "BUNDLE_ID")
               if not os.environ.get(name)]
    if missing:
        print(f"::error::Not set in the environment: {', '.join(missing)}")
        return 1

    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    bundle_id = os.environ["BUNDLE_ID"]
    key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")

    if not os.path.exists(key_path):
        print(f"::error::API key not found at {key_path}")
        return 1

    fields = load_fields(os.path.abspath(args.dir))
    if not fields:
        print(f"::error::No metadata files found in {os.path.abspath(args.dir)}")
        print(f"::error::Expected any of: {', '.join(FIELD_FILES.values())}")
        return 1

    problems = check_lengths(fields)
    if problems:
        for problem in problems:
            print(f"::error::{problem}")
        return 1

    print(f"Fields found: {', '.join(sorted(fields))}")
    print(f"Fields left alone: {', '.join(sorted(set(FIELD_FILES) - set(fields))) or 'none'}")
    print("")

    token = make_token(key_path, key_id, issuer_id)

    status, payload = get(f"apps?filter[bundleId]={bundle_id}&limit=1", token)
    if status != 200 or not payload.get("data"):
        print(f"::error::Could not find the app record for {bundle_id} (HTTP {status}).")
        print(f"::error::{first_error_detail(payload)}")
        return 1
    app_id = payload["data"][0]["id"]

    status, payload = get(
        f"apps/{app_id}/appStoreVersions?filter[versionString]={args.version}&limit=1", token
    )
    if status != 200:
        print(f"::error::Could not list versions (HTTP {status}): {first_error_detail(payload)}")
        return 1
    if not payload.get("data"):
        print(f"::error::App Store Connect has no version {args.version}.")
        print("::error::Create it first: App Store Connect -> your app -> + next to iOS App,")
        print(f"::error::and enter {args.version} exactly as the build declares it.")
        return 1

    version = payload["data"][0]
    version_id = version["id"]
    state = version["attributes"].get("appStoreState", "UNKNOWN")
    print(f"Version {args.version} found (state: {state})")

    if state not in EDITABLE_STATES:
        print(f"::error::Version {args.version} is {state}, which does not accept metadata edits.")
        print("::error::Released versions are frozen; edit the next version instead.")
        return 1

    status, payload = get(
        f"appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50", token
    )
    if status != 200:
        print(f"::error::Could not read localizations (HTTP {status}): {first_error_detail(payload)}")
        return 1

    localization = next(
        (item for item in payload.get("data", [])
         if item["attributes"].get("locale") == args.locale),
        None,
    )
    if localization is None:
        available = [i["attributes"].get("locale") for i in payload.get("data", [])]
        print(f"::error::No {args.locale} localization on version {args.version}.")
        print(f"::error::Available: {', '.join(available) or 'none'}")
        return 1

    print(f"Locale {args.locale} found.")
    print("")
    print("Changes:")
    changed = {
        field: value
        for field, value in fields.items()
        if show_diff(field, localization["attributes"].get(field), value)
    }
    print("")

    if not changed:
        print("Nothing to do — App Store Connect already matches the repo.")
        return 0

    if not args.apply:
        print(f"Dry run. {len(changed)} field(s) would change: {', '.join(sorted(changed))}")
        print("Re-run with apply enabled to write them.")
        return 0

    status, payload = patch(
        f"appStoreVersionLocalizations/{localization['id']}",
        token,
        {
            "data": {
                "type": "appStoreVersionLocalizations",
                "id": localization["id"],
                "attributes": changed,
            }
        },
    )
    if status not in (200, 204):
        print(f"::error::Update failed (HTTP {status}): {first_error_detail(payload)}")
        return 1

    print(f"Updated {len(changed)} field(s) on {args.version} ({args.locale}): "
          f"{', '.join(sorted(changed))}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

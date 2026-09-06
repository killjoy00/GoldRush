#!/usr/bin/env python3
"""Resolve a simulator model name to a UDID, reading `simctl list` JSON on stdin.

Apple renames device models most cycles, and runner images move under you. A
pinned UDID or a hardcoded model turns that into a "device not found" days
after it stops being anyone's fault, so the model is an input and the lookup
happens at run time.

Exact name match wins. A substring is accepted only when it identifies exactly
one model, because "iPhone 17 Pro" is a prefix of "iPhone 17 Pro Max" and
silently photographing the wrong screen size is worse than failing.

Among devices of the matched model, the newest runtime wins: a runner usually
carries several iOS versions and the oldest is the least like what users have.

Usage:
    xcrun simctl list devices available -j | pick_simulator.py "iPhone 17 Pro Max"
"""

import json
import re
import sys


def runtime_sort_key(runtime_id: str) -> tuple:
    """Order runtimes by version, so 'iOS-26-1' beats 'iOS-18-5'.

    Sorting the identifier as a string would put iOS-9 above iOS-26, so the
    numbers are pulled out and compared as numbers.
    """
    return tuple(int(part) for part in re.findall(r"\d+", runtime_id)) or (0,)


def pick(payload: dict, wanted: str) -> tuple[str, str, str]:
    """Return (udid, model name, runtime) for the best match, or raise."""
    # {runtime identifier: [device, ...]}
    by_runtime = payload.get("devices", {})

    candidates = []  # (runtime, device dict)
    for runtime, devices in by_runtime.items():
        for device in devices:
            # `available` already filters, but a stale payload may not have.
            if device.get("isAvailable") is False:
                continue
            candidates.append((runtime, device))

    if not candidates:
        raise SystemExit("No available simulators at all in the simctl payload.")

    exact = [(r, d) for r, d in candidates if d.get("name") == wanted]
    if exact:
        chosen = max(exact, key=lambda pair: runtime_sort_key(pair[0]))
        return chosen[1]["udid"], chosen[1]["name"], chosen[0]

    partial = [(r, d) for r, d in candidates if wanted.lower() in d.get("name", "").lower()]
    distinct_names = sorted({d["name"] for _, d in partial})
    if len(distinct_names) == 1:
        chosen = max(partial, key=lambda pair: runtime_sort_key(pair[0]))
        return chosen[1]["udid"], chosen[1]["name"], chosen[0]

    available = sorted({d.get("name", "?") for _, d in candidates})
    if len(distinct_names) > 1:
        raise SystemExit(
            f"'{wanted}' is ambiguous — it matches {len(distinct_names)} models: "
            f"{', '.join(distinct_names)}. Pass the full model name."
        )
    raise SystemExit(
        f"No simulator matching '{wanted}'.\nAvailable models:\n  "
        + "\n  ".join(available)
    )


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit("usage: pick_simulator.py <device name>   (simctl JSON on stdin)")
    payload = json.load(sys.stdin)
    udid, name, runtime = pick(payload, sys.argv[1])
    # Stdout is the UDID alone so a shell can capture it; the rest goes to
    # stderr so it still shows in the log without polluting the value.
    print(f"Matched '{name}' on {runtime}", file=sys.stderr)
    print(udid)
    return 0


if __name__ == "__main__":
    sys.exit(main())

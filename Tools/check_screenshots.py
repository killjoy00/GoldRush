#!/usr/bin/env python3
"""Verify a directory of captured screenshots before anyone trusts them.

Two failure modes in a capture pipeline are completely silent. A route that
falls back to the home screen produces a valid PNG of the wrong screen, and an
appearance flip that did not take produces a valid PNG in the wrong colours.
Both look like success. What they cannot do is differ from each other, so
identical content is treated as a failure rather than a coincidence.

Dimensions are read from the PNG header rather than by importing Pillow: the
header is eight bytes at a fixed offset, and a capture pipeline should not fail
because a runner image dropped a wheel.

Usage:
    check_screenshots.py <directory> [--expect-width W --expect-height H]
"""

import argparse
import hashlib
import pathlib
import struct
import sys


def png_size(path: pathlib.Path) -> tuple[int, int]:
    """Width and height from the IHDR chunk.

    A PNG is an 8-byte signature, then a chunk header, then IHDR's payload
    beginning with two big-endian 32-bit integers.
    """
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.name} is not a PNG")
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory")
    parser.add_argument("--expect-width", type=int)
    parser.add_argument("--expect-height", type=int)
    args = parser.parse_args()

    directory = pathlib.Path(args.directory)
    images = sorted(directory.glob("*.png"))

    if not images:
        print(f"::error::No PNGs in {directory} — the capture produced nothing.")
        return 1

    problems: list[str] = []
    seen: dict[str, str] = {}

    print(f"{'file':<34} {'dimensions':>13}  digest")
    for image in images:
        digest = hashlib.sha256(image.read_bytes()).hexdigest()
        try:
            width, height = png_size(image)
        except ValueError as error:
            problems.append(str(error))
            continue

        print(f"{image.name:<34} {f'{width}x{height}':>13}  {digest[:16]}")

        if digest in seen:
            problems.append(
                f"{image.name} is byte-identical to {seen[digest]}. "
                "Either a screen route fell back to the default, or an "
                "appearance change did not take effect."
            )
        else:
            seen[digest] = image.name

        if args.expect_width and args.expect_height:
            if (width, height) != (args.expect_width, args.expect_height):
                problems.append(
                    f"{image.name} is {width}x{height}, expected "
                    f"{args.expect_width}x{args.expect_height}. App Store "
                    "Connect rejects anything else for this size class."
                )

    print()
    if problems:
        for problem in problems:
            print(f"::error::{problem}")
        return 1

    print(f"{len(images)} screenshot(s) checked: all distinct, all correctly sized.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

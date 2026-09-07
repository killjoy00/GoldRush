#!/usr/bin/env python3
"""Verify a directory of captured screenshots before anyone trusts them.

Three failure modes in a capture pipeline are completely silent, and all three
produce a valid PNG that looks like success in the artifact listing.

A route that falls back to the home screen produces a valid PNG of the wrong
screen, and an appearance flip that did not take produces a valid PNG in the
wrong colours. Neither can differ from the capture it duplicates, so identical
content is treated as a failure rather than a coincidence.

The third is a blank frame. `simctl io screenshot` occasionally returns before
the app has drawn -- in one observed run the write itself stalled for twelve
seconds and produced a solid black 2064x2752 image. It is correctly sized and
unique, so neither check above notices, and it reached a human only because
somebody opened it. That is not a guarantee, so it is measured here instead.

Dimensions and pixels are read without importing Pillow: the header is eight
bytes at a fixed offset and the image data is zlib plus a documented per-row
filter, both in the standard library. A capture pipeline should not fail
because a runner image dropped a wheel.

Usage:
    check_screenshots.py <directory> [--expect-width W --expect-height H]
"""

import argparse
import hashlib
import pathlib
import struct
import sys
import zlib

# Luminance standard deviation below which an image is considered blank.
#
# Measured across ten real captures of this app, which has a deliberately very
# dark theme: the lowest legitimate spread was 18.6 (the iPad rules sheet, 86%
# of its pixels below luminance 24), while an observed blank frame scored 4.6.
# Twelve sits roughly a factor of two from each side. Spread is used rather
# than mean brightness because it is colour-agnostic -- a solid white or solid
# grey frame is just as empty as a solid black one, and scores just as low.
MIN_DETAIL = 12.0

# Every Nth pixel in each direction. Full decoding is unavoidable because PNG
# rows are filtered against their predecessor, but the statistics do not need
# every pixel, and this keeps a 2064x2752 image at roughly two seconds.
SAMPLE_STEP = 7


def read_chunks(data: bytes) -> tuple[tuple, bytes]:
    """Return the parsed IHDR fields and the concatenated IDAT payload."""
    if len(data) < 8 or data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    header, parts, position = None, [], 8
    while position + 8 <= len(data):
        length = struct.unpack(">I", data[position:position + 4])[0]
        kind = data[position + 4:position + 8]
        body = data[position + 8:position + 8 + length]
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", body)
        elif kind == b"IDAT":
            parts.append(body)
        elif kind == b"IEND":
            break
        position += 12 + length
    if header is None:
        raise ValueError("no IHDR chunk")
    return header, b"".join(parts)


def png_size(path: pathlib.Path) -> tuple[int, int]:
    """Width and height from the IHDR chunk."""
    with path.open("rb") as handle:
        head = handle.read(24)
    if len(head) < 24 or head[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"{path.name} is not a PNG")
    width, height = struct.unpack(">II", head[16:24])
    return width, height


def luminance_spread(path: pathlib.Path) -> tuple[float, float]:
    """Mean and standard deviation of sampled luminance.

    Raises rather than returning a benign default when the image cannot be
    decoded: a checker that silently skips the analysis is the same as not
    having it, which is the hole this function exists to close.
    """
    header, compressed = read_chunks(path.read_bytes())
    width, height, depth, colour, _, _, interlace = header
    if depth != 8 or interlace != 0 or colour not in (0, 2, 4, 6):
        raise ValueError(
            f"unsupported PNG form (bit depth {depth}, colour type {colour}, "
            f"interlace {interlace}) -- cannot check whether it is blank"
        )
    channels = {0: 1, 2: 3, 4: 2, 6: 4}[colour]
    raw = zlib.decompress(compressed)
    stride = width * channels

    values: list[int] = []
    previous = bytearray(stride)
    offset = 0
    for y in range(height):
        method = raw[offset]
        offset += 1
        line = bytearray(raw[offset:offset + stride])
        offset += stride
        # Undo the row filter. Rows are sequential by construction, so none of
        # this can be skipped even though only every Nth row is sampled.
        if method == 1:  # Sub
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 255
        elif method == 2:  # Up
            for i in range(stride):
                line[i] = (line[i] + previous[i]) & 255
        elif method == 3:  # Average
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + previous[i]) >> 1)) & 255
        elif method == 4:  # Paeth
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                up = previous[i]
                corner = previous[i - channels] if i >= channels else 0
                estimate = left + up - corner
                da, db, dc = (abs(estimate - left), abs(estimate - up),
                              abs(estimate - corner))
                if da <= db and da <= dc:
                    nearest = left
                elif db <= dc:
                    nearest = up
                else:
                    nearest = corner
                line[i] = (line[i] + nearest) & 255
        elif method != 0:
            raise ValueError(f"unknown row filter {method} on row {y}")

        if y % SAMPLE_STEP == 0:
            for x in range(0, width, SAMPLE_STEP):
                i = x * channels
                if channels >= 3:
                    values.append(
                        (line[i] * 299 + line[i + 1] * 587 + line[i + 2] * 114)
                        // 1000
                    )
                else:
                    values.append(line[i])
        previous = line

    if not values:
        raise ValueError("no pixels sampled")
    mean = sum(values) / len(values)
    variance = sum((v - mean) ** 2 for v in values) / len(values)
    return mean, variance ** 0.5


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "path",
        help="a directory of captures, or a single PNG to check on its own",
    )
    parser.add_argument("--expect-width", type=int)
    parser.add_argument("--expect-height", type=int)
    parser.add_argument(
        "--min-detail", type=float, default=MIN_DETAIL,
        help="luminance standard deviation below which a capture is blank",
    )
    args = parser.parse_args()

    # A single file is accepted so the capture loop can check a frame the
    # instant it is taken and re-take a blank one, rather than the whole run
    # failing at the end over something a second attempt would have fixed.
    target = pathlib.Path(args.path)
    if target.is_file():
        images = [target]
    else:
        images = sorted(target.glob("*.png"))

    if not images:
        print(f"::error::No PNGs in {target} — the capture produced nothing.")
        return 1

    problems: list[str] = []
    seen: dict[str, str] = {}

    print(f"{'file':<34} {'dimensions':>13}  {'mean':>6} {'spread':>7}  digest")
    for image in images:
        digest = hashlib.sha256(image.read_bytes()).hexdigest()
        try:
            width, height = png_size(image)
        except ValueError as error:
            problems.append(str(error))
            continue

        try:
            mean, spread = luminance_spread(image)
            detail = f"{mean:6.2f} {spread:7.2f}"
        except (ValueError, zlib.error) as error:
            mean, spread = None, None
            detail = f"{'?':>6} {'?':>7}"
            problems.append(f"{image.name}: {error}")

        print(f"{image.name:<34} {f'{width}x{height}':>13}  {detail}  "
              f"{digest[:16]}")

        if digest in seen:
            problems.append(
                f"{image.name} is byte-identical to {seen[digest]}. "
                "Either a screen route fell back to the default, or an "
                "appearance change did not take effect."
            )
        else:
            seen[digest] = image.name

        if spread is not None and spread < args.min_detail:
            problems.append(
                f"{image.name} is blank: luminance spread {spread:.2f} is "
                f"below {args.min_detail:.2f} (mean brightness {mean:.2f}). "
                "The app had not drawn when the frame was taken."
            )

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

    print(f"{len(images)} screenshot(s) checked: all distinct, all correctly "
          "sized, none blank.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
set -euo pipefail

gradle -p Android :app:assembleDebug :app:assembleDebugAndroidTest --no-daemon --stacktrace

app_apk="$(find Android/app/build/outputs/apk/debug -maxdepth 1 -type f -name '*.apk' | head -n 1)"
test_apk="$(find Android/app/build/outputs/apk/androidTest/debug -maxdepth 1 -type f -name '*.apk' | head -n 1)"

test -n "$app_apk"
test -n "$test_apk"
echo "App APK: $app_apk"
echo "Test APK: $test_apk"

adb install -r "$app_apk"
adb install -r "$test_apk"

instrumentation="$(adb shell pm list instrumentation | sed -n 's/^instrumentation:\([^ ]*\).*target=com.killjoy00.goldrush.*/\1/p' | head -n 1 | tr -d '\r')"
test -n "$instrumentation"
echo "Using instrumentation: $instrumentation"

result="$(adb shell am instrument -w -r -e class com.killjoy00.goldrush.StoreScreenshotTest "$instrumentation")"
printf '%s\n' "$result"
printf '%s\n' "$result" | tr -d '\r' | grep -q '^OK ('

output_dir="generated/play-store/android-phone"
rm -rf "$output_dir"
mkdir -p "$output_dir"

remote_dir="/sdcard/Android/data/com.killjoy00.goldrush/files/play-store"
adb shell "ls -l '$remote_dir'"
adb pull "$remote_dir/." "$output_dir/"

python3 - <<'PY'
from pathlib import Path
from PIL import Image

directory = Path("generated/play-store/android-phone")
expected = [
    "01-play-your-way.png",
    "02-draft-scoring-plan.png",
    "03-split-the-claim.png",
    "04-choose-a-pile.png",
]

for name in expected:
    path = directory / name
    if not path.is_file():
        raise SystemExit(f"Missing screenshot: {path}")
    with Image.open(path) as source:
        image = source.convert("RGB")
        width, height = image.size
        if min(width, height) < 320 or max(width, height) > 3840:
            raise SystemExit(f"Play screenshot dimensions out of range: {name} {image.size}")
        if max(width, height) > 2 * min(width, height):
            raise SystemExit(f"Play screenshot aspect ratio exceeds 2:1: {name} {image.size}")
        image.save(path, format="PNG", optimize=True)
        print(f"Validated {name}: {width}x{height}")
PY

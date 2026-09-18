#!/usr/bin/env bash
set -euo pipefail

variant="${1:?variant required}"
api="${2:?api required}"

if [ "$variant" = "release" ]; then
  gradle -p Android :app:assembleRelease --no-daemon --stacktrace
  unsigned="$(find Android/app/build/outputs/apk/release -maxdepth 1 -type f \( -name '*unsigned*.apk' -o -name 'app-release.apk' \) | head -n 1)"
  test -n "$unsigned"

  keystore="$RUNNER_TEMP/goldrush-upload.jks"
  apk="$RUNNER_TEMP/goldrush-release-signed.apk"
  printf '%s' "$ANDROID_UPLOAD_KEYSTORE_BASE64" | base64 --decode > "$keystore"
  test -s "$keystore"

  apksigner_bin="$(find "${ANDROID_HOME:-/usr/local/lib/android/sdk}/build-tools" -type f -name apksigner | sort -V | tail -n 1)"
  test -x "$apksigner_bin"

  "$apksigner_bin" sign \
    --ks "$keystore" \
    --ks-pass "pass:$ANDROID_UPLOAD_KEYSTORE_PASSWORD" \
    --ks-key-alias "$ANDROID_UPLOAD_KEY_ALIAS" \
    --key-pass "pass:$ANDROID_UPLOAD_KEY_PASSWORD" \
    --out "$apk" \
    "$unsigned"
  "$apksigner_bin" verify "$apk"
elif [ "$variant" = "debug" ]; then
  gradle -p Android :app:assembleDebug --no-daemon --stacktrace
  apk="$(find Android/app/build/outputs/apk/debug -maxdepth 1 -type f -name '*.apk' | head -n 1)"
  test -n "$apk"
else
  echo "Unknown variant: $variant" >&2
  exit 2
fi

adb install -r "$apk"
adb logcat -c || true

dump_logcat_and_fail() {
  stage="$1"
  echo "::error::Gold Rush process died during $stage"
  adb logcat -d > /tmp/goldrush-smoke-logcat.txt || true
  grep -E -A60 -B20 'FATAL EXCEPTION|Process: com\\.killjoy00\\.goldrush|AndroidRuntime' /tmp/goldrush-smoke-logcat.txt || true
  tail -n 250 /tmp/goldrush-smoke-logcat.txt || true
  exit 1
}

adb shell am start -W -n com.killjoy00.goldrush/.MainActivity
sleep 5
if ! adb shell pidof com.killjoy00.goldrush >/dev/null; then
  dump_logcat_and_fail "initial launch"
fi

adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -W -n com.killjoy00.goldrush/.MainActivity
sleep 3
if ! adb shell pidof com.killjoy00.goldrush >/dev/null; then
  dump_logcat_and_fail "background/foreground restore"
fi

adb shell settings put system accelerometer_rotation 0 || true
adb shell settings put system user_rotation 1 || true
sleep 3
if ! adb shell pidof com.killjoy00.goldrush >/dev/null; then
  dump_logcat_and_fail "rotation"
fi

adb logcat -d > /tmp/goldrush-smoke-logcat.txt
if grep -E -A25 -B5 'FATAL EXCEPTION|Process: com\.killjoy00\.goldrush' /tmp/goldrush-smoke-logcat.txt; then
  echo "::error::Fatal exception detected for Gold Rush $variant"
  exit 1
fi

echo "ANDROID_SMOKE_OK variant=$variant api=$api"

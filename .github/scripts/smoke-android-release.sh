#!/usr/bin/env bash
set -euo pipefail

gradle -p Android :app:assembleRelease --no-daemon --stacktrace

unsigned="$(find Android/app/build/outputs/apk/release -maxdepth 1 -type f \( -name '*unsigned*.apk' -o -name 'app-release.apk' \) | head -n 1)"
test -n "$unsigned"
test -s "$unsigned"

keystore="$RUNNER_TEMP/goldrush-upload.jks"
signed="$RUNNER_TEMP/goldrush-release-smoke.apk"
printf '%s' "$ANDROID_UPLOAD_KEYSTORE_BASE64" | base64 --decode > "$keystore"
test -s "$keystore"

apksigner sign \
  --ks "$keystore" \
  --ks-pass "pass:$ANDROID_UPLOAD_KEYSTORE_PASSWORD" \
  --ks-key-alias "$ANDROID_UPLOAD_KEY_ALIAS" \
  --key-pass "pass:$ANDROID_UPLOAD_KEY_PASSWORD" \
  --out "$signed" \
  "$unsigned"
apksigner verify "$signed"

adb install -r "$signed"
adb logcat -c || true

adb shell am start -W -n com.killjoy00.goldrush/.MainActivity
sleep 5
adb shell pidof com.killjoy00.goldrush >/dev/null

adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -W -n com.killjoy00.goldrush/.MainActivity
sleep 3
adb shell pidof com.killjoy00.goldrush >/dev/null

adb shell settings put system accelerometer_rotation 0 || true
adb shell settings put system user_rotation 1 || true
sleep 3
adb shell pidof com.killjoy00.goldrush >/dev/null

adb logcat -d > "$RUNNER_TEMP/goldrush-release-smoke-logcat.txt" || true
if grep -E -A35 -B5 'FATAL EXCEPTION|Process: com\.killjoy00\.goldrush' "$RUNNER_TEMP/goldrush-release-smoke-logcat.txt"; then
  echo "::error::Fatal exception detected in minified Gold Rush Release build."
  exit 1
fi

echo "ANDROID_RELEASE_SMOKE_OK"

#!/usr/bin/env bash
set -euo pipefail
api="${1:?api required}"

gradle -p Android :app:assembleRelease --no-daemon --stacktrace
unsigned="$(find Android/app/build/outputs/apk/release -maxdepth 1 -type f \( -name '*unsigned*.apk' -o -name 'app-release.apk' \) | head -n 1)"
test -n "$unsigned"

keystore="$RUNNER_TEMP/goldrush-upload.jks"
signed="$RUNNER_TEMP/goldrush-release-signed.apk"
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
adb shell am start -W -n com.killjoy00.goldrush/.MainActivity || true
sleep 6
adb logcat -d > /tmp/goldrush-release-logcat.txt || true

if grep -E -A35 -B5 'FATAL EXCEPTION|Process: com\.killjoy00\.goldrush' /tmp/goldrush-release-logcat.txt; then
  echo "::error::Fatal exception detected for minified Gold Rush release"
  exit 1
fi

adb shell pidof com.killjoy00.goldrush >/dev/null
echo "ANDROID_RELEASE_SMOKE_OK api=$api"

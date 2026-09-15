#!/usr/bin/env bash
set -euo pipefail

gradle_file="${1:-Android/app/build.gradle.kts}"
expected_publisher="1217971050094766"
expected_app_id="ca-app-pub-${expected_publisher}~3907429685"
expected_banner_id="ca-app-pub-${expected_publisher}/4428717591"
google_sample_prefix="ca-app-pub-3940256099942544"

if [[ ! -f "$gradle_file" ]]; then
  echo "::error::Android Gradle config not found: $gradle_file"
  exit 1
fi

app_id_count="$(grep -Ec '^val admobAppId = "[^"]+"$' "$gradle_file" || true)"
banner_id_count="$(grep -Ec '^val admobBannerAdUnitId = "[^"]+"$' "$gradle_file" || true)"

if [[ "$app_id_count" != "1" ]]; then
  echo "::error::Expected exactly one admobAppId declaration in $gradle_file; found $app_id_count."
  exit 1
fi
if [[ "$banner_id_count" != "1" ]]; then
  echo "::error::Expected exactly one admobBannerAdUnitId declaration in $gradle_file; found $banner_id_count."
  exit 1
fi

app_id="$(sed -n 's/^val admobAppId = "\([^"]*\)"$/\1/p' "$gradle_file")"
banner_id="$(sed -n 's/^val admobBannerAdUnitId = "\([^"]*\)"$/\1/p' "$gradle_file")"

if [[ "$app_id" == ${google_sample_prefix}* || "$banner_id" == ${google_sample_prefix}* ]]; then
  echo "::error::Google sample AdMob IDs are forbidden in signed Play builds."
  exit 1
fi

if [[ ! "$app_id" =~ ^ca-app-pub-${expected_publisher}~[0-9]+$ ]]; then
  echo "::error::Android AdMob app ID does not belong to expected publisher pub-${expected_publisher}: ${app_id:-missing}"
  exit 1
fi
if [[ ! "$banner_id" =~ ^ca-app-pub-${expected_publisher}/[0-9]+$ ]]; then
  echo "::error::Android banner ad-unit ID does not belong to expected publisher pub-${expected_publisher}: ${banner_id:-missing}"
  exit 1
fi

if [[ "$app_id" != "$expected_app_id" ]]; then
  echo "::error::Unexpected Gold Rush Android AdMob app ID. Expected $expected_app_id but found $app_id."
  exit 1
fi
if [[ "$banner_id" != "$expected_banner_id" ]]; then
  echo "::error::Unexpected Gold Rush Android banner ad-unit ID. Expected $expected_banner_id but found $banner_id."
  exit 1
fi

if ! grep -Fq 'manifestPlaceholders["adMobAppId"] = admobAppId' "$gradle_file"; then
  echo "::error::Manifest AdMob app ID is no longer wired from admobAppId."
  exit 1
fi
if ! grep -Fq 'buildConfigField("String", "ADMOB_APP_ID", "\"$admobAppId\"")' "$gradle_file"; then
  echo "::error::BuildConfig.ADMOB_APP_ID is no longer wired from admobAppId."
  exit 1
fi
if ! grep -Fq 'buildConfigField("String", "ADMOB_BANNER_AD_UNIT_ID", "\"$admobBannerAdUnitId\"")' "$gradle_file"; then
  echo "::error::BuildConfig.ADMOB_BANNER_AD_UNIT_ID is no longer wired from admobBannerAdUnitId."
  exit 1
fi

echo "Verified production Android AdMob inventory."
echo "App ID: $app_id"
echo "Banner ID: $banner_id"
echo "Publisher: pub-$expected_publisher"

#!/usr/bin/env bash
# Write the App Store Connect API key to the path xcodebuild and the ASC tools
# expect, normalising the shapes a copy-pasted .p8 secret arrives in.
#
# The elaborate handling is not defensive programming for its own sake: the
# secret has turned up as PEM text, as PEM with the newlines flattened to the
# literal characters backslash-n, as base64 of the whole file, and as base64 of
# just the PEM body with its BEGIN/END lines stripped. Each produces a different
# downstream failure, none of which mentions the key.
#
# Extracted from testflight.yml so metadata and release runs share one
# implementation. testflight.yml still carries its own copy: it is the critical
# path, and this script should prove itself on the low-stakes workflow before
# that one is changed to call it.
#
# Requires ASC_KEY_ID, ASC_KEY_P8 and RUNNER_TEMP in the environment.

set -uo pipefail
mkdir -p ~/.appstoreconnect/private_keys
KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8"
RAW="$RUNNER_TEMP/asc_key_raw"
printf '%s' "$ASC_KEY_P8" > "$RAW"
tr -d '\r' < "$RAW" > "$RAW.n" && mv "$RAW.n" "$RAW"
if grep -q 'BEGIN PRIVATE KEY' "$RAW" && ! grep -q '^-----END PRIVATE KEY-----' "$RAW"; then
  echo "note: expanding literal \\n sequences into real newlines"
  perl -pe 's/\\n/\n/g' "$RAW" > "$RAW.n" && mv "$RAW.n" "$RAW"
fi
if grep -q 'BEGIN PRIVATE KEY' "$RAW"; then
  echo "ASC_KEY_P8 looks like PEM text; using it as-is."
  cp "$RAW" "$KEY_PATH"
else
  echo "ASC_KEY_P8 is not PEM text; trying to base64-decode it."
  tr -d '[:space:]' < "$RAW" > "$RAW.compact"
  DECODED="$RUNNER_TEMP/asc_key_decoded"
  if   base64 -D       < "$RAW.compact" > "$DECODED" 2>/dev/null && [ -s "$DECODED" ]; then
    echo "decoded with: base64 -D (BSD)"
  elif base64 -d       < "$RAW.compact" > "$DECODED" 2>/dev/null && [ -s "$DECODED" ]; then
    echo "decoded with: base64 -d"
  elif base64 --decode < "$RAW.compact" > "$DECODED" 2>/dev/null && [ -s "$DECODED" ]; then
    echo "decoded with: base64 --decode (GNU)"
  else
    : > "$DECODED"
  fi
  if grep -q 'BEGIN PRIVATE KEY' "$DECODED" 2>/dev/null; then
    echo "decoded to a full PEM file."
    cp "$DECODED" "$KEY_PATH"
  elif [ "$(head -c1 "$DECODED" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = "30" ]; then
    echo "decoded to raw DER (PEM header lines were missing); re-wrapping."
    {
      echo "-----BEGIN PRIVATE KEY-----"
      fold -w 64 "$RAW.compact"
      echo ""
      echo "-----END PRIVATE KEY-----"
    } > "$KEY_PATH"
    grep -v '^$' "$KEY_PATH" > "$KEY_PATH.n" && mv "$KEY_PATH.n" "$KEY_PATH"
  else
    : > "$KEY_PATH"
  fi
  rm -f "$DECODED"
fi
if ! grep -q 'BEGIN PRIVATE KEY' "$KEY_PATH" 2>/dev/null; then
  LEN=$(wc -c < "$RAW" | tr -d ' ')
  HAS_DASH=$(grep -qc '^-----' "$RAW" 2>/dev/null && echo yes || echo no)
  IS_B64=$(grep -Eq '^[A-Za-z0-9+/=[:space:]]+$' "$RAW" && echo yes || echo no)
  echo "::error::ASC_KEY_P8 is neither a PEM private key nor valid base64 of one."
  echo "::error::Secret is ${LEN} characters. Begins with dashes: ${HAS_DASH}. Base64 charset only: ${IS_B64}."
  rm -f "$RAW" "$RAW.compact"
  exit 1
fi
chmod 600 "$KEY_PATH"
rm -f "$RAW" "$RAW.compact"
if command -v openssl >/dev/null 2>&1; then
  if openssl pkey -in "$KEY_PATH" -noout 2>/dev/null; then
    echo "openssl parsed the key successfully."
  else
    echo "::error::The key was assembled but openssl cannot parse it as a private key."
    exit 1
  fi
fi
echo "API key installed at AuthKey_${ASC_KEY_ID}.p8 ($(wc -c < "$KEY_PATH" | tr -d ' ') bytes)."


#!/usr/bin/env bash
# Build an APK branded for one company: its own app name, launcher icon and
# package, with the Company ID step skipped.
#
#   tool/build_company_apk.sh <COMPANY_ID> [CONTROL_URL]
#
# Name, colours and logo come from the company's Customer Tenant record on
# the control server. Output: build/brand/<COMPANY_ID>/<Company Name>.apk
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "usage: $0 <COMPANY_ID> [CONTROL_URL]" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
ID="$(echo "$1" | tr '[:lower:]' '[:upper:]')"
CONTROL="${2:-$(grep -v '^ *//' lib/core/config/app_config.dart | sed -n "s/.*defaultValue: '\(https\?:[^']*\)'.*/\1/p" | head -1)}"
OUT="build/brand/$ID"

rm -rf "$OUT"
mkdir -p "$OUT"
echo "Fetching branding for $ID from $CONTROL ..."
INFO="$(python3 tool/brand_assets.py "$ID" "$CONTROL" "$OUT")"
NAME="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["company_name"])' "$INFO")"
echo "Company: $NAME"

flutter build apk --release \
  --dart-define=TCB_MIDDLEWARE_URL="$CONTROL" \
  --dart-define=BRAND_COMPANY_ID="$ID" \
  --dart-define=BRAND_NAME="$NAME" \
  --android-project-arg=brandName="$NAME" \
  --android-project-arg=brandId="$ID" \
  --android-project-arg=brandIconDir="$PWD/$OUT/res"

APK="$OUT/$(echo "$NAME" | tr -c 'A-Za-z0-9._-' '_' | sed 's/_*$//').apk"
cp build/app/outputs/flutter-apk/app-release.apk "$APK"
echo
echo "Done: $APK"

#!/bin/bash
# Raise the build number, build the iPhone app, and deliver it to App Store Connect (TestFlight)
# with Transporter. Run from anywhere:
#
#   ./scripts/testflight.sh             raise build number, build, deliver
#   ./scripts/testflight.sh --no-bump   build and deliver with the current build number
#   ./scripts/testflight.sh --open      build, then open the .ipa in the Transporter app (you click Deliver)
#   ./scripts/testflight.sh --transporter  upload with Transporter's command-line tool instead of altool
#
# One-time setup: save your app-specific password (from account.apple.com) in the Mac keychain:
#   security add-generic-password -U -a "krishna.mula9@gmail.com" -s "AC_PASSWORD" -w "xxxx-xxxx-xxxx-xxxx"
set -euo pipefail

APPLE_ID="${APPLE_ID:-krishna.mula9@gmail.com}"
KEYCHAIN_ITEM="${KEYCHAIN_ITEM:-AC_PASSWORD}"
TRANSPORTER="/Applications/Transporter.app/Contents/itms/bin/iTMSTransporter"

cd "$(dirname "$0")/.."

BUMP=1
OPEN=0
USE_TRANSPORTER=0
for arg in "$@"; do
  case "$arg" in
    --no-bump) BUMP=0 ;;
    --open) OPEN=1 ;;
    --transporter) USE_TRANSPORTER=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# version: 0.1.0+3  ->  name 0.1.0, build 3
current=$(grep -E '^version: ' pubspec.yaml | sed 's/^version: //')
name=${current%%+*}
build=${current##*+}
[ "$name" = "$current" ] && build=0
if [ "$BUMP" = 1 ]; then
  build=$((build + 1))
  sed -i '' -E "s/^version: .*/version: ${name}+${build}/" pubspec.yaml
fi
echo "==> Hoopla ${name} (${build})"

flutter pub get
flutter build ipa --release

ipa=$(ls -t build/ios/ipa/*.ipa | head -1)
echo "==> Built ${ipa}"

if [ "$OPEN" = 1 ]; then
  open -a Transporter "$ipa"
  echo "==> Opened in Transporter. Click Deliver."
  exit 0
fi

password=$(security find-generic-password -a "$APPLE_ID" -s "$KEYCHAIN_ITEM" -w 2>/dev/null || true)
if [ -z "$password" ]; then
  echo "No app-specific password in the keychain yet. Run this once, then try again:"
  echo "  security add-generic-password -U -a \"$APPLE_ID\" -s \"$KEYCHAIN_ITEM\" -w \"xxxx-xxxx-xxxx-xxxx\""
  exit 1
fi

if [ "$USE_TRANSPORTER" = 1 ] && [ -x "$TRANSPORTER" ]; then
  echo "==> Delivering with Transporter..."
  "$TRANSPORTER" -m upload -assetFile "$ipa" -u "$APPLE_ID" -p "$password" -v informational
else
  echo "==> Delivering to App Store Connect with altool..."
  xcrun altool --upload-app -t ios -f "$ipa" -u "$APPLE_ID" -p "$password"
fi

echo ""
echo "==> Delivered ${name} (${build}). Apple emails you when it's ready in TestFlight (10-30 min)."
echo "    Save the new build number to your branch:"
echo "    git add pubspec.yaml && git commit -m \"Build ${build}\" && git push"

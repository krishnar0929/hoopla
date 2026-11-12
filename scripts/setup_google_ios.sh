#!/bin/bash
# One-time: lets "Continue with Google" work on iPhone.
# Copies the Google client ID from ios/Runner/GoogleService-Info.plist into ios/Runner/Info.plist.
set -euo pipefail
cd "$(dirname "$0")/.."

GSI=ios/Runner/GoogleService-Info.plist
PLIST=ios/Runner/Info.plist
PB=/usr/libexec/PlistBuddy

client=$($PB -c "Print :CLIENT_ID" "$GSI" 2>/dev/null || true)
reversed=$($PB -c "Print :REVERSED_CLIENT_ID" "$GSI" 2>/dev/null || true)
if [ -z "$client" ] || [ -z "$reversed" ]; then
  echo "GoogleService-Info.plist has no Google client ID yet. Do this first:"
  echo "  1. Firebase console > Authentication > Sign-in method > enable Google"
  echo "  2. flutterfire configure --project=hoopla-894ca   (pick android, ios, web; answer yes to overwrite)"
  echo "  3. Run this script again."
  exit 1
fi

$PB -c "Delete :GIDClientID" "$PLIST" 2>/dev/null || true
$PB -c "Add :GIDClientID string $client" "$PLIST"
$PB -c "Delete :CFBundleURLTypes" "$PLIST" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0 dict" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$PLIST"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $reversed" "$PLIST"
echo "Google sign-in is set up for iPhone."

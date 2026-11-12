#!/bin/bash
# One-time, after you add the "HooplaShare" Share Extension target in Xcode:
# copies Hoopla's share code and settings into it.
set -euo pipefail
cd "$(dirname "$0")/.."

TARGET_DIR=ios/HooplaShare
if [ ! -d "$TARGET_DIR" ]; then
  echo "ios/HooplaShare not found. In Xcode: File > New > Target > Share Extension, name it HooplaShare."
  exit 1
fi
cp ios/share_extension/ShareViewController.swift "$TARGET_DIR/ShareViewController.swift"
cp ios/share_extension/Info.plist "$TARGET_DIR/Info.plist"
echo "Share to Hoopla is set up. Finish the remaining Xcode steps (App Groups, version, minimum iOS)."

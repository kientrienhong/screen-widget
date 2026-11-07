#!/usr/bin/env bash
# One-time setup on a Mac: generates the macOS/Windows runner folders with
# `flutter create` (your lib/ and assets/ are left untouched), then applies the
# native tweaks this app needs.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed. See https://docs.flutter.dev/get-started/install/macos"
  exit 1
fi

flutter config --enable-macos-desktop >/dev/null
flutter create --platforms=macos,windows --project-name screen_widget --org com.harley .

# Transparent window + window_manager hook.
cp tool/native/macos/MainFlutterWindow.swift macos/Runner/MainFlutterWindow.swift

# Pop-out windows start a second copy of the app and "Launch at login" writes a
# LaunchAgent, so the app runs outside the App Sandbox.
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  /usr/libexec/PlistBuddy -c "Set :com.apple.security.app-sandbox false" "$f" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool false" "$f"
done

bash tool/fix_macos_target.sh

flutter pub get
echo
echo "Done. Run the app with:  flutter run -d macos"
echo "Build a release .app with:  flutter build macos"

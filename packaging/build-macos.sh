#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build macos --release
app="build/macos/Build/Products/Release/oyudent_pos.app"
mkdir -p build/installers
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
ditto "$app" "$stage/Oyudent POS.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
output="build/installers/Oyudent-POS-$version.pkg"
components=$(mktemp)
trap 'rm -rf "$stage"; rm -f "$components"' EXIT
pkgbuild --analyze --root "$stage" "$components"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$components"
pkgbuild --root "$stage" --component-plist "$components" --install-location /Applications \
  --identifier com.oyudent.pos.installer --version "$version" "$output"
pkgutil --payload-files "$output" | awk '/Oyudent POS.app\/Contents\/MacOS\/oyudent_pos$/ {found=1} END {exit !found}'
echo "Installer ready: $output"

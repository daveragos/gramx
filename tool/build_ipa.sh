#!/usr/bin/env bash
#
# Builds an unsigned gramX IPA for sideloading into build/ios/ipa.
#
# AltStore, SideStore and Sideloadly sign the app with the installer's own
# Apple ID, so the IPA ships unsigned and needs no Apple team. The share
# extension is left out: those tools count an extension against the three
# apps a free Apple ID can have installed, so gramX would take two of them.
# Extra arguments go to flutter build, for example --build-number.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

[ -d ios/Frameworks/tdjson.xcframework ] || {
  echo "ios/Frameworks/tdjson.xcframework is missing; run tool/build_tdlib_ios.sh first" >&2
  exit 1
}

flutter build ios --release --no-codesign "$@"

# Xcode's product for the Release configuration. Flutter's copy in
# build/ios/iphoneos holds whichever mode was built last.
app="build/ios/Release-iphoneos/Runner.app"
version="$(plutil -extract CFBundleShortVersionString raw "$app/Info.plist")"
out="build/ios/ipa/gramx-$version.ipa"

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/Payload"
ditto "$app" "$stage/Payload/Runner.app"
rm -rf "$stage/Payload/Runner.app/PlugIns"

mkdir -p "$(dirname "$out")"
rm -f "$out"
(cd "$stage" && zip -qry "$root/$out" Payload)

shasum -a 256 "$out"

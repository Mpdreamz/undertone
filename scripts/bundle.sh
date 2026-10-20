#!/usr/bin/env bash
# Assemble build/Undertone.app from the SwiftPM products: the app binary, the `undertone` command line tool (Contents/Helpers,
# linked onto the PATH by the cask), Sparkle (Contents/Frameworks, the updater), Info.plist, then an ad-hoc signature.
# It packages what `swift build` made; it does not build (mise run build does both).
#
#   scripts/bundle.sh debug|release
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
config="${1:-debug}"
products="$(cd "$root" && swift build -c "$config" --show-bin-path)"
app="${BUILD_DIR:-$root/build}/Undertone.app"
# UNDERTONE_VERSION is set by the release workflow from the release's tag; local builds say dev. The build number is the
# commit count, which only grows on main (pull requests are squash-merged): the updater compares it to tell a newer
# release. UndertoneCommit names the commit, so any build can be traced back.
version="${UNDERTONE_VERSION:-0.1.0-dev}"
build="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)"
commit="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo dev)"

mkdir -p "$app/Contents/MacOS" "$app/Contents/Helpers" "$app/Contents/Resources" "$app/Contents/Frameworks"
cp "$products/UndertoneApp" "$app/Contents/MacOS/Undertone"
cp "$products/undertone" "$app/Contents/Helpers/undertone"
# Sparkle, symlinks kept. Its XPC services are for sandboxed apps; Undertone is not sandboxed, so they go.
rm -rf "$app/Contents/Frameworks/Sparkle.framework"
ditto "$products/Sparkle.framework" "$app/Contents/Frameworks/Sparkle.framework"
rm -rf "$app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
  "$app/Contents/Frameworks/Sparkle.framework/XPCServices"
if ! otool -l "$app/Contents/MacOS/Undertone" | grep -q "@executable_path/../Frameworks"; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$app/Contents/MacOS/Undertone"
fi
sed -e "s/__VERSION__/$version/g" -e "s/__BUILD__/$build/g" -e "s/__COMMIT__/$commit/g" \
  "$root/Resources/Info.plist" >"$app/Contents/Info.plist"
# The icon Finder and System Settings show (drawn by `mise run shots`, and committed; missing only the first time).
if [ -f "$root/Resources/AppIcon.icns" ]; then
  cp "$root/Resources/AppIcon.icns" "$app/Contents/Resources/AppIcon.icns"
else
  echo "bundle: no Resources/AppIcon.icns yet (mise run shots draws it)" >&2
fi
# The screen saver (Contents/Resources/Undertone.saver), which the app copies to ~/Library/Screen Savers: the
# library SwiftPM built, its Info.plist, and a thumbnail drawn by the renderer for System Settings.
saver="$app/Contents/Resources/Undertone.saver"
rm -rf "$saver"
mkdir -p "$saver/Contents/MacOS" "$saver/Contents/Resources"
cp "$products/libUndertoneSaver.dylib" "$saver/Contents/MacOS/Undertone"
sed -e "s/__VERSION__/$version/g" -e "s/__BUILD__/$build/g" "$root/Resources/Saver/Info.plist" \
  >"$saver/Contents/Info.plist"
"$products/undertone" render --style aurora --tonality aurora --seed 19 --size 180x116 --scale 1 \
  -o "$saver/Contents/Resources/thumbnail.png"
"$products/undertone" render --style aurora --tonality aurora --seed 19 --size 360x232 --scale 2 \
  -o "$saver/Contents/Resources/thumbnail@2x.png"
codesign --force --sign - "$app/Contents/Helpers/undertone"
codesign --force --sign - "$saver"
codesign --force --deep --sign - "$app/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$app"
# The helper must be the command line tool, never the app: hotkey daemons run it on every key press.
if ! "$app/Contents/Helpers/undertone" --help 2>/dev/null | grep -q '^usage: undertone'; then
  echo "bundle: Contents/Helpers/undertone is not the undertone command line tool" >&2
  exit 1
fi
echo "bundle: $app ($version, build $build, $commit)"

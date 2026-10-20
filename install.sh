#!/bin/sh
# Install or update Undertone: curl -fsSL https://raw.githubusercontent.com/mpdreamz/undertone/main/install.sh | sh
#
# Downloads the latest release (or UNDERTONE_VERSION=0.1.0), checks its sha256, and puts Undertone.app in /Applications, or
# ~/Applications when /Applications is not writable (UNDERTONE_APP_DIR overrides both; UNDERTONE_DOWNLOAD_BASE downloads from
# elsewhere). Downloaded with curl, the app
# carries no quarantine flag, so it opens without a Gatekeeper prompt.
set -eu

repo="mpdreamz/undertone"
asset="Undertone-arm64.zip"

fail() {
  echo "undertone: $*" >&2
  exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "Undertone is a macOS app."
[ "$(uname -m)" = "arm64" ] || fail "Undertone builds for Apple Silicon only, for now."

if [ -n "${UNDERTONE_DOWNLOAD_BASE:-}" ]; then
  # A mirror, or a local server when testing this script.
  base="$UNDERTONE_DOWNLOAD_BASE"
elif [ -n "${UNDERTONE_VERSION:-}" ]; then
  base="https://github.com/$repo/releases/download/v${UNDERTONE_VERSION#v}"
else
  base="https://github.com/$repo/releases/latest/download"
fi

if [ -n "${UNDERTONE_APP_DIR:-}" ]; then
  dir="$UNDERTONE_APP_DIR"
elif [ -w /Applications ]; then
  dir="/Applications"
else
  dir="$HOME/Applications"
fi
mkdir -p "$dir"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "undertone: downloading $base/$asset"
curl -fsSL -o "$tmp/$asset" "$base/$asset" || fail "download failed (is there a release yet?)"
curl -fsSL -o "$tmp/$asset.sha256" "$base/$asset.sha256" || fail "checksum download failed"
(cd "$tmp" && shasum -a 256 -c "$asset.sha256" >/dev/null) || fail "checksum does not match; nothing installed"

ditto -x -k "$tmp/$asset" "$tmp/app"
[ -x "$tmp/app/Undertone.app/Contents/MacOS/Undertone" ] || fail "the download holds no Undertone.app; nothing installed"

if pgrep -xq Undertone; then
  echo "undertone: Undertone is running; quit it to finish, or it keeps the old version until it restarts."
fi
rm -rf "$dir/Undertone.app"
mv "$tmp/app/Undertone.app" "$dir/Undertone.app"

version="$(plutil -extract CFBundleShortVersionString raw "$dir/Undertone.app/Contents/Info.plist" 2>/dev/null || echo "?")"
echo "undertone: Undertone $version is in $dir. Open it with: open -a Undertone"

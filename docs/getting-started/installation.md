---
description: Install Undertone on macOS with Homebrew or one line, or build it from source.
---

# Installation

Undertone is a macOS app for Apple Silicon (macOS 15 or later).

```sh
brew install --cask mpdreamz/tap/undertone
```

or, without Homebrew:

```sh
curl -fsSL https://raw.githubusercontent.com/mpdreamz/undertone/main/install.sh | sh
```

Homebrew also puts the [`undertone` command](../reference/cli.md) on your `PATH`; `brew uninstall --zap undertone`
removes its settings and pictures too. The install script downloads the latest release, checks its sha256, and puts
`Undertone.app` in `/Applications` (or `~/Applications` when `/Applications` is not writable). Run it again to update.
`UNDERTONE_VERSION=0.1.0` installs a given version and `UNDERTONE_APP_DIR` another folder.

Or download [`Undertone-arm64.zip`](https://github.com/mpdreamz/undertone/releases/latest/download/Undertone-arm64.zip),
unzip it, and move `Undertone.app` to Applications. Releases are signed with a Developer ID and notarized by Apple, so
it opens without a warning.

Open it once: a half-filled circle appears in the menu bar, and the desktop changes. **Open at Login** in its menu
keeps it running from then on, which is what keeps the picture set.

## From source

- Xcode, selected with `xcode-select`.
- [mise](https://mise.jdx.dev), which brings in swiftformat and swiftlint.

```sh
git clone https://github.com/mpdreamz/undertone.git
cd undertone
mise run bundle     # release build: build/Undertone.app
open build/Undertone.app
```

# Undertone

A macOS menu bar app that hides the notch and the screen's borders in black, under beautiful generated backgrounds
that follow your light or dark theme and change on a schedule.

- Hide the notch with a black menu bar strip and round the corners below it, so windows tiled into a corner meet black.
- Eleven styles (mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs) and eight tonalities
  (ember, tide, aurora, dusk, moss, glacier, citrus, mono); lock either or let it pick.
- Seven effects over any picture: dither, halftone, reeded glass, bloom, a light leak, paper and posterize.
- Lock screen motion: your picture drifts while the Mac is locked and settles onto the desktop as you unlock.
- A new picture every hour, 3 hours or day, on login and wake, or from a hotkey; a picture per space; grain; a title.
- Settings in `~/.config/undertone/config.toml`, for your dotfiles; edits apply on their own.
- Updates itself.

**[mpdreamz.github.io/undertone](https://mpdreamz.github.io/undertone/)** has the docs and every style and tonality.

![Undertone's aurora style on a MacBook, the notch hidden in a black menu bar](docs/images/shots/landing/hero.jpg)

## Install

```sh
brew install --cask mpdreamz/tap/undertone
```

or `curl -fsSL https://raw.githubusercontent.com/mpdreamz/undertone/main/install.sh | sh`. Apple Silicon, macOS 15+.

## Build

```sh
mise run dev     # debug build, then open build/Undertone.app
mise run test
mise run shots   # redraw every image in docs/images
mise run docs    # build the docs and landing page as CI does, served on :4000
```

MIT licensed.

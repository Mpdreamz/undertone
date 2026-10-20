# Undertone

A macOS menu bar app that draws your desktop picture: soft gradients and shapes in a tonality that follows light or
dark mode, a different one per space if you like, and puts it back when something else resets it.

- Eleven styles (mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs) and eight tonalities
  (ember, tide, aurora, dusk, moss, glacier, citrus, mono); lock either or let it pick.
- Hide the notch with a black menu bar strip, round the corners below it, add grain, or a centred title.
- Updates itself.

Work in progress: see [PLAN.md](PLAN.md).

## Install

```sh
brew install --cask mpdreamz/tap/undertone
```

or `curl -fsSL https://raw.githubusercontent.com/mpdreamz/undertone/main/install.sh | sh`. Apple Silicon, macOS 15+.

## Build

```sh
mise run dev     # debug build, then open build/Undertone.app
mise run test
```

MIT licensed.

# Undertone

A macOS menu bar app that draws your desktop picture: soft gradients and shapes in a tonality that follows light or
dark mode, a different one per space if you like, and puts it back when something else resets it.

- Eleven styles (mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs) and eight tonalities
  (ember, tide, aurora, dusk, moss, glacier, citrus, mono); lock either or let it pick.
- Hide the notch with a black menu bar strip, round the corners below it, add grain, or a centred title.
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

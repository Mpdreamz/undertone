---
description: Undertone's settings as a file you can keep in your dotfiles.
---

# Configuration

Undertone keeps its settings in a plain text file, `~/.config/undertone/config.toml` (under `$XDG_CONFIG_HOME` when
that is set), so you can keep them in your dotfiles and have every Mac look the same.

- **Edits apply on their own.** Undertone notices a change to the file within a second, whether you edit it, a
  dotfiles manager (chezmoi, stow, yadm) writes it, or a `git pull` brings it in. No restart.
- **Settings write it.** A change in Settings or the menu writes the whole file again, in the layout
  below. Comments of your own are lost when that happens; keep notes elsewhere, or make your changes in the file.
- **A link stays a link.** If `config.toml` is a symbolic link (stow, or chezmoi in symlink mode), Undertone writes to
  the file it points at.
- **Only settings.** What is showing now, when it last shuffled, and **Pause** stay in Undertone's own preferences, so
  a shuffle or a pause never changes the file.
- **No file, no problem.** Without one Undertone uses the defaults, and writes the file the first time you change a
  setting. **Open Config File** in the menu writes it and opens it.
- **Mistakes stay small.** A key or value Undertone cannot use falls back to that setting's default and the rest of the
  file still applies; the menu shows the first problem, and `undertone config --check` lists them all, by line.

## The file

Every setting, at its default (`undertone config --defaults` prints this):

```toml
# Undertone's settings. Undertone reads this file when it changes, and writes it (in this layout, without
# comments of your own) when you change a setting from its settings window or menu.
# https://mpdreamz.github.io/undertone/reference/configuration/

[style]
mode = "shuffle"  # shuffle (a new style each shuffle) or always
always = "mesh"  # the style when mode = "always"
never = []  # left out of shuffles: mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs

[tonality]
mode = "shuffle"  # shuffle, season (suits the time of year, never mono) or always
always = "ember"  # the tonality when mode = "always"
never = []  # left out of shuffles: ember, tide, aurora, dusk, moss, glacier, citrus, mono
hemisphere = "auto"  # whose seasons: auto (from the Mac's region), north or south

# Effects go over every picture, in a fixed order: glass, halftone, vignette, bloom, posterize, paper, leak,
# dither, grain. Each has its own section; on = false turns it off and keeps its settings here.
[effects]
random = false  # one more effect on each shuffle, chosen at random
random_never = []  # left out: dither, halftone, glass, bloom, leak, paper, posterize

[effects.vignette]
on = true
strength = 1.0  # 0 to 3; 1 is the usual

[effects.grain]
on = true
amount = 0.035  # 0 to 0.2; 0.035 subtle, 0.06 strong

[effects.dither]
on = false
levels = 4  # levels per colour, 2 to 16
cell = 1.0  # points per cell, 1 to 4

[effects.halftone]
on = false
spacing = 8.0  # points between dots, 4 to 24
angle = 45.0  # degrees, 0 to 90

[effects.glass]
on = false
width = 36.0  # points per flute, 12 to 96
strength = 0.55  # how much each flute magnifies, 0 to 0.9

[effects.bloom]
on = false
threshold = 0.45  # how bright a part must be to glow, 0 to 1
strength = 0.6  # 0 to 1.5

[effects.leak]
on = false
strength = 1.0  # 0 to 2
warmth = 1.0  # 0 rose to 1 amber

[effects.paper]
on = false
strength = 1.0  # 0 to 2

[effects.posterize]
on = false
bands = 7  # bands of lightness, 3 to 16

[shuffle]
every = "never"  # never, hourly, 3h or daily
on_wake = false  # a new picture on login and wake

[screen]
spaces = "same"  # same (one picture on every space) or different
hide_notch = false  # a black menu bar strip on displays with a notch
round_corners = false  # black corners, curved like macOS's windows

[title]
show = false
title = "{computer}"  # {computer}, {user}, {os} and {host} are filled in
subtitle = "{user} · macOS {os}"

[motion]
lock_screen = false  # needs Undertone chosen as the screen saver
speed = "normal"  # calm, normal or lively
movement = "normal"  # subtle, normal or strong
settle = 2.5  # seconds the slow-down on unlock takes, 1 to 5
easing = "ease-out"  # glide, ease-out or spring
```

The file is a small part of [TOML](https://toml.io): sections, `key = value`, text in double quotes, numbers,
`true` and `false`, and `#` comments. A file needs only the keys you want to change.

## From the command line

| | |
|---|---|
| `undertone config` | Where the file is. |
| `undertone config --defaults` | A file with every setting at its default, to start from. |
| `undertone config --check [file]` | What Undertone cannot use in the file (or in `file`), by line; exits with 1 when there is anything, for a dotfiles repository's checks. |

Older settings move over on their own: from Undertone 0.3's preferences into the file, and a file in Undertone 0.4's
layout (with a `[picture]` section) is read and written again in this one. A locked style or tonality becomes
`mode = "always"`, random becomes shuffling among all, grain becomes `[effects.grain]`, and a chosen effect is turned
on.

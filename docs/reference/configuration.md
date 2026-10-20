---
description: Undertone's settings as a file you can keep in your dotfiles.
---

# Configuration

Undertone keeps its settings in a plain text file, `~/.config/undertone/config.toml` (under `$XDG_CONFIG_HOME` when
that is set), so you can keep them in your dotfiles and have every Mac look the same.

- **Edits apply on their own.** Undertone notices a change to the file within a second, whether you edit it, a
  dotfiles manager (chezmoi, stow, yadm) writes it, or a `git pull` brings it in. No restart.
- **The menu writes it.** A change from the menu or the settings window writes the whole file again, in the layout
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
# comments of your own) when you change a setting from its menu or settings window.
# https://mpdreamz.github.io/undertone/reference/configuration/

[picture]
style = "random"  # random, or mesh, flow, waves, orbs, rings, dunes, contour, silk, aurora, bauhaus, blobs
tonality = "random"  # random, or ember, tide, aurora, dusk, moss, glacier, citrus, mono
effect = "none"  # none, random, or dither, halftone, glass, bloom, leak, paper, posterize
spaces = "different"  # different (a picture per space) or same
grain = 0.035  # 0 for none, 0.035 subtle, 0.06 strong

[shuffle]
every = "never"  # never, hourly, 3h or daily
on_wake = false  # a new picture on login and wake

[screen]
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

Settings from before the file existed (Undertone 0.3 and earlier) are moved into it the first time a newer Undertone
starts.

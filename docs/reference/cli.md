---
description: The undertone command.
---

# Command line

Homebrew links `undertone` onto your `PATH`; it is also at `Undertone.app/Contents/Helpers/undertone`. It starts in
milliseconds and needs no permission.

## undertone shuffle

A new picture now, as **Shuffle** in the menu. Undertone must be running. For a hotkey, with skhd:

```
lcmd + alt - w : undertone shuffle
```

## undertone render

Draws one picture to a file, without the app and without touching the desktop:

```sh
undertone render --style silk --tonality dusk --appearance light --seed 9 -o silk.png
```

| Option | Default | |
|---|---|---|
| `--style` | `mesh` | See `undertone styles`. |
| `--tonality` | `ember` | See `undertone tonalities`. |
| `--appearance` | `dark` | `dark` or `light`. |
| `--seed` | `1` | Any whole number; the same seed draws the same picture. |
| `--grain` | `0.035` | `0` for none. |
| `--vignette` | `1` | `0` for none. |
| `--effect` | none | Turns an effect on at its defaults; give it more than once for more. See `undertone effects`. |
| `--size` | `3024x1964` | In pixels (a 14-inch MacBook Pro). |
| `--scale` | `2` | Pixels to a point: grain, lines and text follow points. |
| `--strip` | `0` | A black strip across the top, in points (37 is a notched MacBook's menu bar). |
| `--corners` | `0` | Rounded corners below the strip, in points. |
| `--title`, `--subtitle` | none | Centred text. |
| `-o` | required | The file; `.jpg` writes a JPEG, anything else a PNG. |

Every image in these docs was drawn this way, or by the app from the same renderer.

## undertone movie

The same picture in motion, written as a movie: one seamless loop, then a settle that slows it to a stop on the still
picture. It takes every `render` option, and:

| Option | Default | |
|---|---|---|
| `--seconds` | `12` | The loop's length. |
| `--fps` | `30` | Frames per second. |
| `--settle` | `2.5` | The settle's length in seconds; `0` for none. |
| `--movement` | `1` | How far things move; `0.5` is subtle, `1.6` strong. |
| `--easing` | `easeOut` | `glide`, `easeOut` or `spring`. |
| `--codec` | `hevc` | `hevc` or `h264`. |

```sh
undertone movie --style aurora --tonality aurora --size 1920x1080 --scale 1 -o aurora.mp4
```

## undertone config

`undertone config` prints where the [config file](configuration.md) is; `--defaults` prints every setting at its
default; `--check [file]` lists what Undertone cannot use in it, by line, and exits with 1 if there is anything.

## undertone styles, undertone tonalities, undertone effects

List the names `render` takes, styles with a line on each.

## undertone --version

The version, build number and commit of the app it belongs to.

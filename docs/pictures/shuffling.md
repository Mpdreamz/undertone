---
description: How Undertone picks a new picture, by hand or on a schedule, and how to leave styles and tonalities out.
---

# Shuffling

A shuffle picks a new picture: a style, a tonality, and a new layout (its seed). Style and tonality are two
separate choices, each made on the **Picture** page of **Settings…**:

- **Shuffle:** every shuffle picks a different one from those left checked. Click a style or tonality to leave it
  out; one always stays in.
- **Always the same:** click the one to keep. Shuffles still change the layout, and anything else that shuffles.

| Style | Tonality | A shuffle changes |
|---|---|---|
| Shuffle | Shuffle | the style, the tonality and the layout |
| Always | Shuffle | the tonality and the layout: the same kind of picture in new colours |
| Shuffle | Always | the style and the layout: new shapes in the same colours |
| Always | Always | only the layout |

A shuffle never lands on what is showing, so it always looks like one. Changing these keeps the layout where it
can: setting the tonality to always *moss* recolours the picture you have rather than drawing another, and leaving
out the style showing replaces just the style.

A shuffle can also add a [random effect](effects.md#a-random-effect-on-each-shuffle), when you turn that on.

## When

- **Shuffle** in the menu or in Settings, or `undertone shuffle` from a terminal or a hotkey daemon (skhd, Raycast, a
  Shortcut).
- **Schedule** in Settings: every hour, every 3 hours or every day, counted from the last shuffle, across sleep and
  restarts; and on login and wake.

Otherwise the picture stays the same, across restarts too: what is showing is remembered.

In the [config file](../reference/configuration.md):

```toml
[style]
mode = "shuffle"
never = ["bauhaus", "contour"]

[tonality]
mode = "always"
always = "dusk"
```

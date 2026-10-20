---
description: How Undertone picks a new picture, by hand or on a schedule.
---

# Shuffling

A shuffle picks a new picture. Style and tonality are two separate choices, each **Random** or locked:

| Style | Tonality | A shuffle changes |
|---|---|---|
| Random | Random | the style, the tonality and the seed |
| Locked | Random | the tonality and the seed: the same kind of picture in new colours |
| Random | Locked | the style and the seed: new shapes in the same colours |
| Locked | Locked | only the seed: the same style and colours, laid out anew |

A random choice never lands on what is showing, so a shuffle always looks like one. Changing a lock keeps the seed:
locking the tonality to *moss* recolours the picture you have rather than drawing another.

## When

- **Shuffle** in the menu, or `undertone shuffle` from a terminal or a hotkey daemon (skhd, Raycast, a Shortcut).
- **Shuffle Automatically**: every hour, every 3 hours or every day, counted from the last shuffle, across sleep and
  restarts.
- **On Login and Wake**: a new picture each time the Mac wakes or Undertone starts.

Otherwise the picture stays the same, across restarts too: what is showing is remembered.

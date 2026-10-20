---
description: Hide the notch in a black menu bar strip, and round the screen's corners.
---

# Notch and corners

## Hide the notch

**Hide the Notch** draws a black strip across the top of the picture, as tall as the menu bar. The notch disappears
into it, and the menu bar reads as part of the bezel. It applies only to displays with a notch; an external display
keeps its full picture.

| Off | On |
|---|---|
| ![The notch over a light picture](../images/shots/overlays/notch-off.jpg) | ![The notch inside a black menu bar strip](../images/shots/overlays/notch-on.jpg) |

## Round corners

**Round Corners** makes the picture black outside a rectangle with rounded corners (below the strip, when the notch is
hidden). A window tiled flush into a corner, as tiling window managers like yabai or Aerospace do, then has its own
rounded corner against black instead of a sliver of picture.

| Off | On |
|---|---|
| ![A sliver of picture behind a window's rounded corner](../images/shots/overlays/corners-off.jpg) | ![Black behind the window's rounded corner](../images/shots/overlays/corners-on.jpg) |

The corners are drawn in the same continuous curve macOS draws windows with, at 27 points: just over the corner of a
toolbar window (Finder, Safari), the roundest kind, so every window tiled into a corner meets black. A plainer window,
with a smaller corner, covers the extra black itself. There is nothing to set.

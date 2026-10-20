---
description: Undertone's seven effects, over any style and tonality.
---

# Effects

An effect is a treatment over the whole picture, on top of any style in any tonality. Effects are off until you
choose one under **Effect** in the menu: lock one, or choose **Random** and every shuffle picks a different one. A
picture with an effect is still drawn once and reused.

Each example below is the same aurora picture, dark on the left and light on the right.

## Dither

Ordered (Bayer) dithering to four levels per channel, in cells a point across: the look of an old screen or a risograph. Grain is left off, which would blur the pattern.

| Dark | Light |
|---|---|
| ![Dither over aurora, dark](../images/shots/effects/dither-dark-1.png) | ![Dither over aurora, light](../images/shots/effects/dither-light-1.png) |

## Halftone

A grid of dots at 45°, about 8 points apart, each the colour of the picture under it and bigger the further that colour is from the base: print, up close.

| Dark | Light |
|---|---|
| ![Halftone over aurora, dark](../images/shots/effects/halftone-dark-1.jpg) | ![Halftone over aurora, light](../images/shots/effects/halftone-light-1.jpg) |

## Glass

Reeded glass in front of the picture: vertical flutes about 36 points wide, each showing a magnified slice of what is behind it, lit along one edge.

| Dark | Light |
|---|---|
| ![Glass over aurora, dark](../images/shots/effects/glass-dark-1.jpg) | ![Glass over aurora, light](../images/shots/effects/glass-light-1.jpg) |

## Bloom

On a dark picture the bright parts glow into the dark around them; on a light one, the colours soften and bleed, like a lens with a little haze.

| Dark | Light |
|---|---|
| ![Bloom over aurora, dark](../images/shots/effects/bloom-dark-1.jpg) | ![Bloom over aurora, light](../images/shots/effects/bloom-light-1.jpg) |

## Light leak

A warm film light leak from the left or right edge, at a height that changes with the picture: screened over a dark picture, a warm tint over a light one.

| Dark | Light |
|---|---|
| ![Light leak over aurora, dark](../images/shots/effects/leak-dark-1.jpg) | ![Light leak over aurora, light](../images/shots/effects/leak-light-1.jpg) |

## Paper

Mottled paper fibres and the odd speck under the colour, as if the picture were printed on handmade paper.

| Dark | Light |
|---|---|
| ![Paper over aurora, dark](../images/shots/effects/paper-dark-1.jpg) | ![Paper over aurora, light](../images/shots/effects/paper-light-1.jpg) |

## Posterize

Hard bands of lightness instead of smooth gradients, the colour kept: a screen print. Light pictures get narrower bands, so they keep their shapes.

| Dark | Light |
|---|---|
| ![Posterize over aurora, dark](../images/shots/effects/posterize-dark-1.jpg) | ![Posterize over aurora, light](../images/shots/effects/posterize-light-1.jpg) |

`undertone render --effect halftone` draws one from the command line; `undertone effects` lists them.

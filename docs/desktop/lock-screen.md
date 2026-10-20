---
description: Your picture in motion while the Mac is locked, slowing to a stop on the desktop as you unlock.
---

# Lock screen motion

Turn on **Lock screen motion** in **Settings…** and your picture comes alive while the Mac is locked: the same
style, tonality and layout, drifting slowly on a loop. When you unlock, it keeps moving over the desktop a moment
longer, slows, and stops on the still picture.

Each style moves its own way: aurora's curtains sway, waves roll, glows and spheres wander, dunes slide past each
other, silk twists, blobs merge and split, contour lines flow, and rings breathe.

## Turning it on

1. Turn on **Lock screen motion** on the **Lock Screen Motion** page of **Settings…**. Undertone installs its screen saver in `~/Library/Screen Savers` and
   starts drawing your picture in motion in the background.
2. In the dialog, choose **Open Screen Saver Settings**, and pick **Undertone** there. This happens once.

The motion plays while the screen saver runs: after the idle time you set in System Settings, or from a hot corner.
Locking straight away (⌃⌘Q, or closing the lid) shows the still lock screen.

## Timing

The **Lock Screen Motion** page of **Settings…** sets its timing:

| Setting | Options | |
|---|---|---|
| Speed | Calm, Normal, Lively | The loop's length: 20, 12 or 8 seconds. |
| Movement | Subtle, Normal, Strong | How far things move: half, the style's own, or 1.6 times as far. |
| Settle | 1 to 5 seconds | How long the slow-down on unlock takes (2.5 by default). |
| Easing | Glide, Ease Out, Spring | How it comes to rest: Glide keeps moving and fades out late; Ease Out (the default) slows at once and creeps into place; Spring swings a little past the still picture and back. |

Changing any of them draws the movies again in the background.

## What it costs

After every shuffle, light and dark switch, or change to the notch, corners or title, Undertone draws a 12-second loop
and a short settle for each display, at the display's size in points. That takes a few minutes in the background on
two cores; until it is ready the screen saver keeps playing the previous one. The movies take about 10 MB per display
and are deleted two days after they were last used.

Playing them is cheap: they are HEVC video, decoded by the Mac's video hardware.

## How it works

macOS's own moving wallpapers are drawn by the system on the lock screen, and that is not open to other apps. Undertone
gets close with what is: a screen saver that plays a movie of your picture, and, on unlock, a window just above the
desktop picture that plays the settle and then fades away. The settle always ends on the exact picture the desktop
shows.

Turning it off again stops the drawing. The screen saver stays installed until you remove it from
`~/Library/Screen Savers` or choose another one.

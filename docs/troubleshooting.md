---
description: When the desktop picture does not change, or does not stay.
---

# Troubleshooting

**The picture does not change at all.** Check that Undertone is running (the half-filled circle in the menu bar) and
that **Pause** is off. A configuration profile that locks the desktop picture wins over every app; see
[Keeping it set](desktop/keeping-it-set.md#what-it-cannot-override).

**The picture changes back after a while.** Something else sets the picture, and Undertone puts its own back within
seconds. If it does not, Undertone is not running: turn on **Open at Login**.

**A space shows the old picture for a moment.** macOS lets an app set only the space on screen, so each space gets its
new picture when you first switch to it after a shuffle. See [Spaces](desktop/spaces.md).

**There is no black strip with Hide the Notch on.** The strip is drawn only on displays with a notch.

**What is Undertone doing?** It logs to the unified log:

```sh
log stream --predicate 'subsystem == "io.github.mpdreamz.undertone"' --info
```

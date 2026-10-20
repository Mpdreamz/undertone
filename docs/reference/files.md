---
description: Where Undertone keeps its pictures and settings.
---

# Files

| Path | What |
|---|---|
| `~/Library/Application Support/Undertone/Pictures` | The pictures, as PNGs, named by a fingerprint of what they show and the display's size. A picture is drawn once and reused; one no display has shown for two days is deleted. |
| `~/Library/Application Support/Undertone/Motion` | With lock screen motion on: each display's loop and settle movies, and `motion.json` naming them for the screen saver. |
| `~/Library/Screen Savers/Undertone.saver` | The screen saver, copied from the app when lock screen motion is turned on, and updated with the app. |
| `~/Library/Application Support/Undertone/undertone.lock` | Keeps a second copy of Undertone from running. |
| `~/Library/Preferences/io.github.mpdreamz.undertone.plist` | The [settings](settings.md). |

`brew uninstall --zap undertone` removes all of them. A 4K picture with grain is about 10 MB.

---
description: Every Undertone setting and its default.
---

# Settings

Everything is set from the menu or **Settings…**, and applies straight away.

| Setting | Default | Where | |
|---|---|---|---|
| Style | Random | Menu, Settings | One of the [styles](../pictures/styles.md), or a new one on every shuffle. |
| Tonality | Random | Menu, Settings | One of the [tonalities](../pictures/tonalities.md), or a new one on every shuffle. |
| Effect | None | Menu, Settings | One of the [effects](../pictures/effects.md), or a new one on every shuffle. |
| Spaces | A picture per space | Menu, Settings | See [Spaces](../desktop/spaces.md). |
| Shuffle automatically | Never | Menu, Settings | Never, every hour, every 3 hours, every day. |
| Shuffle on login and wake | Off | Menu, Settings | |
| Grain | Subtle (0.035) | Menu, Settings | 0 to 0.08; the menu offers none, subtle and strong (0.06). |
| Hide the notch | Off | Menu, Settings | Displays with a notch only. |
| Round corners | Off | Menu, Settings | |
| Corner radius | 16 pt | Settings | 4 to 32. |
| Show a title | Off | Menu, Settings | |
| Title | `{computer}` | Settings | See [A title](../desktop/grain-and-title.md#a-title). |
| Subtitle | `{user} · macOS {os}` | Settings | |
| Lock screen motion | Off | Menu | Needs Undertone chosen as the screen saver. |
| Pause | Off | Menu | Leave the desktop alone. |
| Open at login | Off | Menu | A login item. |

The settings are stored as JSON in Undertone's defaults (`io.github.mpdreamz.undertone`, key `settings`), with the
picture showing now (`pick`) and the time of the last shuffle (`lastShuffle`). `defaults delete
io.github.mpdreamz.undertone` while Undertone is not running starts over from the defaults.

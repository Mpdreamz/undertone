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
| Show a title | Off | Menu, Settings | |
| Title | `{computer}` | Settings | See [A title](../desktop/grain-and-title.md#a-title). |
| Subtitle | `{user} · macOS {os}` | Settings | |
| Lock screen motion | Off | Menu | Needs Undertone chosen as the screen saver. |
| Motion speed | Normal | Settings | Calm (20 s loop), Normal (12 s), Lively (8 s). |
| Motion movement | Normal | Settings | Subtle, Normal, Strong. |
| Settle | 2.5 s | Settings | 1 to 5 seconds. |
| Easing | Ease Out | Settings | Glide, Ease Out, Spring. |
| Pause | Off | Menu | Leave the desktop alone. |
| Open at login | Off | Menu | A login item. |

Every setting except **Open at Login** and **Pause** is also a key in the [config file](configuration.md),
`~/.config/undertone/config.toml`, which you can edit or keep in your dotfiles. What is showing now, the time of the
last shuffle and **Pause** live in Undertone's own preferences (`io.github.mpdreamz.undertone`).

---
description: Every Undertone setting, its default, and its key in the config file.
---

# Settings

Everything is set in **Settings…** (a few also in the menu) and in the [config file](configuration.md); either applies
straight away. A new install shuffles every style and tonality, shows one picture on every space, and draws a vignette
and a subtle grain.

| Setting | Default | Settings page | Config file |
|---|---|---|---|
| Style | Shuffle among all | Picture | `[style] mode`, `always`, `never` |
| Tonality | Shuffle among all | Picture | `[tonality] mode` (shuffle, season, always), `always`, `never`, `hemisphere` |
| Vignette | On, 1 | Effects | `[effects.vignette]` |
| Grain | On, 0.035 | Effects | `[effects.grain]` |
| Dither, halftone, glass, bloom, light leak, paper, posterize | Off | Effects | `[effects.<name>]` |
| A random effect on each shuffle | Off | Effects | `[effects] random`, `random_never` |
| Shuffle | Never | Schedule | `[shuffle] every`: never, hourly, 3h, daily |
| Shuffle on login and wake | Off | Schedule | `[shuffle] on_wake` |
| Spaces | The same picture everywhere | Screen | `[screen] spaces`: same, different |
| Hide the notch | Off | Screen (and the menu) | `[screen] hide_notch` |
| Round corners | Off | Screen (and the menu) | `[screen] round_corners` |
| Title | Off; `{computer}` over `{user} · macOS {os}` | Title | `[title] show`, `title`, `subtitle` |
| Lock screen motion | Off | Lock Screen Motion | `[motion] lock_screen` |
| Motion speed, movement, settle, easing | Normal, normal, 2.5 s, ease out | Lock Screen Motion | `[motion] speed`, `movement`, `settle`, `easing` |
| Open at login | On (turned on once, when Undertone first runs) | General | not in the file |
| Pause | Off | the menu | not in the file |

What is showing now, the time of the last shuffle and **Pause** live in Undertone's own preferences
(`io.github.mpdreamz.undertone`), so a shuffle or a pause never changes the config file.

---
description: How Undertone updates itself.
---

# Updates

Undertone updates itself. Once a day it reads the list of releases on GitHub (an appcast attached to the latest
release); when there is a newer version it downloads it and installs it when Undertone quits. **Check for Updates…**
in the menu looks right away and shows what changed.

An update is installed only if all of these hold:

- the appcast itself is signed with Undertone's update key;
- the download is signed with the same key, checked before it is unpacked;
- the app inside is signed with Undertone's Developer ID and notarized by Apple.

Undertone uses [Sparkle](https://sparkle-project.org) for this, as most Mac apps outside the App Store do. Builds you
make yourself do not update.

## Homebrew

The cask says Undertone updates itself, so `brew upgrade` leaves it alone; `brew upgrade --greedy undertone` still
upgrades it.

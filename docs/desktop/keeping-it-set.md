---
description: How Undertone notices that something else changed the desktop picture, and what it cannot override.
---

# Keeping it set

Undertone was made for a managed Mac whose desktop picture kept resetting to the default. While it runs, it checks
that every display shows its picture:

- when you switch spaces, wake the Mac, switch back to your user, or connect or rearrange displays;
- when the appearance changes between light and dark (which also draws the other half of the tonality);
- when something writes to the system's own record of the desktop pictures
  (`~/Library/Application Support/com.apple.wallpaper`), a moment after the write;
- and every 30 seconds, whatever else happened.

A display showing anything else gets Undertone's picture back. A picture already drawn is not drawn again, so a check
costs next to nothing. In practice a reset is undone within a few seconds.

## What it cannot override

A configuration profile can *lock* the desktop picture (the `com.apple.desktop` payload with
`override-picture-path`). Then macOS refuses every app's change, Undertone's too. To see whether a profile manages it:

```sh
profiles show -type configuration | grep -i -A3 desktop
```

A profile, a script or an agent that only *sets* the picture now and then is exactly what Undertone undoes.

## Leaving the desktop alone

**Pause** stops Undertone setting or putting back anything, until you turn it off; so does quitting it. Choosing a
picture in System Settings while Undertone runs lasts only until its next check.

# Plan

Undertone draws the desktop picture itself and puts it back when something else changes it. It started on a
company-managed Mac whose wallpaper keeps resetting to the default; what it draws is a gradient or a set of shapes in a
tonality that follows the system's light or dark appearance.

## Milestones

1. **Skeleton and release.** SwiftPM package, `build/Undertone.app`, the release pipeline (Developer ID, notarization,
   Sparkle appcast, Homebrew cask), a placeholder status item and the `undertone` command line tool. Shipped as v0.1.0
   to prove the pipeline.
2. **Renderer.** `UndertoneCore` draws a `Recipe` (style, tonality, appearance, seed, overlays) into pixels at a
   display's size, in Swift on the CPU, every row in parallel: the eleven styles and eight tonalities of
   `prototype/gen.py`, colours mixed in OkLab. Pure and deterministic, so tests can pin down what a recipe draws.
3. **Apply and guard.** Write the picture to Application Support and set it with
   `NSWorkspace.setDesktopImageURL(_:for:options:)`; check it again on a space switch, wake, display change,
   appearance change, a change to the wallpaper store (`~/Library/Application Support/com.apple.wallpaper`) and a slow
   timer, and set it again when it is not ours.
4. **Spaces and displays.** The system's call sets the space on screen, so each space gets its picture when it is
   switched to. One seed for every space, or one per space; the tonality is always shared.
5. **Overlays.** Hide the notch (a black strip the menu bar's height, from `NSScreen.safeAreaInsets`), rounded corners
   below it, grain, and a centred title and subtitle with placeholders (computer name, user, macOS version), off by
   default.
6. **Choosing and settings.** Style and tonality are each locked or random; a new pick at login, on wake, every few
   hours, or on "Shuffle" (menu, or `undertone shuffle`). A settings window with a preview, launch at login, updates.

## State

Milestones 1 and 2 are merged; 3 to 6 are in the desktop pull request: the menu (shuffle, style and tonality each
random or locked, spaces, automatic shuffles, grain, notch, corners, title, pause), a settings window for the title's
text, the corner radius and the grain, and `undertone shuffle`. Pictures live in
`~/Library/Application Support/Undertone/Pictures`, named by a fingerprint of what they show, and go two days after
they were last set.

## Styles and tonalities

Styles: `mesh` (soft glows over a dark base), `flow` (domain-warped noise through the palette), `waves` (layered
ribbons with a lit rim), `orbs` (lit spheres), `rings` (bands round an off-screen centre), `dunes` (stacked hills),
`contour` (topographic lines), `silk` (twisting ribbons with a sheen), `aurora` (curtains of light), `bauhaus` (a grid
of quarter and half circles), `blobs` (metaballs).

Tonalities, each with a dark and a light set of five colours (base, deep, two accents, a shadow): `ember`, `tide`,
`aurora`, `dusk`, `moss`, `glacier`, `citrus`, `mono`.

## What macOS offers

- `NSWorkspace.setDesktopImageURL(_:for:options:)` sets the picture of the space currently shown on that screen;
  `desktopImageURL(for:)` reads it back. There is no public call for another space.
- `NSWorkspace.activeSpaceDidChangeNotification`, `didWakeNotification`, `NSApplication.didChangeScreenParameters`,
  and `effectiveAppearance` (KVO) are the moments to look again.
- A management profile with a locked desktop picture (`com.apple.desktop` payload, `override-picture-path`) cannot be
  beaten by any app; one that only resets the picture now and then can.

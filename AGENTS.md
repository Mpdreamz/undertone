# Agents working on Undertone

Undertone is a menu bar app that draws the desktop picture (gradients and shapes in a tonality that follows light or
dark mode), hides the notch and the screen's corners in black, and keeps its picture set. Read `PLAN.md` first.

## Principles

- **Drawing in `UndertoneCore`, AppKit in `UndertoneApp`.** A `Recipe` in, pixels out: the renderer is pure and
  deterministic (the same recipe draws the same picture), so tests check it without a window server. The app decides
  which recipe each screen and space gets, writes the file and sets it.
- **`prototype/gen.py` is the reference.** A style that looks different from the prototype's is a bug unless the
  change is meant; change both.
- **No permissions.** Setting the desktop picture needs none; adding one (Accessibility, Screen Recording, Automation)
  needs the owner's say.
- **Never block the main actor.** Rendering runs off it.
- **Never steal focus.** Undertone activates itself only for its settings window, its alerts and Sparkle's window.

## Working

- `mise run test` and `mise run lint` before committing; `mise run fmt` fixes formatting.
- `mise run dev` builds and launches `build/Undertone.app`.
- Branch names set the release-drafter label: `feature/`, `fix/`, `docs/`, `chore/`, `ci/`. Pull requests are
  squash-merged (the build number is main's commit count).

## Docs

`docs/` is a docs-builder site with `docs/undertone-landing.html` over its home page, published to GitHub Pages
(`https://mpdreamz.github.io/undertone/`, so links carry the `/undertone/` prefix) by `.github/workflows/docs.yml` on
every merge. Every image in `docs/images` is drawn by Undertone from a fixed recipe: change a style, a tonality or an
overlay and run `mise run shots`, never a screenshot of a real desktop. Docs claim only what is built.

## Releasing

Merges to main keep a draft release up to date. `gh workflow run release` builds main, signs it with the Developer ID,
notarizes and staples it, writes a signed appcast for Sparkle, publishes the draft and bumps
`mpdreamz/homebrew-tap`. Secrets are stored with `scripts/release-secrets.sh` (run by the owner, never by an agent);
the Sparkle private key lives in the owner's keychain under the account `undertone` and is never handled here.

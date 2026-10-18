---
name: live-debug
description: Drive or inspect the running parasite Electron app over CDP — evaluate script against the live game, read the `window.__*` debug hooks, take a screenshot, smoke-test a click, or measure render performance. Use whenever a question is about what the game ACTUALLY built or is doing right now rather than what the source says, and before any A/B or timing measurement. Loads `docs/debug-surface.md`.
---

# Driving the running game

Full hook reference, every gotcha and the measurement rules: **`docs/debug-surface.md`** — read it
before the first non-trivial eval, and always before quoting a timing number.

## Session start, every time

1. `mcp__chrome-devtools__list_pages` → match `file:` + `app.html` (DevTools shows up too). A first
   MCP call may transient-fail; retry once.
2. **`select_page({ pageId, bringToFront: true })` — always, as the first call.** `bringToFront`
   defaults OFF. A minimised or buried window stops compositing, so `evaluate_script` and
   `take_screenshot` hang for the MCP's full 180s timeout while `list_pages` still answers. Browser
   call works + page call hangs = hidden window.
3. `make reload` after a build; the renderer does not hot-reload.

## What you can reach without adding anything

- `window.parasiteHx` — the Haxe class registry, **statics only**. `parasiteHx['game.Game'].inst` is
  the live `Game`; `game.scene.view3d` is the live `render.View` (`.scene`, `.camera`, `.renderer`,
  `.composer`, `.rig`, `.perf`) — a complete render A/B harness with nothing added to shipped code.
- `window.__check`, `__occ`, `__dbg` (street-debug only), `__grime`, `__wild()`, `__facility()`,
  `__progs()`, `window.host`. What each returns and why it returns it: the doc.
- Pure functions and static state run headless — `CityGen.generate(seed)`, `SewerModel.demo()`,
  `VisionMask` — so a claim can be tested without loading a save.

Two duties: `area.getObjects()` is a Haxe ITERATOR, never `for...of`; and **restore everything you
touched** (materials, `visible`, `castShadow`, render scale, `DEBUG_PERF`, any monkey-patched static).

## Before quoting any number

The game window must be **focused and in the foreground** — backgrounded it throttles to ~1fps, the
timer query spans the idle gap, `GPU` reads ~1015ms and an A/B comes out inverted. Check the topbar
fps first. Pin the camera (`Tools.freeCam.lookFrom`), interleave A/B/A/B, take the **median**, warm
the shader permutations, never compare across sessions. The rest: `docs/debug-surface.md` and
`docs/3d-render.md`.

## Adding a hook

**Ask first.** A `window.__*` hook, a debug key, a HUD readout or a trace is permanent
instrumentation in shipped game code. Say what it would expose and why, and propose it as PERMANENT
and documented (a bullet in `docs/debug-surface.md`), never as a throwaway. Reading the existing
hooks needs no ask.

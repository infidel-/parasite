# Repository Guidelines

## Build targets (root Makefile)
- `make` / `make game-debug`: `cd src && make electron`
- `make testmod`: `cd examples/testmod/ && make`
- `make main`: `cd electron && make`

## Where the rest of it lives

This file holds only what has to fire when nobody asked for it: build commands, project rules, code
style, and the guards below. Everything else is a doc, pulled in when the task starts.

| doing this | read this first |
|---|---|
| any 3D render change | [`docs/3d-render.md`](docs/3d-render.md) — the index; append [`docs/3d-changes.md`](docs/3d-changes.md) after |
| changing how ANY area is generated or laid out | [`docs/area-gen.md`](docs/area-gen.md) — the block tree; **run `make gen` instead of launching the game** |
| inspecting or driving the running game over CDP | [`docs/debug-surface.md`](docs/debug-surface.md) — skill `live-debug` |
| a new prop, texture or decal; "we need new images" | [`docs/3d-models.md`](docs/3d-models.md), [`docs/3d-textures.md`](docs/3d-textures.md) — skill `3d-art` |
| HAND-MODELLING one in Blender (the brief is a number) over the `blender` MCP | [`docs/3d-models.md`](docs/3d-models.md) § Hand-modelling in Blender over MCP — skill `3d-art` |
| BUILDING that thing out of quads instead of a glb — a fitting, a box, a run | [`docs/3d-geometry.md`](docs/3d-geometry.md) — the per-FACE texture split, the 0..1 aspect lock, wiring and warm |
| dressing or enhancing a 3D area | skill `3d-enhance` |

**A NEW FINDING GOES IN THE DOC, NOT HERE.** This file went 1.7 KB → 61 KB in six months and 75% of
that was two sections that are now docs. One line here when it must fire unprompted, the numbers and
the war story there. A rule nobody can act on without opening the doc anyway belongs in the doc.

## Project rules

- NEVER detach HEAD! NEVER!
- NEVER sweep stray .md files (review reports, notes, scratch docs) into commits unless directly asked; check `git status` for them before `git add -A`, or stage explicit paths.
- ALWAYS respond in English!
- ALWAYS run tests at the end of each task: cd src/ && make
- When changing persisted game data structures, ALWAYS verify Saver/Loader savegame compatibility (both serialization and load behavior, including old saves when relevant). Note that you should ask whether it is needed when planning (there might not have been a release yet)
- When modifying AI logic, see if additional ai traces are needed
- **NEVER conclude the game is not running from a WSL-side port check.** The Electron app runs on the WINDOWS HOST and its CDP port is reached across the WSL boundary (`172.18.208.1:9300`), so `ss`/`lsof`/`netstat` inside WSL see nothing however open the game is. The ONLY test is `mcp__chrome-devtools__list_pages` or `node probe.mjs`. See [`docs/debug-surface.md`](docs/debug-surface.md).
- **PARK THE GAME WINDOW WHILE ITERATING: `host.restore()` before driving it, `host.minimize()` when done, every time and without being asked.** It is the user's foreground app, not a workbench to leave open. Minimised costs nothing — evals and screenshots both still work and return current frames; only TIMING is invalid down there. `bringToFront` does NOT un-minimise. See [`docs/debug-surface.md`](docs/debug-surface.md).

## Code style (Haxe)

- Use two-space indentation, brace-on-newline, and avoid trailing whitespace. in general, follow the existing code style of the file and repository.
- Lines without text should NEVER have whitespace.
- When adding new functions, always add short comment with summary of what it does on top, first letter should be lowercase
- When generating code, comment each large block with a short summary, first letter should be lowercase
- NEVER write var x = new Array<...>(), just write var x = []
- When writing if statements with multiple conditions, format each condition on a new line for better readability
- Multi-field object literals (options args, typedef instances, 3+ fields) are ALWAYS multi-line: `{` opens the block, each field on its own line, trailing comma, `});`/`};` closes. Never pack fields several-per-line.
- REFACTOR OVERLY LARGE ARG LISTS into a single options `typedef`. Past ~5 positional args — and ALWAYS when adding one to a signature already at that size — stop and convert instead of appending: a call site of bare `0`s and `true`s is unreadable and silently mis-orderable. Put the typedef in its own file named `<Thing>Opts.hx` next to its consumer, comment EVERY field on its own line, and say in the typedef's header comment which signature it replaced. Mark a field `@:optional` only when callers genuinely omit it (a lone call site wanting every value = keep them all required). See [`render/particles/PaintOpts.hx`](src/render/particles/PaintOpts.hx) (replaced 16 positional args) and [`render/particles/ProjectileOpts.hx`](src/render/particles/ProjectileOpts.hx) (replaced 10).
- NEVER pack multiple statements onto one line. No inline `{ a; b; }` blocks, no `if (x) { y; return; }`. Each statement on its own line, brace-on-newline (opening brace indented on the next line, body inside). A single-statement body may stay on its own line unbraced. This applies everywhere — guard clauses, loop bodies, self-check blocks, ternary arms.
- Method comments should ALWAYS start from the line start (no indentation)
- When creating variables or method names that have "id" in their name, use ID (e.g., memberID instead of memberId, getMemberID() instead of getMemberId()). Note: This applies to variable and method names only, not object properties like <object>.id which remain lowercase.
- When updating most of the code, keep changes compact: avoid introducing unnecessary temporary variables, redundant conditionals, or extra formatting helpers unless the existing code already requires them. Temporary variables are fine if they shorten the code or are reused.
- All enum values should be in ALL_CAPS_SNAKE_CASE (e.g., `enum ActionType { ATTACK, DEFEND, HEAL }`).
- stop unnecessary defensive checks. Prefer invariant-driven code for internal data structures and hot paths; only add extra null/bounds/type guards at real trust boundaries (user input, save/load migration, external APIs) or when existing local code already uses that guard pattern.
- for newly introduced internal data contracts (generatorInfo, mission hints, etc.), ALWAYS use explicit typed `typedef`/class fields. DO NOT use `Dynamic` unless the source is truly untyped external input.
- for metadata written and read by code introduced in the same change, DO NOT add migration/alias parsing helpers (`parse*` scaffolding, legacy key remaps) unless explicitly requested.
- keep fallback logic minimal and behavior-focused: allow `null`/missing optional fields, then fall back to existing gameplay behavior.
- compatibility shims are allowed only for real pre-existing persisted formats already in production saves; otherwise reject over-defensive parsing.
- any `Dynamic` usage in game logic MUST have an inline comment that states the trust boundary and why typed data is not possible.
- in `parasite-mod-sdk/externs/`, ALWAYS comment EVERY field and EVERY function of every typedef/extern (one-line summary above the line; first letter lowercase). Externs are the mod author's primary documentation surface — uncommented fields ship as silent API to third parties.

## Render & art authoring guards

The rationale, the measurements and the traps behind each of these are in the docs above. These are
here because they have to fire BEFORE anyone knows a doc is relevant.

- **Before generating any prop, texture or reference image, open the doc** (or invoke `3d-art`). Do not work the pipeline from memory — every parameter in it was fitted to a measurement.
- **"we need new images" / "new images" means GENERATE them with the gpt-image MCP tool** (not "the user will supply them"). Treat it as an instruction to run `generate_image`/`edit_image` yourself. Default to 1k (`gpt-image-2`) and never ask; append a canonical style string from `art/textures.json` VERBATIM to every gen/edit prompt — **`style` for a SURFACE** (tiling texture, decal, sprite) and **`style_prop` for an OBJECT** (any TRELLIS reference image, i.e. anything that becomes a glb). They differ in one clause and it is the one that matters: `style` says "very dark and muted desaturated palette", which is right for a wall and is how 9 of 38 props shipped grey, a green tree canopy and a bottle-green bin among them.
- **ASK which route before generating a BATCH of textures: ONE PACKED SHEET or separate images?** Four 512 tiles fit in one 1k gen (`"crop": [x,y,w,h]` in `textures.json`, several labels one source) at a quarter of the cost, and drawing them side by side CHANGES THE ART — measured: it fixed a cardboard chroma three solo rolls could not reach. It also roughly doubles tiling wrap error and cannot serve an aspect-locked 0..1 face or an alpha cut. Never default to either — the trade is the user's, so say what each buys and ask. Numbers in [`docs/3d-textures.md`](docs/3d-textures.md).
- **A BOX IS NOT A PROP — and the real test is SILHOUETTE vs SURFACE.** Axis-aligned slabs (kiosk, bench, cabinet, low wall) get EMITTED as geometry ([`render/facility/FacilityGeom.hx`](src/render/facility/FacilityGeom.hx)); anything whose read is a stripe, a rhythm or a material gets a TILING TEXTURE; only a real silhouette earns a generated glb. Measured: guard booth **7,431 tris → 34**, boom barrier **3,098 → 22**, both also `propstat` REJECTs as glbs.
- **There is a FOURTH route and its test is DIMENSION: hand-model it in Blender over the `blender` MCP** when the brief is a NUMBER — an exact height, a parametric splay, a boolean cut, a shape that has to land on constants the game already has. It also wears the game's OWN textures instead of a bake. The workstation went generated (1,200 tris, blocky) → emitted quads (no silhouette) → hand-modelled (**268/116/44 tris**, tilted screen, recessed tower front, keyboard wedge). Not cheaper by default — argue the triangle budget separately, and build it from a SCRIPT in `models-src/` rather than by clicking. Rules and traps: [`docs/3d-models.md`](docs/3d-models.md) § Hand-modelling in Blender over MCP.
- **An emitted thing takes ONE TEXTURE PER FACE, not one per object** — a front, a side and a top are three different surfaces, and one sheet over all of them puts book spines on a bookcase's top and cardboard boxes in steel. Everything that follows from it (when a face maps 0..1 and the aspect lock that costs, reading the geometry off the art, the value/lift rules, wiring and warm) is in [`docs/3d-geometry.md`](docs/3d-geometry.md) — **open it before emitting geometry**, not after.
- Object/AI visual effects (flames, glows, auras, hit sparks tied to a world entity) must be FRONTAL-facing (fixed yaw, leaned back by `Sprites.TILT`, like the actor sprites) so they stay coplanar with and glued to their source from every camera angle — NOT camera-facing billboards. Camera-facing is only for free transient FX with no world anchor (loose embers/impact sparks). See `render.particles.Sparks` `flameQuad`/`glowQuad` (frontal) vs `streak` (camera-facing).
- Animation timing: every timed anim derives from [`render.RenderConfig.BASE_MS`](src/render/RenderConfig.hx) (base one-turn duration) as a plain multiplier (0.5×/1×/1.5×…), advanced each frame by `dtMs * ANIM_SPEED / BASE_MS` and scaled by the global `ANIM_SPEED`. NEVER hardcode milliseconds — a new anim's duration is `BASE_MS * <mult>`. (bullets etc. bypass and use raw dt.)
- **Warm every new glb path in `View.hx`'s `Models.get` promise chain**, one entry per material variant it will ever draw (`SOLID`/`GHOST`/`HULL` each compile their own program), or it compiles on first area entry instead.
- **ASK before extending the debug surface.** A new or extended hook (`window.__*`, a debug key, a HUD readout, a trace) is permanent instrumentation in shipped game code — say what it would expose and why, and ask. Frame it as PERMANENT and documented, never throwaway. Reading the existing hooks needs no ask.

## Console commands (`src/console/`)

- A new console command is **THREE edits, not one**. Miss any and it half-works:
  1. the handler + its routing branch (`src/console/<Group>.hx`, e.g. `Cult.hx`);
  2. its line in that group's **help block** (the `arr.length == 1` listing);
  3. its node in the **completion table** — `src/console/ConsoleCompletion.hx` (e.g. `cultSubs`, shared by the `cu`/`cult` aliases). Skip this and the command works but autocompletes nothing.
- Command aliases (`occasio`/`occ`) are routed in the handler, but only the **primary** name goes in the completion table.
- Args are declared in the completion table as `slot` nodes (`{ lit: 'br', next: [ { slot: '[amount]' } ] }`) — keep the slot names identical to the help line's.

## 3D render changes: read the index + append the log

- [`docs/3d-render.md`](docs/3d-render.md) is the index: measurement rules, standing notes, open leads, and a verdict table with one row per experiment ever tried. **READ IT BEFORE proposing or starting any render change.** It is kept small on purpose — do not grow it beyond its table rows.
- [`docs/3d-changes.md`](docs/3d-changes.md) is the append-only log holding the full write-up of each entry. Find one by grepping the change text from the verdict table. **APPEND to it after trying anything** (including failures — those are the valuable entries), and add the matching row to `3d-render.md`; an entry with no row is invisible.
- **Entry shape: ~25 lines** — what changed, the measured numbers, the trap, the verdict. **Settled outcomes only**: no `IN PROGRESS`, no `pending`, no `TODO`, no "checked X and it was clean" narrative. If it is not settled, it is not an entry yet. When a new entry invalidates an old one, mark the old heading `> SUPERSEDED by <heading>`.
- `3d-changes.md` is capped: when it reaches ~2600 lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one. The verdict table is what survives rolling, so the row matters more than the body.
- **Measure, never infer.** `calls=` in the `[street-render]` trace is the only draw-call number; the scene dump (`9`) is an INVENTORY, not a draw list (measured: 1616 visibleDrawables → 435 calls). The rest of the measurement rules live in the index.

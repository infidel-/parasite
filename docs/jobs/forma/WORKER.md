# Forma: its own build UI (worker brief)

**Status: Phase 4 is next.** Phases done: 1, 2, 3. (The controller updates this line at each phase boundary.)

**Controller:** session `build-forma-ui-plan` (`ListAgents`, `SendMessage`). You are the worker: read
`docs/worker-loop.md` § Worker first. The controller drives the live game; **you never use CDP** (no
`mcp__chrome-devtools__*`, no `make reload`). You edit, build with `cd src && make`, log, report, and hold.

## Goal
Forma (cult base build mode, `HUD_BASE_BUILDING`) runs through the generic actions menu (`CultBase.updateActionList`,
~16 numbered rows) and a plain-text info panel (`CultBase.hudInfo`). The user approved a dedicated UI, designed as an
interactive HTML preview: **`docs/jobs/forma/preview.html` is the spec.** Its CSS tokens, layout px, tint/mask technique,
strings and interaction rules are what you build. The reference shots are `docs/jobs/forma/final.png` (whole screen)
and `final_tray.png`. The preview's `{{...}}` placeholders (fonts, snapshot) were filled by a build script. Read the
code, not the placeholders. Its `S` state, `SNAP` cells and sample resources are preview-only stand-ins for the game's
data.

The user's decisions:
- Custodes keys are `-` and `=`.
- Hovering the map moves the cursor; clicking builds, crafts or tends.
- Tray sprites are always tinted with the pink wash.
- Inside Forma, Q/E turn the turret; the quick menu is not available there.
- No save format changes. The custos selection lives in the HUD and is not saved.

## Rules for this job
- Code style, `T()`/`N()` and the rest come from the repo CLAUDE.md, which is loaded for you; follow it to the letter.
  A sentence with values is ONE `T()` template with `{placeholders}`.
- Each base action has ONE refusal function returning its reason ('' = OK). The HUD calls these and never
  re-implements a rule.
- Use the game's existing strings for every refusal. Never invent a new refusal text.
- No new debug hooks, no new console commands.
- Touch only the files listed for the phase. Anything else is a question to the controller first.
- At the end of each phase: `cd src && make` must pass. Then add a `LOG.md` entry (files, what changed, build result),
  send the controller a one-line summary, and **hold**. Do not start the next phase until the controller says so.

## Phase 1: one refusal function per action
Files: `src/cult/base/CultBase.hx`, `src/const/CultBaseConst.hx` (and the typedef of `info()` wherever it lives).
- **Extract the refusal checks:**
  - add `validateUpgrade(organ): String`, `validateRepair(organ): String` and `validateCustos(x, y): String`, each
    returning '' or the exact `T()` reason that `upgradeAtCursor`, `repairAtCursor` and `createCustos` use today;
  - the reasons: 'This organ cannot grow further.', 'This organ is whole.', 'Not enough base resources.', 'A working
    Caldarium is required.', 'Custodes capacity reached.', 'Custos needs a free tile.';
  - those three functions then call the validator and `game.actionFailed(reason)`, with behaviour unchanged;
  - "No base organ at cursor." stays in the `*AtCursor` functions.
  - The custos cost (10/8/0) becomes one constant used by both `validateCustos` and `createCustos`.
- **Make `custosCap()` public.**
- **Extract `incomePerTurn()`** from `turn()`: the per-organ flesh/blood/bone yield and the bodies drawn. It is a pure
  function: it simulates the body draws on a copy of the count and mutates nothing. `turn()` then applies its result
  (stockpile cap as now). No number changes. Read `docs/relations.md` § Cult base before touching `turn()`.
- **`CultBaseConst.info()` gains two fields:**
  - `shortName`, an `N()` string: 'Murus' for RIBWALL, 'Porta' for RIBGATE, 'Turris' for SPINE_TURRET, the full name
    for the rest;
  - `desc`, an `N()` string: the preview's `ORG[...].does` line for each organ (preview.html ~line 230).
- Check: `cd src && make` passes. The quick bot tests run the base logic, so the refactor must keep them green.

## Phase 2: the FormaHud panels
Files:
- ❔ new `src/ui/hud/FormaHud.hx`
- `src/ui/HUD.hx`
- `src/ui/hud/ActionsHud.hx`
- `src/ui/hud/InfoHud.hx`
- `src/cult/base/CultBase.hx`
- `electron/app.css`

**The panel.** `FormaHud` is a DOM panel like the others: constructed with `(game, hud)`, appended to `hud.container`,
created in `HUD.hx` next to the other panels, and updated from `HUD.update()`. It is visible only when
`hud.state == HUD_BASE_BUILDING`.

**Ledger** (preview `#ledger`, `renderLedger`):
- the reservoirs flesh/blood/bone against `stockpileCap()`;
- the cost bite: the selected tool's cost hatched out of each fill, and a shortfall overhanging in alert stripes;
- income per turn from `incomePerTurn()`;
- Bodies, Custodes `n/cap`, Pressure and the defense timer (find how `statusText` gets it);
- the Corpus Basilica checklist (from the data `readinessText` uses).

**Tray** (preview `#tray`, `renderTray`): fixed groups and keys, not sorted by name.
| Group | Keys | Tools |
|---|---|---|
| Defense | 1–4 | RIBWALL, RIBGATE, SPINE_TURRET, BLOOD_TRAP |
| Growth | 5–8 | FLESH_BLOCK, RAT_NEST, CRUSHER, GARBAGE_HEAP |
| Upkeep | 9, 0 | BODY_STORAGE, CAULDRON |
| Custodes n/cap | `-`, `=` | Firmus, Mordax |
- Each tile shows its short name, its cost (resource colours, the short resource marked) and its key.
- The selected tile is pressed (`aria-pressed`). The spine turret tile shows the picked direction.
- An unaffordable tool dims. Custodes also dim without a working Caldarium or at the cap.
- Custodes need a "selected custos" field in FormaHud: null means the organ in `base.selectedType` is the tool.

**Sprites** (preview `.tint`, `tintHTML`):
- the CSS colour-layer, blend and alpha-mask technique, with `--tc: rgba(253,151,255,.38)` and `--bm: soft-light`;
- the organ atlas is `CultBaseConst.IMAGE_PATH`, cells from `CultBaseConst.block()` / `spineTurretBlock()`, every URL
  through `AssetPath.resolve`;
- a 2×2 organ shows at half size so every tile is 64 px; 1×1 organs show native; never scale an image up;
- custodes come from `img/creatures64.png` (512×192, 64 px cells): Firmus row 0 col 0, Mordax row 1 col 0 (see
  `Images.hx` ~321).

**Tooltip** (preview `#detail`, `renderDetail`, `cardHTML`):
- shown while a tray tile is hovered or focused, and after a key pick until the cursor moves;
- contents: the full name, the `desc`, the cost.
- Custodes descs are new `N()` strings, from the preview's `CUSTOS[...].does`.

**Key legend** (preview `#keys`, `renderKeys`): the two variants, normal and tend menu.

**CSS:** one new `#hud-forma` block in `electron/app.css` with the preview's tokens (`--plum`, `--edge`, `--rule`,
`--wash`, `--bone`, `--flesh`, `--blood`, `--blood-text`, `--cult`, `--dried`, `--alert`) and its px layout. The fonts
Cruiser2015 and Virtucorp are already loaded by `electron/fonts.css`. The ledger sits where the info panel was.

**Remove the old UI:**
- the Forma branch of `ActionsHud.updateList`: in Forma the actions list is empty and the panel shows nothing;
- the Forma branch of `InfoHud.update`;
- `CultBase.updateActionList` and `CultBase.hudInfo`, if nothing else calls them (grep).
- Phase 3 gives F its new home. Until then, exiting Forma may only work from the code path the controller uses.
  Note it in the LOG.

The chip and the tend menu DOM can wait for Phase 3.

Check: `cd src && make` passes. The controller then compares the live game against `final.png` and may send visual
fixes; expect 2–3 rounds.

## Phase 3: input and map overlays
Files:
- `src/ui/hud/FormaHud.hx`
- `src/ui/UI.hx`
- `src/ui/Mouse.hx`
- `src/cult/base/CultBase.hx`
- `electron/app.css`
- `src/test/Bot.hx`: around line 1024 the bot picks `baseExit`, else `escape`; it must exit Forma with the new F key
- `src/render/Actors.hx`: one call next to `badges.drawFormaCursor()` places the chip and menu per frame, using its existing projection (~499-512); no View.hx change, no rAF loop of your own

**Keys.** In `UI.hx`, while `HUD_BASE_BUILDING`, a `hud.forma.onKey(...)`-style hook sees the key first and returns
true when it used it.
| Key | Action |
|---|---|
| Digit 1–0 | pick the organ |
| `-` / `=` (codes Minus / Equal) | pick Firmus / Mordax |
| Enter | act |
| Q / E | turn the turret (`base.selectedDirection`), before the quick menu's `q` |
| F | exit Forma, as `baseExit` did: `HUD_DEFAULT` + `setTactical(false)` |
| Escape | closes an open tend menu; otherwise not used, so the main menu opens as before |
| arrows / numpad | close the tend menu, then move as today |
- With the tend menu open, digits run its rows instead.

**Act** (preview `verdict()` and `act()`):
- if an organ is under the cursor, and the pick is not Porta over a Murus: open the tend menu;
- else if a custos is picked: `createCustos(type)`;
- else: `buildSelected()`.

**Mouse** (`Mouse.hx`):
- hovering a map cell in Forma calls `base.setCursor` when the cell changes, but not while the tend menu is open;
- a click on the map sets the cursor, then acts;
- a click while the tend menu is open only closes it and moves the cursor, unless it is on the same organ;
- clicks and hovers on FormaHud's own panels must not reach the map.

**Chip** (preview `#chip`, `renderChip`): one line under the footprint.
- The line reads "Click to build X", "Click to craft X", "<name> <HP bar> hp/max Click to tend", or the validator's
  reason in alert red.
- It flips above the footprint when it would hit the tray.
- It is hidden (visibility) while the tooltip shows.

**Tend menu** (preview `#tend-float`, `tendOpts`, `tendHTML`): it sits beside the organ footprint, flipped near the
right edge.
- **Header:** sprite, name, "Level N of M", HP bar.
- **Rows:**
  1. Upgrade to level N: `upgradeAtCursor`, its reason from `validateUpgrade`.
  2. Repair: `repairAtCursor`, `validateRepair`.
  3. Grow Porta Costarum (Murus only): `validateBuild(RIBGATE, ...)` + afford.
  4. Esc Back.
- An unavailable row shows its reason. Pressing its key logs the reason via the action itself.
- Hovering or focusing a row shows its cost bite in the reservoirs.
- Focus goes to the first enabled row. The tray is inert and dimmed while the menu is open.

**Placement.** The chip and the menu are anchored to the footprint's projected corners (`CityConfig.cellToWorld` +
`WorldCtx.floorY`, `Vector3.project(camera)`, viewport scale, as the speech bubbles do). Re-place them every frame
while visible, so a camera move keeps them glued.

Check: `cd src && make` passes. The controller then runs every scenario live.

## Phase 4: 3D footprint ghost
Files: `src/render/actors/Badges.hx`, and `src/render/Actors.hx` only if the call needs new arguments.
- Read `docs/3d-render.md` first (the CLAUDE.md rule).
- `Badges.drawFormaCursor` (~206) draws one reticle today. It should draw instead:
  | Under the cursor | Look |
  |---|---|
  | the selected tool's footprint, valid | w×h cell quads, bone `#e9dfc8` |
  | the selected tool's footprint, refused | alert `#f26a6a` |
  | an organ (the tend case) | that organ's footprint in pink `#fd97ff` |
  | spine turret selected | an arrow in its direction |
- The verdict comes from the same refusal functions.
- Reuse the reticle's material and quad path. Add no new draw path if the badge batch covers it, and say in the LOG
  if it does not.
- The controller measures `calls=` and writes the `docs/3d-changes.md` entry; you report what you changed.

## Log
`docs/jobs/forma/LOG.md`: one entry per iteration (phase, files, change, build result). The controller commits.

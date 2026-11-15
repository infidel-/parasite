# Forma worker log

One entry per iteration: phase, files, what changed, `make` result. Newest last.

## Phase 1: one refusal function per action
- Files: `src/cult/base/CultBase.hx`, `src/const/CultBaseConst.hx`.
- `validateUpgrade(organ)`, `validateRepair(organ)`, `validateCustos(x, y)` return '' or the existing `T()` reason; `upgradeAtCursor`, `repairAtCursor`, `createCustos` call them then `game.actionFailed(reason)`. "No base organ at cursor." stays in the `*AtCursor` functions. Same check order as before.
- `CultBaseConst.custosCost` (10/8/0) used by `validateCustos` and `createCustos`.
- `custosCap()` is public.
- `incomePerTurn(): CultBaseIncome` (typedef `{ income, bodies }` at the top of CultBase.hx) is pure: body draws run on a local copy of `storedBodies`. `turn()` sets `income = res.income` and `storedBodies -= res.bodies`; per-organ numbers unchanged.
- `CultBaseOrganInfo` gained `shortName` and `desc` (`N()` strings, the preview's `does` lines; Murus/Porta/Turris short names, full name for the rest).
- Note: `meta()` already took 9 positional args. Not converted to an Opts typedef (would be a new file outside the phase list); `info()` fills the two new fields through a small `text(meta(...), shortName, desc)` helper instead. Controller to decide if an Opts typedef is wanted.
- Build: `cd src && make` passes; quick tests 54 runs, 0 failed; loc check +14 strings.
- Review fix: `text(data, desc, ?shortName)`; `shortName` overrides the `meta()` default (the name) only for Murus/Porta/Turris. Build: `cd src && make` passes.

## Phase 2: the FormaHud panels
- Files: ❔ `src/ui/hud/FormaHud.hx`, `src/ui/HUD.hx`, `src/ui/hud/ActionsHud.hx`, `src/ui/hud/InfoHud.hx`, `src/cult/base/CultBase.hx`, `electron/app.css`. (`loc/en.json` was rewritten by the build's loc step.)
- `FormaHud(game, hud)`: root `#hud-forma` in `hud.container`, shown only in `HUD_BASE_BUILDING`; `HUD.forma` is public, `HUD.update()` calls `forma.update()`. Four blocks (ledger, tray, key legend, tooltip), each re-set only when its html changed.
- Ledger: reservoirs with the cost bite and shortfall stripes, income from `incomePerTurn()`, Bodies/Custodes/Pressure, defense timer (when `activeDefenseMissionID >= 0`), Corpus Basilica checklist from the new `CultBase.readiness()` (typedef `CultBaseReadiness`; `readinessText()` now uses it).
- Tray: fixed groups and keys (1-4, 5-8, 9/0, `-`/`=`), tiles with short name, cost and key, pressed = picked tool, dim when unaffordable (custodes also without a working Caldarium or at cap), turret tile shows the direction arrow. Sprites use the `.tint` colour layer + alpha mask; atlas from `CultBaseConst.IMAGE_PATH` / `block()` / `spineTurretBlock()`, custodes from `img/creatures64.png`, every URL through `AssetPath.resolve`, 2x2 organs at half size.
- Tooltip on tile hover/focus, and after a key pick until the cursor moves (FormaHud notices the cursor change itself). Custodes names/descs are new `N()` strings.
- Hooks left for Phase 3: `pick(id, fromKey)` (id = organ type name or `firmus`/`mordax`; sets `base.selectedType` or `selectedCustos`), `selectedCustos`, `peek` (cost bite override), `tendRows` (>0 = tend menu open: tray inert, tooltip off, legend variant).
- Old UI removed: Forma branch of `ActionsHud.updateList` (list empty, panel `display:none` in Forma), Forma branch of `InfoHud.update` (panel `display:none` in Forma; `baseInfo` region deleted), `CultBase.updateActionList`, `hudInfo`, and their helpers `action()` / `directionName()`. `CultBase.bodyCapacity()` is now public.
- `baseExit` is gone with `updateActionList`, so until Phase 3 there is no F key out of Forma. `src/test/Bot.hx` still asks for `baseExit` first and falls back to `escape`; the quick tests do not hit it.
- Deviation: the preview's pressure "warn" colour (>= 10) was a stand-in with no game rule behind it, so Pressure is never red. Only the defense timer is.
- Not verified in the live game; visual check is the controller's.
- Build: `cd src && make` passes; quick tests 54 runs, 0 failed; loc check +44 -15 strings.

- Font fix (live check): `fonts.css` gives Virtucorp `size-adjust: 145%` and Cruiser2015 `90%`, the preview embedded neither. Every font size in the `#hud-forma` block is now `calc(Npx / 1.45)` (Virtucorp) or `calc(Npx / 0.9)` (Cruiser2015); px layout unchanged, `fonts.css` untouched. Build: `cd src && make` passes.

- CSS fix 2 (live check): `#hud-forma, #hud-forma *` is `box-sizing: border-box` like the preview (the game is content-box). Every line-height in the block is now the preview's font px times its ratio, in px (a unitless one multiplies the shrunken font-size, not the glyph size). Basilica `li` is 14px x 1.5 = 21px (the preview's `ul` is 14px, not 15). Elements that inherited the body's 1.25 ratio got their own px value; `.fm-val`, its `small` and `.fm-after` use 1 (22/13/13px) as in the preview. Build: `cd src && make` passes.

## Phase 3: input and map overlays
- Files: `src/ui/hud/FormaHud.hx`, `src/ui/UI.hx`, `src/ui/Mouse.hx`, `src/render/Actors.hx` (added to the list by the controller), `src/test/Bot.hx`, `electron/app.css`. `CultBase.hx` needed no change.
- Keys: `UI.onKey` calls `hud.forma.onKey(e)` right after the targeting branch (before the quick menu), only in `HUD_BASE_BUILDING` with no window open. Digit1-0 / Minus / Equal pick (`pick(id, true)`), Enter acts (a focused button inside `#hud-forma` clicks itself instead), Q/E turn `base.selectedDirection` (swallowed, no quick menu), F exits (`exit()`: tend closed, `HUD_DEFAULT`, `setTactical(false)`, `mouse.update(true)`), Escape closes an open tend menu else is not used. With the tend menu open digits run its rows, Q/E and tray keys are swallowed. Movement keys close the tend menu in `UI.handleMovement`'s Forma branch, then the cursor moves as before.
- Act: `FormaHud.verdict()` (`FormaVerdict`: `act` TEND/BUILD/CRAFT, `reason`, `organ`) is public, from the same `validate*` functions plus affordability; `act()` opens the tend menu, `createCustos(selectedCustos)` or `buildSelected()` (they log their own refusal). A Porta picked over a Murus builds instead of tending.
- Mouse: hovering a map tile in Forma calls `base.setCursor` when the tile changes and `tendRows == 0`; a forced update (entering Forma) only records the tile, so the cursor starts where the player is. A click goes to `FormaHud.onMapClick`: tend menu open = close it and move the cursor unless on the same organ; else move the cursor and act. Panels are `pointer-events: auto`, so their clicks and hovers never reach the canvas; the chip and tooltip are click-through as in the preview.
- Chip `#hud-fm-chip`: "Click to build/craft {name}", organ name + hp bar + hp/max + "Click to tend", or the refusal in alert red; hidden (visibility) under the tooltip, `display:none` while the tend menu is open.
- Tend menu `#hud-fm-tend`: header (organ sprite, name, level, hp bar), rows Upgrade (`validateUpgrade`), Repair (`validateRepair`), Grow Porta (Murus only: `validateBuild(RIBGATE)` + afford; builds with `selectedType` swapped and restored), Back. A row with no cost shows its reason; a row with a cost but not enough resources shows the short-marked cost and logs the reason when run. Hover/focus a row = cost bite in the reservoirs (`peek`); first usable row is focused on open; tray inert while open (existing class). The menu closes by itself when its organ leaves `base.organs` (checked in `update()`).
- Placement: `Actors.placeForma()` runs next to `badges.drawFormaCursor()` (every frame, while the HUD is on): it projects the corners of `forma.anchorCells()` on their floor (`cellToWorld` + `floorY`, `project(camera)`, `Viewport` scale) into a `FormaBox` and calls `forma.place(box)` (null when all corners are behind the camera: both go off screen). Sizes are measured once per html change; chip flips above the footprint above the tray, tend menu flips left near the right edge.
- Refactor: tray sprite code split into `tintOrgan(type, direction)` / `tintHTML(...)`, reused for the tend header (uses the organ's own `direction`).
- Bot: in `HUD_BASE_BUILDING` it offers `press('key f exit forma', 'KeyF', ...)` with id `baseExit`, so the goal policy's `first(list, ['baseExit', 'escape'])` leaves Forma by the key; its fake key event gained `metaKey: false`.
- CSS: `#hud-fm-chip`, `#hud-fm-tend`, `.fm-hp`, `.fm-opt` etc. in the `#hud-forma` block, same px rules as before (font px / 1.45 or / 0.9, absolute line-heights, border-box).
- Not verified in the live game (visual and every scenario is the controller's). Deviation: the tend rows' "Esc" key label is the literal `Esc`, not a `T()` string.
- Build: `cd src && make` passes; quick tests 54 runs, 0 failed; loc check +10 strings.

- Live-check fixes: (1) `UI.onKey` now `preventDefault`s a key `FormaHud.onKey` consumed, so the browser's Enter no longer clicks the row `openTend` just focused (Enter on a focused button still returns false, native click kept). (2) `Bot.hx`: the Forma F-exit option moved inside the `ui.hud.state != HUD_DEFAULT` branch next to `escape()`, so the navbar-windows `else` binds to its original `if` again. Build: `cd src && make` passes; quick tests 54 runs, 0 failed.

- Enter regression fix: `FormaHud.onKey` no longer relies on native button activation (UI preventDefaults every consumed key). Tend menu open: Enter/NumpadEnter reads the row of `document.activeElement` (`rowOf`), runs it (`runRow`) or closes the menu on Back, returns true. No menu: a focused tray tile is picked explicitly (`pick(id, false)`), else `act()`. Build: `cd src && make` passes.

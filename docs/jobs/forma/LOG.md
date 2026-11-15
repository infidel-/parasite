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

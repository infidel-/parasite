# Cult L2 worker log

One entry per iteration: phase, files, what changed, `make` result. Newest last.

## P1: unblock, save hygiene, L2 limits
- Files: `src/cult/ordeals/MetamorphosisPhaseI.hx`, `src/cult/base/CultBase.hx`, `src/cult/Cult.hx`,
  `src/console/Cult.hx`, `src/console/ConsoleCompletion.hx`.
- Phase I `initiateAction`: removed the 0.22 disable + `return`.
- `CultBase._ignoredFields`: + `income`, `cursorX`, `cursorY`, `selectedType`, `selectedDirection`. `init()`
  defaults them; the only readers are Forma build/tend actions, and `PlayerArea.hx` ~416 sets the cursor on entry.
- `Cult.maxSize()` / `getLevelLimit()`: level 2 → cap 15, L1 15, L2 5, L3 2 (level 1 unchanged).
- Console `cu meta 1|2`: handler `metamorphosis()` (needs an active cult; `1` sets `metamorphosisPhaseIComplete`;
  `2` refused when a base exists, else pushes a `MetamorphosisPhaseII` ordeal and runs its Perform action `f()`,
  which refuses outside a habitat and keeps the ordeal), help line, completion node `meta` + `[phase]` slot.
- Build: `cd src && make` passes (58 quick runs, 0 failed; loc-test ok). The `fr unreadable` line in loc-test
  predates this phase (`electron/lang/fr.json` JSON error), not touched.
- New math: none (only limit constants).
- P1 fix (controller review): `console/Cult.hx` `metamorphosis()`: when the Perform is refused (`cult.base == null`
  after `f()`), the ordeal is removed from `cult.ordeals.list` and `recalc()` runs, so repeats don't stack. A
  successful Perform already removes it (`Ordeals.success` → `list.remove`); members are locked only through the
  ordeal list, so removal frees them. Build: `cd src && make` passes (58 runs, 0 failed).

## P2 (a): placement, economy, Reap
- Files: `src/cult/base/CultBase.hx`, `src/cult/base/CultBaseOrgan.hx`, `src/const/CultBaseConst.hx`,
  `src/ui/hud/FormaHud.hx`, `src/cult/ordeals/ReapTheUnwary.hx`, `src/test/Scenarios.hx`. `make` also rewrote
  `loc/en.json` (generated string catalog, +17 strings).
- Placement: `validateBuild` ends in new `validateClearance(type, x, y)`: the 8-tile ring around the footprint must
  hold no wall (off-floor tile), object, organ or body (AI) for a standard organ; Ribwall/Porta (`isRib()`) may touch
  walls and rib/Porta organs but no other object or non-rib organ. One refusal text each.
- Nidus Murium: saved `CultBaseOrgan.focus` (`'flesh'`/`'blood'`/`'bone'`, default flesh, set in `init()`);
  `incomePerTurn` pays 3 of the focus and 1 of each other per level. `validateFocus`/`setFocus(organ, focus)`; the tend
  menu gets a free "Focus on X" row per other resource. Organ description updated.
- Cadaverum: `validateDrain`/`drainBody(organ)`: 1 stored body → `BODY_DRAIN_BLOOD` (4) blood at once, refused when
  broken, with no bodies, or with the blood stockpile full. Tend row "Drain a body: +4 blood".
- Heart repair: `CultBaseConst.repairCost(COR_NEFANDUM)` = ceil 25% of `upgradeCost(COR_NEFANDUM, 1)` = 10/8/8.
- Readiness counts working organs only (`readiness()` skips broken ones).
- Reap the Unwary: cost is now 100k money OR two of media/lawfare/corporate/political (never money as a slot);
  `getActions()` drops every `spend.*` action and `getNote()` says why while no working Cadaverum exists.
- Scenarios (made to fit the new rules; the 21x14 habitat fits one or two 2x2 organs under the clearance rule):
  `base-build` lifts each organ after it grows (keeps the Murus) and a new `clearance()` check (organ refuses a
  Murus beside it, Murus chains with Murus, Murus refuses a Nidus and every object); `base-economy` plants its five
  organs with `looseSpot`/`plant` (no clearance rule, paid as a build) and checks focus, drain, readiness and Reap;
  `base-tend` checks the 10/8/8 heart repair. Helpers `plant`, `unplant`, `looseSpot`, `clearance`.
- Build: `cd src && make` passes (58 quick runs, 0 failed).
- New math: Reap cost variant roll is 50% money / 50% two powers; Nidus focus 3/1 split; drain 1 body → 4 blood;
  heart repair 25% of upgrade I; clearance ring.
- P2 (a) fix (user decisions): clearance rule dropped (`validateClearance` and its two strings removed; placement
  is footprint-only again) and the scenario workarounds reverted (`base-economy` grows its organs with `grow`, `base-build`
  no longer lifts organs; helpers `plant`/`unplant`/`looseSpot`/`clearance` deleted). `CultBaseOrgan.focus` is now the
  enum abstract `CultBaseFocus` (`FLESH`/`BLOOD`/`BONE`, String values) declared in `CultBaseConst.hx`, defaulted to
  `FLESH` in `init()`; `focusTypes`, `focusName`, `validateFocus`, `setFocus` and the Scenarios checks use it. No INFO
  lines for (a). Build: `cd src && make` passes (58 runs, 0 failed).

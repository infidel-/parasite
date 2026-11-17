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

## P2 (b): attacks and old ambush paths
- Files: `src/cult/base/CultBase.hx`, `src/cult/missions/BaseDefense.hx`, `src/cult/missions/BaseDefenseLogic.hx`,
  `src/game/Team.hx`, `src/game/Group.hx`.
- Pressure defense: `CultBase.addPressure` with no `cultID` now picks a live rival (`pickAttackingRival`, weight
  `1 + power.combat`); the generic 2 thugs + 2 security stay only when none lives (-1).
- New `CultBase.startDefense(ordeal)` registers the ordeal, mission id, timer and saved `defenseFirstBodyID`
  (default 0 in `init()`); `addPressure` and `Team.spawnBaseDefenseOrdeal` use it. The console `cu def` still sets
  the ids by hand, so a debug defense leaves `defenseFirstBodyID` at 0 (counts every body).
- `BaseDefenseLogic.commandAttacker`: fights the closest visible custos / player-cult cultist / player host / earlier
  attacker (`getEngageTarget`, never dead or preserved); else `getHeartRoute` (Dijkstra over the habitat, free tile 1,
  working non-heart organ 6) walks toward Cor Nefandum, hits the first organ on the route when it is next to it, and
  hits the heart once beside it. The old nearest-organ `getAttackTarget`/`getAdjacentAttackTarget` are gone.
- Rival attackers: `BaseDefense.equipByLevel` by member job level: 1 knife if unarmed; 2 pistol (skill 40+10*level+0..9)
  if no ranged weapon + 25% kevlar; 3 pistol + kevlar.
- Bodies: `loadBodiesIntoStorage` counts only bodies made since the defense began (`o.id >= defenseFirstBodyID`) and
  removes from the floor the ones stored; overflow bodies stay on the floor.
- `BaseDefense.onEventAI` no longer completes at once: the dead attacker's `BodyObject` is made AFTER the death event,
  so the last body was missed; the mission now ends on the next `turn()`. `TeamBaseDefense` (not in my files) still
  completes inside the event, so its last attacker's body is still missed.
- Ambush paths: `Team.turn` turns a team in `TEAM_AMBUSH` into a base defense whenever a base exists (waits while
  another defense runs); `Group.onDirectorDeath` routes the final team there at once.
- Build: `cd src && make` passes (58 runs, 0 failed). No scenario for (b) yet (group (d)).
- New math: rival pick weight 1+combat power; route costs 1 / 6; loadout by level (above); pistol skill formula.
- P2 (b) fixes (controller review): `Team.turn` with a base and `TEAM_AMBUSH` tries `spawnBaseDefenseOrdeal()` and
  returns either way (no fall-through to `turnAmbush`); `Team.onEnterHabitat` returns early while a base exists (no
  `TEAM_FIGHT` spawn in an ambushed habitat); the extra call in `Group.onDirectorDeath` is dropped (the final team
  has `timer = 3`, `Team.turn` picks it up). `TeamBaseDefense.onEventAI` no longer completes inside the event (the
  mission ends on the next `turn()`, last body counted). Console `cu def` uses `base.startDefense(ordeal)`.
  Files added: `src/console/Cult.hx`, `src/cult/missions/TeamBaseDefense.hx`. Build: `cd src && make` passes (58 runs, 0 failed).

## P2 (c): custodes
- Files: `src/ai/CustosLogic.hx`, `src/ai/FirmusCustosAI.hx`, `src/ai/MordaxCustosAI.hx`, `src/cult/base/CultBase.hx`.
- Stats: both override `recalc()` (`maxHealth` = STR+CON then Firmus +6 → 26 at STR 8 / CON 12, Mordax -1 → 16 at STR 10 /
  CON 7; ±1 STR/CON still moves it; `maxEnergy` fixed 240 / 190 per design.md).
- Own attacks: `getCurrentWeaponItemInfo()` overridden (not the generic `animal` item): Firmus slam 1-4 (BLUNT),
  Mordax bite 3-8 (BITE), built by new `CustosLogic.attackInfo` with their own hit texts.
- Heal: `CultBase.healCustodes` heals nothing during a defense; with the player in the base habitat the LIVE custodes
  heal +1 per cult turn (they overwrite their records on leaving), otherwise the records heal +1.
- `CustosLogic.findTarget` never targets the player host or preserved hosts.
- INFO: custodes attacks already print through the generic `__Math.damage` line (`Damage AI->AI: 3...8 (5) = 5.`, plain
  English, no custos name) in `CommonLogic.logicAttack`; no custodes-specific line added (question to the controller).
- Build: `cd src && make` passes (58 runs, 0 failed). No scenario yet (group (d): `base-custos` stats).
- New math: life/energy numbers above; heal +1/turn live (as before for records).

## P2 (d): scenarios
- File: `src/test/Scenarios.hx` only. New: `defense-rival` (`BASE+cu_br_100+cu_def`), `defense-timeout` (`BASE+cu_def`),
  `ambush-base-turn` (`BASE`); extended: `base-custos` (new `custosStats`). `base-build`, `base-economy`, `base-tend` were
  extended in (a) (focus, drain, readiness, Reap, heart repair); the clearance checks went with the rule.
- `defense-rival`: a Cadaverum placed by hand (Forma is closed during a raid) and an older body before the raid;
  attackers armed by member level (weapon; level 2+ ranged; level 3 kevlar); Cor Nefandum ringed with Murus: the route
  must hit a Murus before the heart (`getHeartRoute` via `@:privateAccess`); all attackers die, the mission ends on
  the next turn: survived +1, Cadaverum +n bodies, only the older body left on the floor (proves the last body is
  counted); pressure 30 then starts a defense naming a rival.
- `defense-timeout`: the ordeal's missions emptied so no attacker comes, cult turns until the timer ends: game FINISH, heart 0.
  The ordeal is gone with its mission, so the scenario resets `activeDefenseMissionID` before the invariants run.
- `ambush-base-turn`: a team in `TEAM_AMBUSH` with the player in the ambushed base habitat becomes `TEAM_BASE_DEFENSE`;
  a second one while that defense runs never reaches `TEAM_FIGHT`.
- `base-custos` `custosStats`: Firmus life 24-28, Mordax 14-18, slam 1-4, bite 3-8, a hurt custos heals +1 per cult
  turn in the base and nothing during a defense, and `findTarget` skips the host for a farther thug (checked by
  mutation: without the `isPlayerHost` rule the scenario fails).
- Build: `cd src && make` passes (61 runs, 0 failed).

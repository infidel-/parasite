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

## P3: defense organ upgrades and turret rotation
- Files: `src/const/CultBaseConst.hx`, `src/objects/base/{Ribwall,Ribgate,SpineTurret,BloodTrap,BaseOrganObject}.hx`,
  `src/cult/base/CultBase.hx`, `src/ui/hud/FormaHud.hx`, `src/test/Scenarios.hx`. (`loc/en.json` was regenerated by the build.)
- Levels: Murus, Porta, Turris, Tardans maxLevel 3 (upgrade cost ×1 then ×2 comes from the existing `upgradeCost`). Health
  18/26/34, 24/32/40, 18/24/30, 10/14/18. Tables in `CultBaseConst`: `turretDamage` 3-8/4-10/5-12, `turretTargets` (2 at
  level 3), `gateBite` 2-5/3-7/4-9, `trapSlime` 10/14/18. Descriptions of the four organs reworded.
- Porta `frob`: bite by level + `Bleeding(3)`, still -1 gate health per bite. Tardans: `Slime` by level (was Paralysis 2),
  -1 pool health per trigger, no longer immune to attack (override removed); the player host no longer triggers it (`!isPlayer`).
- LOS: `Ribwall` and `Ribgate` `canSeeThrough` false while the organ works. "Closed Porta" read as "working Porta" (a gate
  has no open state).
- Turret: `turn()` uses the level's damage and shoots the first N foes in line (N 2 at level 3); a working Murus/Porta in
  line stops it through `canSeeThrough`.
- Rotation: `CultBase.validateTurn` (only a turret, not broken) + `turnTurret` (a quarter clockwise, refreshes the 3D prop
  via `updateObjects3D`). Forma tend row "Turn" (free) and object action `turnTurret` ("Turn turret", one action point).
- Scenario `base-tend` extended (`baseDefenses`): levels/health/cost ×1,×2/top, LOS working/broken/mended, Turn row free, broken
  refuses, object action spends 1 AP, level 3 hits two foes and level 1 one (checked by mutation), Porta bite range + bleeding
  by level, Tardans slime by level + wear.
- Build: `cd src && make` passes (61 runs, 0 failed).
- New math: tables above; Slime points 10/14/18 (my pick, brief said "points by level"); Bleeding 3; trap wear 1 per trigger
  (my reading of "attackers can damage it": the pool wears out, and attackers can target it; nothing routes them at it).
- P3 fix (controller review): `SpineTurret.turn` skips `isPlayerHost()` and `AI_STATE_PRESERVED` (as `CustosLogic.findTarget`),
  and keeps looking down the line. `base-tend` `baseDefenses`: host and a preserved thug stand in line, neither is hit, the foe
  behind is (checked by mutation: both rules removed fails). Build: `cd src && make` passes (61 runs, 0 failed).

## P5 (a): generator, strategic turns, growth, research dead end
- Files: `src/const/CultConst.hx`, `src/cult/RivalCult.hx`, `src/cult/ordeals/MetamorphosisPhaseII.hx`,
  `src/cult/base/CultBase.hx`, `src/cult/ordeals/RivalResearch.hx`, `src/test/Scenarios.hx`. (`loc/` regenerated by the build.)
- `CultConst`: table `tunings` keyed by TACTIC (not template: Blooded Mask is template `occult` but combat tactic, and
  must keep a combat roster): `mix` (AI type + optional power group the job is rolled from), `startMembers` 6, `level2Pct`/
  `level3Pct`, `recruitPct`, `pressure`. Constants `RIVAL_TURN_PERIOD` 10, `RIVAL_REPLACE_TURNS`/`SPREAD` (used in (b)).
  `randomRivalID(tactic, taken)` prefers an info not held by a live rival.
- `RivalCult.generate(game, tactic)` (static; also pushes into `game.cults`) replaces `createRivalCult` /
  `rivalMemberTypes` / `addRivalMember` (removed from `MetamorphosisPhaseII`). The dead power assignment is gone:
  power only from `recalc()`. Non-combat rosters now carry media/lawfare/corporate/political jobs (civilian AIs with a job
  rolled from the group) so their power is not zero (the old civilian/scientist roster derived 0 non-combat power).
- Strategic turn: new saved `strategicTimer` (init = 10, `generate` staggers it 1..10), `RivalCult.turn` counts down each
  cult turn; at 0: recruit chance, then pressure on the player's base by tactic (combat 10, non-combat 5, same log lines
  as before). `CultBase.rivalTurnCounter` and `runRivalTurn` removed (every rival now fires on its own timer, so total
  pressure doubles with two rivals: the user's "as now, but per rival").
- Research dead end: `RivalResearch.onSuccess` finds the base area BEFORE raising the reveal level (none found: level stays 2,
  no wasted reveal); `findRivalBaseMarker` tries quiet city area, then any with events, then any city area, never another
  rival's base area.
- Scenario `rival-lifecycle` (start BASE): generate (roster 6, level limits, combat power, stagger), strategic timer
  (nothing early, +10 pressure on the turn, reset), growth (recruits, cap, limits), research finds an area. (b) extends it.
- Build: `cd src && make` passes (62 runs, 0 failed).
- New math: starting level odds combat 30% L2 / 5% L3, non-combat 20% / 0% (each capped by the 5 L2 / 2 L3 limits);
  recruit chance 35% per strategic turn (level 1, up to cap 15); strategic period 10 cult turns; stagger 1-10;
  pressure combat 10 / non-combat 5 per rival per strategic turn.

## P5 (a) fix + (b): wipe, reward, replacement
- Fix (controller review): `RivalCult.turn` skips the base pressure (growth stays) when `cults[0].state != CULT_STATE_ACTIVE`
  or `cults[0].base == null`. `rival-lifecycle` covers both (state INACTIVE, base null: no pressure, no throw).
- Files: `src/cult/Cult.hx`, `src/cult/RivalCult.hx`, `src/cult/missions/RivalBase.hx`, `src/cult/base/CultBase.hx`,
  `src/const/CultConst.hx`, `src/test/Scenarios.hx`. (`loc/en.json` regenerated by the build.)
- `RivalBase`: the sanctum collapsing no longer wins by itself. `turn()` (player in the mission area) wins when the sanctum
  is down AND no live rival defender is left. `onSuccess`: `rival.wipe()` (members cleared, state dead, replacement
  scheduled), base resources +`RIVAL_LOOT` flesh/blood/bone each (capped by `stockpileCap`), every body in the mission area
  into Cadaverum (overflow lost, stored ones leave the floor; same text as the defense). `onFail`: 15% chance the rival
  gains one level 1 member (`RivalCult.recruitMember`, also used by growth).
- `Cult.destroy` now ends in a new overridable `onWiped()` (default: leave `game.cults`, as before). `RivalCult.onWiped` keeps
  the dead rival listed ("destroyed") and sets the saved `replaceTimer` = 30 + random 0-19 cult turns. This also covers a rival
  whose leader dies in a fight (`Cult.onDeath` → `destroy`), which used to delete the rival with no replacement.
  `RivalCult.wipe()` is the public entry (`destroy` is private).
- `CultBase.turnRivalReplacements` (called from `turn()`, each cult turn): counts the timer down on each dead rival; at 0
  `RivalCult.generate(game, tactic)` (same tactic; prefers an info no rival has used) + log "Another cult rises in the city."
- `generate` now avoids info IDs of every rival, dead ones included, and falls back to any when none is left.
- Scenario `rival-lifecycle` extended: raid does not win with a defender alive (checked by mutation: without the
  defenders-dead rule it fails), wins once none is left; rival dead, members 0, replacement timer set; loot and bodies into
  Cadaverum, none left on the floor; failed raids recruit up to the cap; the timer runs out → one more live rival.
- Build: `cd src && make` passes (62 runs, 0 failed).
- New math: loot 15 each of flesh/blood/bone; replacement 30 + random(20) cult turns; failed-raid recruit 15%.
- Questions: (1) the mission/ordeal notes still say "Destroy the rival sanctum." (RivalBase.hx, RivalAttack.hx note; N() strings,
  translations): should they say defenders too? I left them. (2) The body loading is a copy of `BaseDefenseLogic.loadBodiesIntoStorage`
  without the first-ID filter (that file is outside P5's list); say if you want it parametrized instead.
  (3) The test spawns the mission area by hand (`RivalBase` constructor makes a sewer area) and runs `turn()` from the habitat;
  the real area/spawn flow is not driven by the scenario.

## P5 (b) review fixes
- Files: `src/cult/missions/RivalBase.hx`, `src/cult/ordeals/RivalAttack.hx`, `src/cult/missions/BaseDefenseLogic.hx`,
  `src/cult/RivalCult.hx`, `src/test/Scenarios.hx`.
- Notes: RivalBase and RivalAttack `note` = N('Destroy the rival sanctum and kill its defenders.') (translation later;
  missions already in a save keep their old text).
- `BaseDefenseLogic.loadBodiesIntoStorage(game, ?firstBodyID = -1)`: -1 = the running defense's mark (callers unchanged),
  0 = every body in the area. `RivalBase.onSuccess` calls it with 0; the copy is gone.
- Wipe message: the base `Cult.log` only prints for the player cult, so the old "{cult} is destroyed, forgotten by time." line
  never showed for a rival at all. `RivalCult.onWiped` now `game.log`s T('{cult} is destroyed.') — both the raid wipe and the
  leader-death path go through it (`destroy` → `onWiped`).
- Scenario: a rival whose leader dies (`onDeath(members[0])`) stays in `game.cults` as a dead husk with a replacement timer.
- Build: `cd src && make` passes (62 runs, 0 failed).

## P6 (a)+(b): heretical ordeals, strike
- Files: ❔ `src/cult/ordeals/HereticalOrdeal.hx`, ❔ `src/cult/ordeals/RivalStrike.hx`, `src/cult/Ordeals.hx`,
  `src/cult/RivalCult.hx`, `src/cult/missions/CombatTargetsWithGuards.hx`, `reports/cult-ordeals.md`,
  `src/test/Scenarios.hx`. (`loc/en.json` regenerated by the build.) `CultBase.hx` untouched.
- `CombatTargetsWithGuards(g, info, ?rivalCultID)`: new saved `rivalCultID` (-1 default). With an ID the targets are up to 3
  real roster members of the rival (never the leader, `RIVAL_TARGETS`), spawned `setCult(rival)` so a death leaves the
  roster through `Cult.onDeath`. `rivalInfo()` is a placeholder combat info that only places the mission in a city area
  (Combat's ctor needs a valid target list; the real targets replace it). `turnTemplate` drops marked members that left
  the roster elsewhere and wins when none is left.
- `HereticalOrdeal extends ProfaneOrdeal` (the profane timer, no annul, penalty path): 8-12 turn timer, 2 level 1 members,
  flavour = the rival's strongest of media/lawfare/corporate/political, 2 flavour texts each (own table in the file).
  `check()` overridden: answered by its power OR its money OR its strike mission. `onFail`: `addPressure(5, rivalID)` +
  `addRandomBadEffect(5, 10 at 5%)`. `HereticalOrdeal.raise(game, rival)` raises one if the rival has a non-leader member,
  the cult has 2 free level 1 members and none of this rival's heresies runs.
- `RivalCult.turn`: a non-combat rival raises a heresy; no heresy possible -> the old +5 pressure at once. Combat unchanged.
- `RivalStrike extends Ordeal` (communal, 2 level 1 members, mission = `CombatTargetsWithGuards` on the rival). Offered per
  rival with `rivalRevealedLevel >= 1`, 2+ members, no strike running. Success: `recalc`, pressure -5 (floor 0). Failure: 15%
  recruit (`RIVAL_FAIL_RECRUIT_PCT`). Registered in `Ordeals` (initiate list + `rivalStrike` action).
- Scenarios `heretical-ordeal` (lone-leader rival refused, raise, one per rival, strategic turn raises with no pressure,
  blocked -> 5 pressure, three ways out through the real `spend.*` actions and the mission, timeout -> pressure + effect)
  and `rival-strike` (offered once revealed, once at a time, marked members spawn as rival cultists, kills shrink the
  roster, ordeal ends, pressure -5, failed strikes recruit within the cap). Mutation check: answering by power broken ->
  `heretical-ordeal` fails.
- Build: `cd src && make` passes (64 runs, 0 failed).
- New math: heresy price 15/10/5 power and 60000/40000/20000 money by the cult's best member level (3/2/1), no random
  spread; timer 8 + random 5; failure +5 pressure, bad effect 5 turns (10 at 5%); strike targets 3 random non-leader
  roster members; strike success pressure -5; failed strike 15% recruit.
- Decisions to confirm: (1) heretical ordeals are ORDEAL_PROFANE, so they count toward the profane limit and set the
  profane timeout like `BaseDefense` already does (a heresy can crowd out a tribulation for a cult under 6 members);
  say if they should be excluded in `Ordeals`. (2) A heresy outlives a rival wiped meanwhile (its mission just wins when
  entered). (3) Pedia/tests README not touched (P9).

## P6 review fixes
- Files: `src/cult/ordeals/HereticalOrdeal.hx`, `src/cult/Ordeals.hx`, `src/cult/missions/CombatTargetsWithGuards.hx`.
- Heresy `success`/`fail` texts are `N()` keys in the static table, `Loc.tr()`'d where shown (`onSuccess`/`onFail`), like name/note.
- `Ordeals`: a `HereticalOrdeal` is not counted in the profane limit and does not set `profaneTimeout` on success/fail (the
  base defense stays as it was). Questions (1) and (2) of the P6 entry are settled.
- `rivalInfo()` has the `ponytail:` comment (Combat's ctor needs a target list).
- Build: `cd src && make` passes (64 runs, 0 failed). No new math, no INFO lines.

## P9: tests and docs wrap
- Files: `src/test/Bot.hx`, `src/test/Scenarios.hx` (added by the controller), `src/ui/hud/FormaHud.hx`, `tests/README.md`,
  `docs/relations.md`, `TODO.md`. (`loc/en.json` regenerated by the build, +1 string `Esc`.)
- `Bot.checkBaseOrgans`: stock over `stockpileCap()`, stored bodies over the Cadaverum slots, custodes over the Cauldron slots
  are broken invariants. The slots count broken organs too (a broken organ keeps what it holds), so the 8 / 2 per level mirror
  `CultBase.bodyCapacity` / `custosCap` minus the working test (a copy of two numbers, noted in the comment).
- The first run failed two scenarios that cheat state: `base-leave-custos` (a custos pushed by hand, no Cauldron) now plants a
  Cauldron first; `defense-rival` (`cu_br_100` adds past the cap) clamps the stock to the cap after setup.
- `FormaHud`: the two bare `Esc` key labels go through `T('Esc')`.
- `tests/README.md`: scenario row lists `defense-rival`, `defense-timeout`, `ambush-base-turn`, `rival-lifecycle`,
  `heretical-ordeal`, `rival-strike` and the extended base scenarios; the invariants list has the caps.
- `docs/relations.md`: Cult core (L2 limits), Ordeals, Missions, Cult base, Rival cults, Team, the join and destruction tables
  (rivals keep a husk via `onWiped`), Copies (`rivalCultID`), Invariants (caps), History; neighbour ideas "no reward for a rival
  wipe" and "rivals act only through the base" removed (the second kept as "never draw Group attention or compete for recruits").
  Save/load row: unchanged (no new re-link: new saved fields default in `init()`).
- `TODO.md`: the stale-cult-flag entry no longer says a taken rival is never destroyed. Nothing else was done by P1-P6
  (the Porta custos craft and the pedia entries stay).
- Build: `cd src && make` passes (64 runs, 0 failed).
- New math: none.

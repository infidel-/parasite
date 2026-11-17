# Cult level 2: feature-complete (worker brief)

**Status: worker phases done (P1, P2, P3, P5, P6, P9). P4/P7/P8 run in other sessions.** (The controller updates this line at each phase boundary.)

**Controller:** session `cult-l2-controller` (`ListAgents`, `SendMessage`). You are the worker: read
`docs/worker-loop.md` § Worker first. **You never use CDP** (no `mcp__chrome-devtools__*`, no `make reload`): you
edit, build with `cd src && make`, log, report, and hold. Phases P4, P7, P8 run in other sessions, not here.

## Goal
Cult L2 (Metamorphosis → Cor Nefandum → base building → rivals) is mostly coded but can't be reached in play, and it
differs from `design.md` (repo root, the spec) in many places. Each worker phase below closes one group of gaps. Where
this brief and `design.md` disagree, this brief wins (it carries the user's decisions).

The user's decisions:
- Cult level 2 limits: member cap 15, at most 5 level 2 and 2 level 3 members (level 1 unchanged: cap 10, L2 3, L3 1).
- A failed mission against a rival changes nothing, except a 15% chance the rival gains one level 1 member.
- Save compat: the base was unreachable in every release since 0.22, so **no compat shims**. New fields get defaults
  in `init()`. The test fixture `habitat-cult-base-t108-v0.21` must keep loading (the quick tests check it).

## Rules for this job
- Code style, `T()`/`N()` and the rest come from the repo CLAUDE.md; follow it to the letter.
- Each base action keeps ONE refusal function returning its reason ('' = OK): `validateBuild`, `validateUpgrade`,
  `validateRepair`, `validateCustos`. New actions get their own. The HUD never re-implements a rule.
- Read `docs/relations.md` § Cult base and § Rival cults before touching `CultBase.turn()` or rival code.
- New game math (a roll, a formula, a modifier): list it in your phase report; the controller asks the user whether
  it gets an INFO line. Do not add INFO lines yourself.
- A new console command is three edits (handler, help block, `ConsoleCompletion.hx`), per CLAUDE.md.
- Ordeal added or changed: update its row in `reports/cult-ordeals.md` (the controller runs `make report`).
- Touch only the files listed for the phase. Anything else is a question to the controller first.
- At the end of each phase: `cd src && make` passes (build + quick headless tests). Add a `LOG.md` entry (files,
  change, build result, new math), send the controller a one-line summary, and **hold**.

## P1: unblock, save hygiene, L2 limits
Files: `src/cult/ordeals/MetamorphosisPhaseI.hx`, `src/cult/base/CultBase.hx`, `src/cult/Cult.hx`,
`src/console/Cult.hx`, `src/console/ConsoleCompletion.hx`.
- Remove the `// TODO: CURRENTLY DISABLED FOR 0.22 RELEASE` + `return;` in `MetamorphosisPhaseI.initiateAction`.
- `CultBase._ignoredFields`: add `cursorX`, `cursorY`, `selectedType`, `selectedDirection` (Forma UI state) and
  `income` (a log cache; the HUD uses `incomePerTurn()`). `init()` already defaults them; check nothing reads them
  before Forma is entered (`PlayerArea.hx` ~415 re-centres the cursor on entry).
- `Cult.maxSize()` and `Cult.getLevelLimit()` read `level`: level 2 → cap 15, L1 15, L2 5, L3 2.
- Console `cu meta 1` (marks Phase I complete) and `cu meta 2` (runs Phase II's ritual result in the current habitat,
  refused outside one, the same path the Phase II action uses). Handler + help line + completion node `meta` with a
  `[phase]` slot.
- Check: `cd src && make` passes.

## P2: base correctness pass
Files: `src/cult/base/CultBase.hx`, `src/cult/base/CultBaseOrgan.hx`, `src/const/CultBaseConst.hx`,
`src/ui/hud/FormaHud.hx`, `src/cult/ordeals/ReapTheUnwary.hx`, `src/cult/missions/BaseDefense.hx`,
`src/cult/missions/BaseDefenseLogic.hx`, `src/game/Team.hx`, `src/game/Group.hx`, `src/ai/CustosLogic.hx`,
`src/ai/FirmusCustosAI.hx`, `src/ai/MordaxCustosAI.hx`, `src/test/Scenarios.hx`.
- **Placement:** DONE, then dropped by the user (2026-11-17): footprint-only, no clearance rule.
- **Economy:**
  - Nidus Murium gets a saved `focus` (flesh/blood/bone, default flesh) and a tend row to change it: 3 of the focus
    and 1 of each other per level.
  - Cadaverum tend row "Drain a body": 1 stored body → 4 Blood, immediately (own refusal function).
  - Cor Nefandum repair costs 25% (rounded up) of its upgrade I cost, not free.
  - Corpus Basilica readiness counts working organs only.
- **Reap the Unwary:** cost is two random powers among media/lawfare/corporate/political **or** 100k money, not money
  as one of the two slots. Refuse completion without a working Cadaverum.
- **Attacks:**
  - a pressure-tick defense (no `cultID`) picks a live rival, weighted toward combat power; the generic 2 thugs +
    2 security only when no rival lives;
  - `BaseDefenseLogic`: attackers path to Cor Nefandum first and break the organs that block that path, instead of
    the nearest organ; they engage visible custodes, player cultists and the player host;
  - rival attackers' loadout scales by member level;
  - corpse loading counts only bodies from this defense and removes them from the floor after loading.
- **Old ambush paths:** a team already in `TEAM_AMBUSH` when the base forms, and the final team after the
  controller's death (`Group.hx` ~375-383), both route to `Team.spawnBaseDefenseOrdeal` while a base exists.
- **Custodes:**
  - stats per design.md § Custodes: Firmus life 26, damage 1-4; Mordax life 16, damage 3-8 (their own attack, not
    the generic animal one); ±1 STR/CON stays;
  - heal the live AI each cult turn too when the player is in the base (no heal while a defense mission is active);
  - never target the player host or preserved hosts.
- Check: extend `base-build` (clearance, rib exceptions), `base-economy` (focus, drain, heart repair, readiness),
  `base-custos` (stats); add `defense-rival` (heart path, corpse load, survived count) and `defense-timeout` (timer
  expiry ends the game).

## P3: defense organ upgrades and turret rotation
Files: `src/const/CultBaseConst.hx`, `src/cult/base/CultBase.hx`, `src/objects/base/Ribwall.hx`,
`src/objects/base/Ribgate.hx`, `src/objects/base/SpineTurret.hx`, `src/objects/base/BloodTrap.hx`,
`src/objects/base/BaseOrganObject.hx`, `src/ui/hud/FormaHud.hx`, `src/test/Scenarios.hx`.
- Ribwall, Porta, Spine Turret and Tardans: maxLevel 3, upgrade cost ×1 then ×2 (as growth organs). Per-level table:
  | organ | health | effect |
  | --- | --- | --- |
  | Murus Costarum | 18/26/34 | — |
  | Porta Costarum | 24/32/40 | bite 2-5/3-7/4-9 + Bleeding |
  | Turris Spinarum | 18/24/30 | damage 3-8/4-10/5-12; level 3 hits the first two AIs in line |
  | Tardans | 10/14/18 | `Slime` effect (the "slow"), points by level; attackers can damage it |
- A working Ribwall (and a closed Porta) blocks line of sight (`canSeeThrough`); broken ones don't.
- Turret rotation after building: a "Turn" row in the Forma tend menu (free), and an object action "Turn turret"
  outside Forma (costs one turn). Refused while broken (own refusal function).
- Check: extend `base-tend` (defense levels, rotation, LOS).

## P5: rival generator and rival model
Files: `src/cult/RivalCult.hx`, `src/const/CultConst.hx`, `src/cult/ordeals/MetamorphosisPhaseII.hx`,
`src/cult/base/CultBase.hx`, `src/cult/missions/RivalBase.hx`, `src/cult/ordeals/RivalResearch.hx`,
`src/cult/Cult.hx`, `src/test/Scenarios.hx`.
- Move `createRivalCult`, `rivalMemberTypes` and `addRivalMember` out of `MetamorphosisPhaseII` into a static
  `RivalCult.generate(tactic)`. Tuning (member count, job mix per template, level odds) goes in a table in
  `CultConst.hx`. Drop the dead power assignment: power stays derived from the roster via `recalc()`.
- Each rival takes its own strategic turn every 10 cult turns (a per-rival saved counter, staggered at creation),
  replacing the shared `CultBase.rivalTurnCounter`.
- `RivalCult.turn`: slow growth, a chance per strategic turn to recruit one level 1 member, capped.
- `RivalBase.onSuccess` needs the sanctum down **and** its defenders dead; then a proper wipe (members cleared,
  state dead) and a reward: base resources, plus the raid's bodies to Cadaverum.
- A replacement rival with the same tactic spawns some cult turns after a wipe (one combat and one non-combat rival).
- Research dead end: when no marker area is found, retry, then fall back to any city area.
- Check: scenario `rival-lifecycle` (generate → research ×3 → raid → wipe → replacement).

## P6: heretical ordeals and city strikes
Files: ❔ `src/cult/ordeals/HereticalOrdeal.hx`, ❔ `src/cult/ordeals/RivalStrike.hx`, `src/cult/Ordeals.hx`,
`src/cult/RivalCult.hx`, `src/cult/missions/CombatTargetsWithGuards.hx`, `src/cult/base/CultBase.hx`,
`reports/cult-ordeals.md`, `src/test/Scenarios.hx`.
- `HereticalOrdeal`: raised by a **non-combat** rival's strategic turn. A profane-style ordeal (clone the
  `GenericProfaneOrdeal` / profane const pattern), flavour from the rival's media/lawfare/corporate/political side.
  Timer 8–12 cult turns; countered by paying power or money, or by winning its strike mission. Failure: +5 pressure
  and a profane-style penalty.
- A **combat** rival's strategic turn adds +10 pressure (as now, but per rival).
- `RivalStrike`: communal ordeal against a rival revealed at least once, 2 members. Its mission reuses
  `CombatTargetsWithGuards` with a `rivalCultID` and spawns real roster members. Success: the killed members leave
  the roster, `recalc()`, pressure −5. Failure: nothing, except a 15% chance the rival gains a level 1 member.
- Check: scenarios `heretical-ordeal` (spawn, counter, fail → pressure) and `rival-strike` (roster shrinks).

## P9: tests and docs wrap
Files: `src/test/Bot.hx`, `tests/README.md`, `docs/relations.md`, `TODO.md`, `src/ui/hud/FormaHud.hx`.
- Bot invariants: base stock ≤ cap, stored bodies ≤ capacity, custodes ≤ cap.
- The bare "Esc" literals in `FormaHud.hx` go through `T()`.
- `tests/README.md`: every new scenario. `docs/relations.md`: the Cult base, Rival cults, Ordeals, Team and Save rows,
  the cult destruction table, and remove the neighbour ideas that shipped. `TODO.md`: drop what's done.
- Pedia articles are drafted by the controller with the user, not here.
- Check: `cd src && make` passes; tell the controller to run `make test` (full soak).

## Log
`docs/jobs/cult-l2/LOG.md`: one entry per iteration (phase, files, change, build result). The controller commits.

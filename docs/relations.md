# Relations: how the game's systems touch each other

The game's systems are coupled through **lifecycle events**: an AI dies or despawns, an area is
entered or left, a cult is destroyed, a save is loaded. Most cross-system bugs have one shape: an
event got a second entry point, and a listener was wired into only the first. A cultist host fed to
the ovum skipped the cult roster because `AI.dieRegion` had no cult listener that `AI.die` reached
through `AreaGame.removeAI`. This file maps the events, their entry points and their listeners, and
records the invariants that make an empty cell safe.

Read it before planning or reviewing a game change. It is a living document: a change that adds an
entry point, a listener, a copy or an invariant updates its row in the same commit.

## How to use it

A plan for a game change carries this block:

```
Relations: <the event rows and systems below it touches>
Neighbours: must update: <correctness: a listener or copy that would go stale>
            could update: <ideas: a neighbour that could plausibly react, see Neighbour ideas>
Invariants offered: <a rule that, made true, lets the change touch fewer neighbours>
Web delta: +<edges added> / -<edges removed>
```

- **Prefer the variant with the fewest new edges.** A change that must touch more than a couple of
  neighbours is a smell. Look for an invariant or a choke point that removes the need first, and if
  the storm is unavoidable, say why.
- **Ask before editing a neighbour.** The Neighbours block is a proposal.
- **A new lifecycle entry point gets a scenario** in the headless tests (`tests/README.md`). **A new
  invariant goes into `Bot.check`** when it is cheap to assert.
- Cell marks: ✓ reached · ✗ not reached · **SAFE** (an invariant elsewhere covers it, named) ·
  **GAP** (a confirmed bug, filed in `TODO.md`) · **PLAUSIBLE** (read, not traced end to end).
- References are `Class.method`, never line numbers. Line numbers go stale with every commit.

## Keeping the web small

- **Forbid over handle.** One lock removes a whole column. A custos cannot be possessed
  (`BaseCustosAI.canAttach`), so no host-death path has to update the custodes; a mission area
  cannot be left (`AreaGame.canLeave`), so a mission target never dies on the region map.
- **Derive, or validate on read, over storing.** Every stored copy is a sync obligation on every
  event. An id that the reader checks against the live object needs no listener when the object
  goes away.
- **One choke point per event.** Two entry points with two listener lists drift apart.
- **A local fix over a cross-system patch.** Fix the state in the system that owns it.
- **Explicit calls, no core event bus.** One choke point with direct calls stays greppable.
  `ModEventRegistry` is for mods only; core code fires it but never subscribes.

## Systems

`S` = saved by the reflection `Saver`, `¬S` = not saved. "Out" are the systems it calls, "In" the
ones that call it.

**Game core**: `game/Game.hx`
- Owns turns, state, location, messageList, modData (S); `region`, `area`, `jobs` (¬S).
- Three orders are hardcoded and a new system joins all three: creation (`Game.init`), turn
  (`Game.turnInternal`: TURN_PRE → player → group → each cult (cult time ×5 on the region map) →
  area → managerArea → goals → visibility → TURN_POST) and load (`Loader`, below).
- `Game.setLocation` fires AREA_LEAVE/AREA_ENTER and autosaves. `Game.beginRebirth`/`endRebirth`.

**Save/load**: `Saver.hx`, `Loader.hx`, `game/AreaGameSaver.hx`
- The Saver walks every field by reflection, skips `game`/`ui` and each class's static
  `_ignoredFields`, and silently drops any class instance not extending `_SaveObject`.
- For `ai.*` and `objects.*` the Saver reads `_ignoredFields` from the `AI`/`AreaObject` base
  class; any other subclass needs its own list.
- Post-load order: timeline → goals → world → managerArea → group → playerArea → player → sounds →
  each cult → `Loader.rebuildAIDataMaxID`.

**Player**: `game/Player.hx`, `PlayerArea.hx`, `PlayerRegion.hx`, `Command.hx`
- Owns energy/health, state, host/hostID, hostControl, vars, skills (S); `command`,
  `PlayerArea.currentAction` (¬S). At `game.player`, `game.playerArea`, `game.playerRegion`.
- Host death has three layers: `Player.onHostDeath(msg)` (affinity loss, tutorial goals, pedia) →
  `PlayerArea.onHostDeath` / `PlayerRegion.onHostDeath` → `AI.die` / `AI.dieRegion`.
- Out: nearly everything. Pedia: basics, lifeParasite, movement, hostInvading, hostExpiry,
  hostAffinity, hostAssimilation, regionMode, hud*, keyboardShortcuts, spoonMode, sandboxMode.

**Evolution**: `game/EvolutionManager.hx`, `game/Improv.hx`, `const/EvolutionConst.hx`
- Owns improvements, current task, `ovum` (S). At `game.player.evolutionManager`.
- Out: goals, log, ui. In: Player, Ovum, Organs, items (Readable, Computer, Contraceptives).
  Nothing in `cult/` touches it.
- Hooks: `ImprovInfo.onUpgrade`/`noteFunc`. Pedia: evolution. SDK: `registerEvolution`.

**Ovum and rebirth**: `region/Ovum.hx`, `Player.death`, `Game.beginRebirth`
- State in `evolutionManager.ovum` (S); the ovum region object is in the region object list.
- `Ovum.nurtureOvumAction` enters host death at the middle layer (`PlayerRegion.onHostDeath`), so no
  affinity loss, which matches the other voluntary sacrifice (`Habitat.putObject`).
- Hidden: nurture points per host type; rebirth gives each improvement a 50% chance to lose a
  level, +9 turns, and the ovum loses a level; a host the parasite died in is left behind
  (`Player.releaseHost`). Rebirth notifies nobody else. Pedia: impOvum.

**Habitat**: `game/Habitat.hx`, `objects/HabitatObject.hx` and the habitat organs
- Owns energy balance, regen, watcher (S, as `AreaGame.habitat`).
- Destruction lives in `Team.destroyHabitat`: habitatsLeft--, a max-energy shock, maybe
  `Player.death('habitatShock')`. Never the base habitat: the team attacks the base instead.
- Pedia: habitat, habitatCavity, habitatBiomineral, habitatDestruction, habitatWatcher,
  habitatPreservator.

**Host body**: `game/Organs.hx`, `game/Effects.hx`, `effects/*`, `game/Skills.hx`, traits
- Saved per `AIData` and player. Organ hooks `OrganInfo.onGrow`/`onAction`; effect hooks
  `Effect.turn`/`onRemove`/`damageMods`; `AI.onEffect`.
- `Organs._ai` and `Effects.ai` are parent links: a shallow AIData copy shares them (see Copies).
- Pedia: hostOrgans, hostBrainProbe, hostSkills, hostAttributes. Hidden: almost every status
  effect (bleeding, panic, berserk, drunk, withdrawal, paralysis…). SDK: `registerTrait`,
  `registerSkill`.

**Chat**: `game/Chat.hx`
- Owns difficulty (S). At `game.player.chat`.
- Out: group (subvert), cults[0] (recruit, `addLeader`), timeline (clues), the current area's
  mission (`ON_AI_MAX_CONSENT`). Pedia: hostConversation.

**Items**: `items/*`, `game/Inventory.hx`
- Saved per AI and player. Hooks `ItemInfo.onLearn`/`action`; mod ITEM_LEARN.
- Out: player, timeline (Readable, Computer), goals, group (Dossier intel). Pedia: hostInventory.
  SDK: `registerItem`.

**Area objects**: `objects/*`, `objects/base/*`, `objects/mission/*`
- Saved in `AreaGame` (entity ¬S). Many dynamic hooks on `AreaObject` (`frob`, `turn`,
  `onDecay`, `onAction`, `onDamage`, `isWalkable`).
- Out: player, area, region, cults (Necronomicon, CorNefandum, CloneVat), setLocation.
  `BodyObject` feeds `RegionManager.onBodyDiscovered`.

**Group, team, director**: `game/Group.hx`, `Team.hx`, `GroupDirector.hx`, `ai/TeamMemberAI.hx`,
`ai/BlackopsAI.hx`, `ai/AgentAI.hx`
- Owns priority, intel, isKnown, isNeutralized, director fields; team level/size/distance/state
  (S). At `game.group`, `game.group.team`.
- Priority comes from AreaManager law and backup calls, RegionManager host and body discovery,
  area alertness above 25, team member despawn, the GroupInterference and BuryTheFile ordeals.
- Out: goals, area, cults[0] (`Team.spawnBaseDefenseOrdeal`: also from `Team.turn` for a team already in
  `TEAM_AMBUSH` when a base exists), player (habitat shock).
- Pedia: group, groupBasics, groupPriority, teamAmbush, teamBasics, teamDeactivation,
  impFalseMemories, groupNeutralize, msgWatching. Hidden: priority spillover from alertness; a team
  wipe makes the next team start at 1.5× distance.

**Cult core**: `cult/Cult.hx`, `cult/Effects.hx`, `cult/effects/*`
- Owns members (AIData copies, leader is `members[0]`), power, resources, level, base,
  trainingMemberIDs (S). At `game.cults[0]` (the player's), `getCultByID`, `getRivalCults`.
- Ticks every 10 player turns, paused in mission areas. Size limits by level (`maxSize`,
  `getLevelLimit`): level 1 cap 10 (L2 3, L3 1); level 2 cap 15 (L2 5, L3 2). Rivals use the same limits.
- Death chain: `AreaGame.removeAI` or `AI.dieRegion` → `Cult.onRemoveAI` / `Cult.onDeath` →
  `Ordeals.onDeath`; the leader's death runs `Cult.destroy`.
- Pedia: cult, cultBasics, cultPowerResources, cultCommands, cultBazaarNet. SDK: none.

**Ordeals**: `cult/Ordeal.hx`, `Ordeals.hx`, `ProfaneOrdeal.hx`, `cult/ordeals/*`
- Owns the ordeal list, profaneTimeout, per-ordeal members/power/missions (S). Rows in
  `reports/cult-ordeals.md`.
- Hooks: `onDeath` (fails the ordeal unless overridden), `check`, `turn`, `onSuccess`, `fail`,
  `getActions`, `onTimerTick`.
- Out: timeline (GatherClues), goals, group, getRivalCult*. MetamorphosisPhaseII (a three-stage ritual
  pinned to a habitat, a vision per stage) creates the base and the first rivals (`RivalCult.generate`). `HereticalOrdeal` (a profane ordeal a non-combat rival
  raises; answered by power, money or its strike mission; not counted in the profane limit, sets no
  `profaneTimeout`) and `RivalStrike` (communal, against a revealed rival) are the ordeals that
  reach into a rival's roster. Pedia: cultCommunalOrdeals, cultProfaneOrdeals.

**Missions**: `cult/Mission.hx`, `cult/missions/*`
- Saved inside their ordeal. Hooks `turn`, `turnPreAI`, `turnAI` (can take over an AI before its
  own logic), `onSuccess`, `onFail`, `onEventAI` (ON_AI_DEATH, ON_AI_MAX_CONSENT only), `isTarget`
  (the mission mark).
- `CombatTargetsWithGuards(rivalCultID)` spawns real roster members of a rival (`setCult(rival)`), so a
  kill leaves the roster through `Cult.onDeath`; `RivalBase` wins only with the sanctum down and its
  defenders dead (`RivalCult.wipe`); both defense missions end on the next `turn()`, so the last
  attacker's body is counted.
- `AreaGame.getAreaMission` finds the current area's mission; `AreaGame.canLeave` locks the area
  until it completes. Pedia: cultCombatMissions.

**Cult base**: `cult/base/*`, `objects/base/*`, `ai/CustosLogic.hx`, BaseDefense missions
- Owns resources, storedBodies, organs, custodes, attackPressure, defense id and timer (S). At
  `game.cults[0].base`. Losing Cor Nefandum ends the game.
- Created only by `MetamorphosisPhaseII` at its third ritual stage, in the habitat the ritual is
  pinned to (console `cu meta 2` skips the stages, in the current habitat). Pedia: none.
- Attacks: `addPressure` (no `cultID`) picks a live rival weighted by `1 + combat power`, the generic
  thugs only when none lives; `startDefense` registers the ordeal, mission id, timer and
  `defenseFirstBodyID` (only bodies made since count). `BaseDefenseLogic` routes attackers to Cor Nefandum
  through the organs on the way. `Team.turn` turns a `TEAM_AMBUSH` into a base defense while a base
  exists; the final team after the director's death does the same.
- Defense organs (Murus, Porta, Turris, Tardans) have 3 levels; a working Murus or Porta blocks sight.
  Custodes heal +1 per cult turn (live in the base, records elsewhere, none during a defense) and never
  target the host. Rivals reach it through `CultBase.turnRivalReplacements` (a dead rival's replacement).
- Saved fields added with no compat shim (the base was unreachable before): organ `focus`,
  `defenseFirstBodyID`; Forma's cursor state and `income` are `_ignoredFields`.
- Each base action has ONE refusal function returning its reason ('' = OK): `validateBuild`,
  `validateUpgrade`, `validateRepair`, `validateCustos`; the actions log that reason and the Forma HUD
  (`ui/hud/FormaHud.hx`, chip, tend menu, 3D ghost) shows it, never re-deriving a rule. Income lives in
  the pure `incomePerTurn()`, which `turn()` applies and the ledger previews.
- 3D: an organ's prop key (`BaseOrganObject.getModelKey`) carries its direction and its broken state
  (the `_broken` ruin rows, `ObjModels.withRuins`). `CultBase.refresh3D` rebuilds the props after a
  break, repair, upgrade or turn, the only changes that change a key; `CultDetail` lays the ruin decals (and
  fades one back out on repair). `CultBase.fx3D` plays the destroy/repair/mend/upgrade animation
  (`OrganFxKind` → `GameScene.organFx` → `render.particles.OrganFx3D`); a DESTROY plays INSTEAD of
  `refresh3D` and rebuilds the props itself when its slump lands (falls back to `refresh3D` off screen).
  `CultBase.birth` (from `MetamorphosisPhaseII.onSuccess`) runs `refresh3D` + a BIRTH fx with an
  `onDone`: the heart's object is made inside the `CultBase` constructor, before `cult.base` is set, so
  its key resolves to no prop and `AreaGame.addObject` skips the rebuild until `birth` forces one.
- Scenarios: `base-build` (every organ, Porta over Murus, refusals), `base-tend` (upgrade, heart,
  repair, defense levels, turret turn, sight), `base-custos` (craft, cap, respawn, stats, heal),
  `base-economy` (income per organ, focus, drain, bodies, cap, pressure), `defense-rival`,
  `defense-timeout`, `ambush-base-turn`.

**Rival cults**: `cult/RivalCult.hx`, `RivalAttack`/`RivalResearch` ordeals, `RivalBase` mission
- Owns template, tactic, revealed level, base area id, `strategicTimer`, `replaceTimer` (S, inside
  `game.cults`). Built by `RivalCult.generate(game, tactic)` from the `CultConst.tunings` table.
- `RivalCult.turn`: each rival has its own strategic turn every 10 cult turns: a chance to recruit one
  level 1 member (`recruitMember`), then, when the player cult is active with a base, a combat rival
  adds +10 pressure and a non-combat one raises a `HereticalOrdeal` (+5 pressure at once when none can
  be raised). A wiped rival stays listed as dead (`onWiped`) and `CultBase.turnRivalReplacements`
  generates one of its tactic 30-49 cult turns later. Pedia: none.
- Scenarios: `rival-lifecycle`, `heretical-ordeal`, `rival-strike`.

**Timeline**: `scenario/Timeline.hx`, `Event.hx`, `Location.hx`, `NPC.hx`, `Scenario*.hx`
- Owns events, locations, names, variables (S; maps rebuilt on load). At `game.timeline`.
- In: Chat, Readable/Computer items, EventObject, PlayerArea, the GatherClues ordeal, AI (npc).
- `NPC.ai` is a pointer (¬S) re-linked by `AI.loadPost`/`AI.setNPC`. Pedia: eventTimeline,
  gameplay.

**Goals**: `game/Goals.hx`, `const/Goals.hx`, `scenario/GoalsAlienCrashLanding.hx`
- The main data-driven hook system: `onTurn`/`onReceive`/`onComplete`/`onFailure`/`onEnter`/
  `aiInit`/`leaveAreaPre`. Pedia: hudGoals. SDK: `registerGoal`.

**Area managers**: `game/AreaManager.hx` (S queue), `RegionManager.hx`, `WorldManager.hx` (¬S)
- Event types: CALL/ALERT/ARRIVE_LAW, CALL/ARRIVE_(TEAM_)BACKUP, OBJECT_DECAY, ARRIVE_CULTIST.
- Out: group priority, `Cult.onArriveCultist`, playerArea. Pedia: npcAlertness, areas.

**AI behaviour**: `ai/AI.hx` (+ `AIData`), all `*AI.hx`, `CommonLogic`, `DefaultLogic`,
`FollowerLogic`, `CommandLogic`, `CustosLogic`
- Dispatch order: `cults[0].turnMissionAI` → custos → player cultist (command, then follower) →
  default.
- Dynamic hooks: `onStateChange`, `onAttack`, `onInvade`, `onBrainProbe`, `onRemove`, `onDeath`,
  `onNotice`, `canAttach`, `attachPre`, `updateActionList`, `action`. SDK: `registerAI`, AI_SPAWN,
  AI_DIE_PRE, AI_DIE.

**World, region, area**: `game/World.hx`, `RegionGame.hx`, `AreaGame.hx`, `region/RegionObject.hx`
- Saved (area cells compacted). `AreaGame.enter`/`leave` are the area choke points (below).
- Pedia: areas, areaCity, areaHighCrime, areaCorp, areaMilitary, areaLab, areaUninhabited.

**Area generation**: `src/gen/*`, `game/*AreaGenerator.hx`. Reads world and region; see
[`area-gen.md`](area-gen.md).

**Mods**: `src/mods/*`. `ModContentRegistry` (items, pedia, traits, skills, improvements, goals, AI
types, area actions); `ModEventRegistry` (turn pre/post, area enter/leave, ai spawn/die-pre/die,
item learn, game finish-pre); `game.modData` (S). Externs in `parasite-mod-sdk/externs/mods/`.

**Console**: `src/console/*`. Debug commands into every system; owns no state.

**Headless tests**: `src/test/Bot.hx`, `src/test/Headless.hx`, `tools/test.mjs`. `Bot.check` asserts
the invariants below after every bot step. See [`tests/README.md`](../tests/README.md).

## Lifecycle events

### AI death

One listener list: **`AI.notifyDeath`** (the AI's `onDeath()` hook, `npc.isDead`, the area mission's
`ON_AI_DEATH`, mod `ai:die` in an area / `ai:die-region` on the region map). Every death path calls
it, so a new death listener goes there and reaches them all. The cult and custodes records are
synced on removal (`AreaGame.removeAI`); the region path has no removal and syncs the cult itself.

| step | H1 `AI.die` (area, via `PlayerArea.onHostDeath` for the host) | H2 `AI.dieRegion` (region host: expiry, degradation, bleeding) | H3 `Ovum.nurtureOvumAction` (→ H2) | H6 `Habitat.putObject` (host grown into an organ) |
|---|---|---|---|---|
| `Player.onHostDeath` (affinity, tutorial goals, pedia) | ✓ host | ✓ | ✗ SAFE: voluntary sacrifice, matches H6 | ✗ same |
| `Cult.onDeath` → `Ordeals.onDeath` | via `AreaGame.removeAI` → `Cult.onRemoveAI` | ✓ direct | ✓ | via `removeAI` |
| custos `CultBase.onRemoveAI` | via `removeAI` | ✗ SAFE: `BaseCustosAI.canAttach` is false | ✗ same | n/a |
| `AI.notifyDeath` | ✓ | ✓ | ✓ | ✓ (G6, fixed) |
| ↳ mission `ON_AI_DEATH` | ✓ current area | ✗ SAFE: a mission area can't be left | ✗ same | ✓ |
| mod `ai:die-pre` (live entity, attacker) | ✓ | ✗ no entity | ✗ same | ✗ no corpse |
| body, targeting clear, enemies purge | ✓ | n/a | n/a | via `removeAI` (no body: the organ replaces it) |

H4 (`AI.onDamage` host branch) and H5 (`PlayerArea.onDamageHost`) run `AI.die` and match H1.
Bleeding on the region map enters H2 at the top layer (`Player.onHostDeath`), never through
`AI.onDamage`, whose alert, sound and `AI.die` are area code. `Player.death` in host state (only
`habitatShock`) releases the host first (`Player.releaseHost`): in an area it stays behind alive and
despawns with the rebirth's leave (D4); on the region map it walks off and its NPC is unlinked (P6,
fixed: the parasite was reborn still inside it). No mission area is in play: the Group pauses there,
so no habitat shock fires in one. Scenarios: `ovum-leader`, `ovum-member`, `expiry-member`,
`organ-npc`, `region-effects`, `rebirth-region`, `rebirth-area`.

### AI despawn (removed alive)

Entry points: D1 `AI.checkDespawn` (idle, unseen 5 turns), D2 `CommandLogic` leave-area command,
D3 `PoliceAI`/`SecurityAI.onStateChange` (backup goes idle), D4 `AreaGame.leave` (everything not
PRESERVED, the host too), D5 `Cult.clearCultistsInHabitats`, D6 `Team.destroyHabitat` (drops the
area, no `removeAI`). All but D6 go through `AreaGame.removeAI`.

| listener | D1–D3 | D4 leave | D5 | D6 |
|---|---|---|---|---|
| `AI.onRemove` (alive, not host, player in the same area, not a teardown): `HumanAI` → `RegionManager.onHostDiscovered`; `TeamMemberAI` → group; `BlackopsAI` → `Team.checkFightFinish` | ✓ | ✓ (not the host) | ✗ other area | ✗ |
| `npc.ai = null` | ✓ | ✓ | ✓ | ✗ stale pointer |
| `Cult.onRemoveAI` → `AIData.updateData` | ✓ (D2) | ✓ | ✗ SAFE: flag cleared first | ✗ record kept, live copy lost |
| custos `CultBase.onRemoveAI` | n/a (guards) | ✓ | n/a | ✗ |
| mission target copies | ✗ SAFE: a mission target never despawns (`AI.checkDespawn` asks `AreaGame.isMissionTarget`; P2, fixed: it came back from its stale record) | ✗ SAFE: a mission area can't be left | n/a | n/a |
| BaseDefense `targetIDs` | ✗ SAFE: a wave with none left alive is spawned anew (`BaseDefenseLogic.waveGone`; G8, fixed) | ✗ same (rebirth walks you out) | n/a | n/a |
| `Targeting.target` | ✓ `AreaGame.removeAI` (P9, fixed: a despawned target could still be attacked from its last tile) | ✓ | ✓ | n/a |
| mod event | ✗ none exists (Neighbour ideas) | ✗ | ✗ | ✗ |

`RegionManager.onHostDiscovered` reports an NPC host dead ("had suffered a fatal accident") and
sets `npc.isDead` (G7, fixed: it used to leave the NPC alive to respawn). `BlackopsAI.onRemove`
does not call super: SAFE by design, a former blackops host needs no report, since the team it
belongs to already hunts the player (P12). Scenarios: `despawn-target`, `kill-target`.

### Area enter and leave

Enter: N1 `Game.setLocation(LOCATION_AREA)` → `AreaGame.enter` (travel, habitat, mission area,
teleport); N2 `Game.init` → `AreaGame.enter` (new game); N3 load → `AreaGame.currentAreaLoadPost`.
Leave: X1 `Game.setLocation(LOCATION_REGION)` → `AreaGame.leave`; X2 `Game.restartPre` →
`AreaGame.leave` (restart and load).

| listener | N1 | N2 | N3 |
|---|---|---|---|
| `Team.onEnterHabitat`, `Goals.onEnter`, `cults[0].onEnterArea` → `CultBase.onEnterArea` (custodes respawn) | ✓ | ✓ | ✗ SAFE: director and custodes are saved in the area AI list |
| host re-added to `_ai` | ✓ with `_ai.add`; SAFE: `removeAI` never unlinks the player's host from its NPC (G5, fixed: a second AI spawned for the same NPC) | n/a | via `Player.loadPost` |
| mod AREA_ENTER, autosave | ✓ | ✗ by design: nothing is entered; a mod needs new-game and load events of its own (Neighbour ideas, P7) | ✗ same |

| listener | X1 | X2 |
|---|---|---|
| body discovery → `RegionManager.onBodyDiscovered` (not in habitats) | ✓ | ✗ SAFE: a teardown runs no gameplay (below) |
| `removeAI` on everything not PRESERVED (= D4) | ✓ | ✓ without the `AI.onRemove` hooks |
| `Team.onLeaveArea` (escape, `destroyHabitat`, ambush → search) | ✓ | ✗ SAFE: teardown (P8, fixed: a load during a habitat ambush burned the habitat of the game it discarded, and at the last habitat could finish the run and delete the autosave) |
| `AreaManager.onLeaveArea`, `cults[0].onLeaveArea` | ✓ | ✗ SAFE: teardown |
| mod AREA_LEAVE, autosave, `RegionGame.updateAlertness` | ✓ | ✗ |

X2 is a teardown: `Game.restartPre` clears `game.isInited` before it leaves, and `AreaGame.leave`
and `AreaGame.removeAI` run their gameplay listeners only while it is set. Scenario:
`load-habitat-fight`.

A final habitat shock inside `Team.onLeaveArea` (X1) runs the rebirth's `Game.setLocation` inside
the outer one, while `game.location` is still the area: the inner leave meets the parent cell, which
`RegionGame.removeArea` made `game.area`, and finds nothing left to do. SAFE, but only by that
accident.

Only `cults[0]` gets enter/leave: SAFE, because rivals have no base, ordeals or missions.

Leave checks, run by every exit object and `PlayerArea.leaveAreaAction`: `AreaGame.canLeave`
(mission lock, `Goals.leaveAreaPre`), `Cult.leavePre` (each follower 10% death). The habitat exit
also refuses with outsiders present; preserved AIs, the host and custodes are not outsiders (G4,
fixed: custodes kept the player in the base habitat). `Game.beginRebirth` skips every check.

### Habitat

| phase | entry point | not notified |
|---|---|---|
| create | `PlayerRegion.createHabitatAction` | — |
| enter | `PlayerRegion.enterHabitatAction` → N1, plus `Team.onEnterHabitat` | — |
| leave | `PlayerArea.leaveAreaAction` / `HabitatExit` | — |
| destroy | `Team.destroyHabitat` (from `Team.turnAmbush`, `Team.onLeaveArea`) | the AIs inside (no `removeAI`); missions marked there. Never the base habitat: the team turns on Cor Nefandum instead (`Team.spawnBaseDefenseOrdeal`; P1, fixed: an ambush laid before the base grew burned it, and the save then failed to load). Scenario: `ambush-base` |

### Host attach, invade, detach

- Attach `PlayerArea.attachToHostAction` checks armour, `AI.canAttach` (false for custodes and the
  choir), `AI.attachPre`. Invade `PlayerArea.invadeHostAction` → `AI.onInvadeWrapped`. No cult or
  mission listener: the cult checks the host by id instead.
- Detach while the host lives (`leaveHostAction`, tear-away, control loss, blackout) always runs
  `AI.onDetach` then `PlayerArea.onDetach`: symmetric. No detach exists on the region map.
- `AssimilationCavity.onAction` adds a trait; nothing listens, and the cult copy catches up at the
  next `removeAI`.

### Cult membership and destruction

| join path | limits | ACTIVE | live flags | recalc |
|---|---|---|---|---|
| `Cult.addLeader` (`Chat.recruit`, console) | ✗ | ✓ | ✓ | ✓ |
| `Cult.addMember` (`Chat.recruit`) | ✓ | ✗ | ✓ | ✓ |
| `Cult.addAIData` (`RecruitFollower.onSuccess`, never live) | ✓ | ✗ | n/a | ✓ |
| `RivalCult.addRosterMember` (`generate`, `recruitMember`) | ✓ | set in `generate` | temp AI | once |

A member leaves only by dying (`Cult.onDeath`); a rival's also by a won `RivalStrike`, whose targets are
real roster members, so a kill is an ordinary death. `trainingMemberIDs` and BlockCultist targets go
stale until they expire.

| listener | `Cult.destroy` (leader died) | `RivalBase.onSuccess` (rival base taken) |
|---|---|---|
| entry | `Cult.onDeath` of `members[0]` | `RivalCult.wipe` → `destroy` (the same path) |
| state → DEAD | ✓ | ✓ |
| members, effects, ordeals wiped | ✓ (no fail/success hooks run) | ✓ same |
| removed from `game.cults` | the player cult never; a rival no: `RivalCult.onWiped` keeps the dead husk and sets `replaceTimer` | same |
| flags cleared in `game.area` and habitats | ✓ | ✓ same |
| `player.host` flag on the region map | ✗ SAFE: members only die on screen, so the host is in the cleared area or is the one dying | ✗ same |
| base defense | ✓ the defense id is cleared with the ordeals; a team in TEAM_BASE_DEFENSE calls the attack off on its turn (`Team.turn`; G3, fixed) | n/a |
| ordeals pointing at the rival (`RivalAttack`, `HereticalOrdeal`, `RivalStrike` in the PLAYER cult) | kept: a heresy's mission wins when entered, the others find no live rival | same |

The `MetamorphosisPhaseII` channel action refuses outside a habitat, or in a habitat other than the
one the ritual is pinned to (its `areaID`), and keeps the ordeal (G11, fixed: `Ordeal.success`
removed it whatever `onSuccess` did). A stage counts when its animation ends
(`GameScene.ritualFx`, at once with no 3D view), so a save mid-animation drops it. The third stage
succeeds at once; its vision opens from `onSuccess`, and enduring it plays the heart's birth, after
which the base message shows (`cu meta 2` skips straight to the birth). The ritual is no
`Mission`: one would make its habitat a mission area, locked and pausing the cult and Group, while
leaving the habitat has to suspend it instead. Scenarios: `phase2-outside`, `phase2-ritual`.

### Missions and ordeals

| listener | `Mission.success` | `Mission.fail` | profane timer out | member death | `Cult.destroy` |
|---|---|---|---|---|---|
| subclass `onSuccess`/`onFail` | ✓ | ✓ | ✓ | via `Ordeal.onDeath` → `fail` | ✗ |
| removed from `Ordeals.list` | via `Ordeal.check` | ✓ | ✓ (`Ordeals.turn` iterates a copy; G9, fixed) | ✓ (iterates a copy) | wiped |
| mission site area removed | only through exit objects | same | ✗ | ✗ | ✗ |

`ON_AI_DEATH` has one sender, `AI.die`, to the current area's mission. `ON_AI_MAX_CONSENT` comes
only from Chat. Mission targets: Kill/Persuade hold an AIData and respawn from it; Combat respawns
missing targets (`Combat.getMissingTargets`); BaseDefense/TeamBaseDefense hold ids only and cannot
respawn (G8). Every ordeal fails when a locked member dies: `Ordeal.onDeath` defaults to `fail()`
(P3, fixed: four ordeals kept the dead member and its action slot). Scenario: `ordeal-member-dies`.

The mission mark is derived, not stored: `AreaGame.isMissionTarget` asks the area's open mission
(`Mission.isTarget`: Kill, Persuade, Combat), so it holds across a load and ends with the mission
(fixed: a flag on the render entity was lost on every load).

### Turn ticks: area vs region

| system | area turn | region turn |
|---|---|---|
| `Player.turn` (energy, affinity, organs, evolution) | ×1 | ×5 |
| `PlayerArea.turn` (control, AP) / `PlayerRegion.turn` (control +25, `chatTurn(5)`) | area | region |
| `Group.turn` | ×1 | ×1, not scaled: design, the region map slows the Group (P5) |
| `Cult.turnInternal` | cult time 1 | cult time 5 |
| `AI.turnInternal` (effects, traits, logic, despawn) | area AIs and host | ✗ |
| host effects | via `AI.turnInternal` | ×5 via `PlayerRegion.turn`: timers and stats only; attacks, sounds, alerts and splats are area code and skip (P4, fixed: effects froze) |
| mission `turnPreAI`/`turn`/`turnAI` | mission area | ✗ |
| `Goals.turn` | ✓ | ✓, not scaled |
| alertness decay | current area −0.1, only with nobody alerted | every area −1 |

Group and cult pause in mission areas.

### Save and load re-links

| system | re-links after load |
|---|---|
| `Timeline.loadPost` | event/location maps, `area.events`, `npc.event` |
| `World.loadPost` → `AreaGame.loadPost` → `AI.loadPost` | region by id, `_maxID`s, `npc.ai`, `Organs.currentOrgan` |
| `AreaManager.loadPost`, `Team.loadPost` | `AreaEvent.ai` by id, `ambushedHabitat` by area id |
| `PlayerArea.loadPost` | `attachHost` by id |
| `Player.loadPost` | area: host by `hostID`; region: keeps the saved copy and runs `host.loadPost`, since no area holds it (G2, fixed: organ growth stopped) |
| `Cult.loadPost` (per cult) | raises `Mission._maxID` past its own missions, never below an earlier cult's (G1, fixed: a per-cult assignment let the last cult win) |
| `Loader.rebuildAIDataMaxID` | the AIData counter over areas, habitats, host and cults, run last |

Every id counter is static (¬S): `Game.restartPre` resets them all, and the load raises each past
the ids it finds. `Bot.check` asserts that every counter is above every live id.

## Copies and ids

`AIData.cloneData`/`AIData.updateData` are **shallow**: inside a session a copy shares inventory,
skills, organs, effects, traits and chat with the live AI. An AI spawned from a copy therefore
would share an `Organs` whose `_ai` points at the old AI: `AIData.updateData` re-parents the
organs and effects it copies (G10, fixed: a possessed summoned cultist grew organs on the wrong
body).

| holder | stores | synced by | stale when |
|---|---|---|---|
| `Cult.members` | AIData | `Cult.onRemoveAI` (despawn, death), `AI.dieRegion` | habitat destroyed (record kept) |
| `CultBase.custodes` | CustosAIData | `CultBase.onRemoveAI`, respawned by `CultBase.onEnterArea` | habitat destroyed |
| `Kill.target`, `Persuade.target` | AIData | ON_AI_DEATH | — (a mission target never despawns) |
| Combat `targets`/`targetIDs` | AIData + ids | ON_AI_DEATH, `Combat.getMissingTargets` | — (guards don't despawn) |
| BaseDefense `targetIDs`, `CultBase.activeDefenseMissionID` | ids | ON_AI_DEATH, the missions' `onSuccess` | — (fresh wave, cleared by `Cult.destroy`) |
| `CombatTargetsWithGuards.rivalCultID` (a strike's targets) | rival id + member ids | `Cult.onDeath` (roster); the mission drops marked members that left | — (a wiped rival stays listed as dead) |
| `RecruitFollower.target` | AIData, never live | — | — |
| `Ordeal.members` | member ids | `Ordeal.onDeath` fails the ordeal | — |
| `Targeting.target` | AI pointer | cleared by `AreaGame.removeAI`, `Game.setLocation`, `PlayerArea.onDetach` | — |
| `Group.directorID` | id | `AgentAI.onDeath`; SAFE: `GroupDirector.onEnter` reassigns on every visit | — |
| `NPC.ai` | pointer (¬S) | `AI.setNPC`, `AI.loadPost`, cleared by `removeAI` | `Team.destroyHabitat` |
| `Player.host`/`hostID` | pointer + id | invade, `onDetach`, host death | — |
| `AreaEvent.ai` | pointer + id | pruned when the event fires | despawn (still fires) |
| `AI.enemies` | ids | purged by `removeAI` | — |
| id counters `AIData`/`Mission`/`RegionObject`/`NPC`/`Cult`/`CultBaseOrgan._maxID` | statics (¬S) | reset by `Game.restartPre`, raised on load | — |

## Invariants

| invariant | relied on by | enforced at | asserted |
|---|---|---|---|
| a custos is never a host | host-death paths skip the custodes | `BaseCustosAI.canAttach` | no (structural) |
| a mission area can't be left until its mission completes | mission targets never die on the region map | `AreaGame.canLeave` (not `Game.beginRebirth`) | no (structural) |
| the player cult is `cults[0]`; only it has a base, ordeals and missions | enter/leave notify only `cults[0]` | `Game.init`, `MetamorphosisPhaseII` | no |
| every id counter is above every live id; mission ids are unique across all cults | lookups by id (`Ordeals.getMissionByID`, `AreaGame.getAIByID`, the base defense) | `Game.restartPre` resets, each `loadPost` raises, `Loader.rebuildAIDataMaxID` runs last | yes |
| mission ids start at 1, so 0 is never a mission | `CultBase.initPost` reads a defense id of 0 as none | `Mission._maxID`, `Game.restartPre` | no |
| every cultist in the area has a record in a live cult | `AreaGame.removeAI` and `Cult.onRemoveAI` don't null-check | `Cult.destroy` clears flags in the area | yes |
| an ACTIVE cult has ≥ 1 member, the leader first | `Cult.onDeath` reads `members[0]` | `Cult.addLeader`, `Cult.destroy` | yes |
| a base defense id points at a live mission | `CultBase.addPressure`, `Team.spawnBaseDefenseOrdeal` skip while one runs | the defense missions' `onSuccess` | yes |
| custodes records and the base area's custos AIs match | `CultBase.onEnterArea` respawns from the records | `CultBase.onRemoveAI`, `CultBase.onEnterArea` | yes |
| base organ records and the base area's `base_organ` object parts match, footprints never overlap, one heart | Forma's `getOrganAt`, `refreshOrganObject`, organ damage through its object | `CultBase.createOrganObject`, `removeRibwallAt`, `syncOrganObjects` on load, `validateBuild` | yes |
| base stock, stored bodies and pressure are never negative, stock is under the stockpile cap, bodies under the Cadaverum slots and custodes under the Cauldron slots (broken organs counted); organ health in 0..max and level in 1..max; a non-heart organ is broken exactly at 0 health | `canAfford`, `incomePerTurn`, `isWorking` | `CultBaseResources.spend` after `canAfford`, `damageOrgan`, `initPost` | yes |
| a dead AI leaves the area at once; area AI ids are unique | area AI loops | `AI.die` sets DEAD and calls `removeAI` | yes |
| an NPC is at most one AI in the area | timeline NPC state | `AreaGame.turnSpawnNPC` spawns only an unlinked NPC | yes |
| in area mode the host is in the area's AI list | `Player.loadPost` re-link | `AreaGame.enter` | yes |
| cult members only die on screen: in the current area, or as the dying host | the region host's cult flag can't go stale (`Cult.destroy` clears only the area and habitats) | no off-screen member deaths exist | no |
| group priority stays in 0..100, team distance in 0..150, a team has 1..maxSize members | group and team logic | `Group.changeOnlyPriority`, the `Team.distance` setter, `Group.onTeamMemberDeath` | yes |
| the team leaves TEAM_FIGHT whenever the player leaves the area | a blackops host dying on the region map is harmless | `Team.onLeaveArea` | no |
| the base habitat is never removed | `CultBase` reads its area (`CultBase.syncOrganObjects` on load) | `Team.destroyHabitat` turns on the base instead | yes |
| an ordeal locks only live members | its action slots, the cult window | `Ordeal.onDeath` fails it | yes |
| the attack target is a live AI of the current area | attacks and organ actions on it | `AreaGame.removeAI`, `Game.setLocation` | yes |
| a mission target never despawns | Kill/Persuade would respawn it from a stale record | `AI.checkDespawn` | no (scenario `kill-target`) |
| a teardown runs no gameplay | load and restart discard the game | `AreaGame.leave`, `AreaGame.removeAI` check `game.isInited` | no (scenario `load-habitat-fight`) |
| on the region map only the host's effects tick, and only their location-free part | no effect reaches area code or `AI.die` there | `PlayerRegion.turn`, each area effect's location check | no (scenario `region-effects`) |
| the parasite is never reborn in a host | rebirth starts free at the ovum | `Player.releaseHost` | no (scenarios `rebirth-*`) |

`Bot.check` also asserts: no NaN in player, group, cult money, AI health/energy and alertness; host
and attach state consistent with the player state; the player and every AI inside the area; no goal
both current and completed; the message list under its cap; no unfilled template in the log. It
runs after every bot step, once before the first, and after a roundtrip load.

## Neighbour ideas

Design opportunities: a system that reacts to an event while a plausible neighbour does not.
Remove a line when it ships.

- Rebirth notifies nobody: the team could lose the trail, followers could react, a mod event.
- Habitat destruction punishes only the player: the cult, the ovum or evolution don't react.
- `CultBase.storedBodies` and ovum nurture aren't connected; no nurture points for cultist,
  custos or choir hosts.
- Team-member deaths raise Group priority, but cultist deaths and rival wipes touch nothing.
- Rivals never draw Group attention or compete with the player cult for recruits.
- No ordeal grants evolution or ovum progress; Metamorphosis I/II would fit.
- Group intel has two sources (brain probe, Dossier); the timeline has many. A cult intel ordeal or
  an "interrogate agent" chat option would mirror that.
- Mission events stop at death and consent; `onInvade`/`onBrainProbe`/`onNotice` could forward to
  `Mission.onEventAI`.
- `Group.neutralize`/`reopen` are invisible to cults and the timeline.
- No mod events for cult, ordeal, mission, goal, group priority, rebirth, despawn, new game or
  load (`area:enter` fires on neither, P7).

## History

One line per cross-system bug: the commit and the empty cell.

| commit | bug | cell |
|---|---|---|
| 6a9e4726 | a cultist host fed to the ovum stayed in the cult roster | AI death × H2/H3 × `Cult.onDeath` |
| 07fc1bd3 | a member's death failed every ordeal, not only its own | cult membership × member death × `Ordeals.onDeath` |
| 3e225586 | the ordeal death loop skipped ordeals | missions × member death × list removal |
| 82e2103e | a deferred key click hit a HUD button rebuilt after host loss | host death × HUD |
| c22f6c78 | ship parts vanished on area leave | area leave × scenario objects |
| ac4cbac8 | mission ids collided after loading a save with rivals (G1); a failed profane ordeal skipped the next one's turn (G9) | save/load × `Cult.loadPost`; missions × list removal |
| e902a0f0 | a host grown into a habitat organ came back as its NPC (G6) | AI death × H6 × `AI.notifyDeath` |
| "Fix eight cross-system gaps found by relations mapping" | G2 G3 G4 G5 G7 G8 G10 G11, each with a scenario | the cells above marked "fixed" |
| "Fix the plausible relations gaps" | P1 P2 P3 P4 P6 P8 P9 and the mission mark lost on load, each with a scenario; P5 P7 P12 recorded as design, P11 covered by "mission ids start at 1" | the P cells above |
| 686af4c4 | a rival whose leader died in a fight was deleted with no replacement; a raid won by the sanctum falling alone, with its defenders alive, and its rival never wiped | cult destruction × `RivalBase.onSuccess` |
| 9760e2ee | the last attacker's body of a defense was missed (its `BodyObject` is made after the death event) | missions × AI death × body storage |

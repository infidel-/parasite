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
  level, +9 turns, and the ovum loses a level. Rebirth notifies nobody else. Pedia: impOvum.

**Habitat**: `game/Habitat.hx`, `objects/HabitatObject.hx` and the habitat organs
- Owns energy balance, regen, watcher (S, as `AreaGame.habitat`).
- Destruction lives in `Team.destroyHabitat`: habitatsLeft--, a max-energy shock, maybe
  `Player.death('habitatShock')`.
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
- Out: goals, area, cults[0] (`Team.spawnBaseDefenseOrdeal`), player (habitat shock).
- Pedia: group, groupBasics, groupPriority, teamAmbush, teamBasics, teamDeactivation,
  impFalseMemories, groupNeutralize, msgWatching. Hidden: priority spillover from alertness; a team
  wipe makes the next team start at 1.5× distance.

**Cult core**: `cult/Cult.hx`, `cult/Effects.hx`, `cult/effects/*`
- Owns members (AIData copies, leader is `members[0]`), power, resources, level, base,
  trainingMemberIDs (S). At `game.cults[0]` (the player's), `getCultByID`, `getRivalCults`.
- Ticks every 10 player turns, paused in mission areas.
- Death chain: `AreaGame.removeAI` or `AI.dieRegion` → `Cult.onRemoveAI` / `Cult.onDeath` →
  `Ordeals.onDeath`; the leader's death runs `Cult.destroy`.
- Pedia: cult, cultBasics, cultPowerResources, cultCommands, cultBazaarNet. SDK: none.

**Ordeals**: `cult/Ordeal.hx`, `Ordeals.hx`, `ProfaneOrdeal.hx`, `cult/ordeals/*`
- Owns the ordeal list, profaneTimeout, per-ordeal members/power/missions (S). Rows in
  `reports/cult-ordeals.md`.
- Hooks: `onDeath`, `check`, `turn`, `onSuccess`, `fail`, `getActions`, `onTimerTick`.
- Out: timeline (GatherClues), goals, group, getRivalCult*. MetamorphosisPhaseII creates the base
  and the rivals. Pedia: cultCommunalOrdeals, cultProfaneOrdeals.

**Missions**: `cult/Mission.hx`, `cult/missions/*`
- Saved inside their ordeal. Hooks `turn`, `turnPreAI`, `turnAI` (can take over an AI before its
  own logic), `onSuccess`, `onFail`, `onEventAI` (ON_AI_DEATH, ON_AI_MAX_CONSENT only).
- `AreaGame.getAreaMission` finds the current area's mission; `AreaGame.canLeave` locks the area
  until it completes. Pedia: cultCombatMissions.

**Cult base**: `cult/base/*`, `objects/base/*`, `ai/CustosLogic.hx`, BaseDefense missions
- Owns resources, storedBodies, organs, custodes, attackPressure, defense id and timer (S). At
  `game.cults[0].base`. Losing Cor Nefandum ends the game.
- Created only by `MetamorphosisPhaseII`, inside the current habitat. Pedia: none (the `cultBase`
  article it adds does not exist).

**Rival cults**: `cult/RivalCult.hx`, `RivalAttack`/`RivalResearch` ordeals, `RivalBase` mission
- Owns template, tactic, revealed level, base area id (S, inside `game.cults`).
- `RivalCult.turn` is empty: rivals act only through the player's base (`CultBase.runRivalTurn`).
  Pedia: none.

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

| listener | H1 `AI.die` (area, via `PlayerArea.onHostDeath` for the host) | H2 `AI.dieRegion` (region host: expiry, degradation) | H3 `Ovum.nurtureOvumAction` (→ H2) | H6 `Habitat.putObject` (host grown into an organ) |
|---|---|---|---|---|
| `Player.onHostDeath` (affinity, tutorial goals, pedia) | ✓ host | ✓ | ✗ SAFE: voluntary sacrifice, matches H6 | ✗ same |
| `Cult.onDeath` → `Ordeals.onDeath` | via `AreaGame.removeAI` → `Cult.onRemoveAI` | ✓ direct | ✓ | via `removeAI` |
| custos `CultBase.onRemoveAI` | via `removeAI` | ✗ SAFE: `BaseCustosAI.canAttach` is false | ✗ same | n/a |
| `onDeath()` hook (team member → `Group.onTeamMemberDeath`, agent → director, blackops → `Team.checkFightFinish`) | ✓ | ✓ | ✓ | ✗ **GAP G6** |
| `npc.isDead` | ✓ | ✓ | ✓ | ✗ **GAP G6**: the NPC respawns |
| mission `onEventAI(ON_AI_DEATH)` | ✓ current area | ✗ SAFE: a mission area can't be left | ✗ same | ✗ **GAP G6** |
| mod AI_DIE_PRE / AI_DIE | ✓ | ✗ **GAP** (TODO.md, Mods) | ✗ same | ✗ **GAP G6** |
| body, targeting clear, enemies purge | ✓ | n/a | n/a | via `removeAI` (no body: the organ replaces it) |

H4 (`AI.onDamage` host branch) and H5 (`PlayerArea.onDamageHost`) run `AI.die` and match H1.
`Player.death` in host state (only `habitatShock`) keeps the host through the rebirth (PLAUSIBLE
P6: in a Kill mission area that carries the target out without ON_AI_DEATH).

### AI despawn (removed alive)

Entry points: D1 `AI.checkDespawn` (idle, unseen 5 turns), D2 `CommandLogic` leave-area command,
D3 `PoliceAI`/`SecurityAI.onStateChange` (backup goes idle), D4 `AreaGame.leave` (everything not
PRESERVED, the host too), D5 `Cult.clearCultistsInHabitats`, D6 `Team.destroyHabitat` (drops the
area, no `removeAI`). All but D6 go through `AreaGame.removeAI`.

| listener | D1–D3 | D4 leave | D5 | D6 |
|---|---|---|---|---|
| `AI.onRemove` (alive, not host, player in the same area): `HumanAI` → `RegionManager.onHostDiscovered`; `TeamMemberAI` → group; `BlackopsAI` → `Team.checkFightFinish` | ✓ | ✓ (not the host) | ✗ other area | ✗ |
| `npc.ai = null` | ✓ | ✓ | ✓ | ✗ stale pointer |
| `Cult.onRemoveAI` → `AIData.updateData` | ✓ (D2) | ✓ | ✗ SAFE: flag cleared first | ✗ record kept, live copy lost |
| custos `CultBase.onRemoveAI` | n/a (guards) | ✓ | n/a | ✗ |
| mission target copies | ✗ PLAUSIBLE P2: a Kill/Persuade target's progress resets on respawn | ✗ | ✗ | ✗ |
| BaseDefense `targetIDs` | ✗ **GAP G8** | ✗ **GAP G8** (rebirth walks you out) | n/a | n/a |
| `Targeting.target` | ✗ PLAUSIBLE P9 | via `Game.setLocation` | n/a | n/a |
| mod event | ✗ none exists | ✗ | ✗ | ✗ |

`RegionManager.onHostDiscovered` logs "had suffered a fatal accident" for an NPC host but leaves
`npc.isDead` false: **GAP G7**. `BlackopsAI.onRemove` does not call super, so a despawned invaded
blackops is never reported (PLAUSIBLE P12).

### Area enter and leave

Enter: N1 `Game.setLocation(LOCATION_AREA)` → `AreaGame.enter` (travel, habitat, mission area,
teleport); N2 `Game.init` → `AreaGame.enter` (new game); N3 load → `AreaGame.currentAreaLoadPost`.
Leave: X1 `Game.setLocation(LOCATION_REGION)` → `AreaGame.leave`; X2 `Game.restartPre` →
`AreaGame.leave` (restart and load).

| listener | N1 | N2 | N3 |
|---|---|---|---|
| `Team.onEnterHabitat`, `Goals.onEnter`, `cults[0].onEnterArea` → `CultBase.onEnterArea` (custodes respawn) | ✓ | ✓ | ✗ SAFE: director and custodes are saved in the area AI list |
| host re-added to `_ai` | ✓ with `_ai.add`, no NPC re-link: **GAP G5** (a second AI spawns for the same NPC) | n/a | via `Player.loadPost` |
| mod AREA_ENTER, autosave | ✓ | ✗ PLAUSIBLE P7 | ✗ P7 |

| listener | X1 | X2 |
|---|---|---|
| body discovery → `RegionManager.onBodyDiscovered` (not in habitats) | ✓ | ✓ |
| `removeAI` on everything not PRESERVED (= D4) | ✓ | ✓ |
| `Team.onLeaveArea` (escape, `destroyHabitat`, ambush → search) | ✓ | ✓ PLAUSIBLE P8: runs gameplay on the game being torn down |
| `AreaManager.onLeaveArea`, `cults[0].onLeaveArea` | ✓ | ✓ |
| mod AREA_LEAVE, autosave, `RegionGame.updateAlertness` | ✓ | ✗ |

Only `cults[0]` gets enter/leave: SAFE, because rivals have no base, ordeals or missions.

Leave checks, run by every exit object and `PlayerArea.leaveAreaAction`: `AreaGame.canLeave`
(mission lock, `Goals.leaveAreaPre`), `Cult.leavePre` (each follower 10% death). The habitat exit
also refuses with outsiders present: custodes count as outsiders, **GAP G4** (you can't leave the
base habitat). `Game.beginRebirth` skips every check.

### Habitat

| phase | entry point | not notified |
|---|---|---|
| create | `PlayerRegion.createHabitatAction` | — |
| enter | `PlayerRegion.enterHabitatAction` → N1, plus `Team.onEnterHabitat` | — |
| leave | `PlayerArea.leaveAreaAction` / `HabitatExit` | — |
| destroy | `Team.destroyHabitat` (from `Team.turnAmbush`, `Team.onLeaveArea`) | the AIs inside (no `removeAI`); `CultBase` if this is the base habitat (PLAUSIBLE P1: the base's area id dangles); missions marked there |

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
| `MetamorphosisPhaseII.addRivalMember` | ✗ | set on rival creation | temp AI | once |

A member leaves only by dying (`Cult.onDeath`). `trainingMemberIDs` and BlockCultist targets go
stale until they expire.

| listener | `Cult.destroy` (leader died) | `RivalBase.onSuccess` (rival base taken) |
|---|---|---|
| state → DEAD | ✓ | ✓ |
| members, effects, ordeals wiped | ✓ (no fail/success hooks run) | ✗ SAFE: `getRivalCults(true)` filters on state |
| removed from `game.cults` | rivals only | ✗ SAFE: `getCultByID` still finds it for its AIs |
| flags cleared in `game.area` and habitats | ✓ | ✗ SAFE: members kept, lookups succeed |
| `player.host` flag on the region map | ✗ SAFE: members only die on screen, so the host is in the cleared area or is the one dying | ✗ same |
| base defense | ✗ **GAP G3**: the defense id survives, `addPressure` never schedules again, the team stays in TEAM_BASE_DEFENSE | n/a |

`MetamorphosisPhaseII.onSuccess` returns early outside a habitat, but `Ordeal.success` removes the
ordeal anyway: **GAP G11**.

### Missions and ordeals

| listener | `Mission.success` | `Mission.fail` | profane timer out | member death | `Cult.destroy` |
|---|---|---|---|---|---|
| subclass `onSuccess`/`onFail` | ✓ | ✓ | ✓ | via `Ordeal.onDeath` → `fail` | ✗ |
| removed from `Ordeals.list` | via `Ordeal.check` | ✓ | ✓ but `Ordeals.turn` skips the next ordeal: **GAP G9** | ✓ (iterates a copy) | wiped |
| mission site area removed | only through exit objects | same | ✗ | ✗ | ✗ |

`ON_AI_DEATH` has one sender, `AI.die`, to the current area's mission. `ON_AI_MAX_CONSENT` comes
only from Chat. Mission targets: Kill/Persuade hold an AIData and respawn from it; Combat respawns
missing targets (`Combat.getMissingTargets`); BaseDefense/TeamBaseDefense hold ids only and cannot
respawn (G8). MetamorphosisPhaseII, RivalResearch, ReapTheUnwary and GenericProfaneOrdeal lock
members but don't override `onDeath` (PLAUSIBLE P3: a dead member still counts).

### Turn ticks: area vs region

| system | area turn | region turn |
|---|---|---|
| `Player.turn` (energy, affinity, organs, evolution) | ×1 | ×5 |
| `PlayerArea.turn` (control, AP) / `PlayerRegion.turn` (control +25, `chatTurn(5)`) | area | region |
| `Group.turn` | ×1 | ×1, not scaled (PLAUSIBLE P5) |
| `Cult.turnInternal` | cult time 1 | cult time 5 |
| `AI.turnInternal` (effects, traits, logic, despawn) | area AIs and host | ✗: host effects freeze (PLAUSIBLE P4) |
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
| `Player.loadPost` | area: host by `hostID`; region: keeps the saved copy and never calls `host.loadPost`: **GAP G2** (organ growth stops) |
| `Cult.loadPost` (per cult) | `Mission._maxID` set per cult, the last wins: **GAP G1** (mission ids collide after loading any save with rivals) |
| `Loader.rebuildAIDataMaxID` | the AIData counter over areas, habitats, host and cults, run last |

`World.loadPost` sets `RegionObject._maxID` from the region id instead of the object id and never
increments it (latent: only one ovum is created after worldgen).

## Copies and ids

`AIData.cloneData`/`AIData.updateData` are **shallow**: inside a session a copy shares inventory,
skills, organs, effects, traits and chat with the live AI. An AI spawned from a copy therefore
shares an `Organs` whose `_ai` still points at the old AI, so a possessed summoned cultist grows
organs on the wrong body: **GAP G10** (one session; a load builds fresh ones).

| holder | stores | synced by | stale when |
|---|---|---|---|
| `Cult.members` | AIData | `Cult.onRemoveAI` (despawn, death), `AI.dieRegion` | habitat destroyed (record kept) |
| `CultBase.custodes` | CustosAIData | `CultBase.onRemoveAI`, respawned by `CultBase.onEnterArea` | habitat destroyed |
| `Kill.target`, `Persuade.target` | AIData | ON_AI_DEATH | despawn (P2) |
| Combat `targets`/`targetIDs` | AIData + ids | ON_AI_DEATH, `Combat.getMissingTargets` | — (guards don't despawn) |
| BaseDefense `targetIDs`, `CultBase.activeDefenseMissionID` | ids | ON_AI_DEATH, the missions' `onSuccess` | despawn, rebirth, cult destroyed (G3, G8) |
| `RecruitFollower.target` | AIData, never live | — | — |
| `Ordeal.members` | member ids | `Ordeal.onDeath` in 7 ordeals | the other 4 (P3) |
| `Group.directorID` | id | `AgentAI.onDeath`; SAFE: `GroupDirector.onEnter` reassigns on every visit | — |
| `NPC.ai` | pointer (¬S) | `AI.setNPC`, `AI.loadPost`, cleared by `removeAI` | host re-added (G5), `Team.destroyHabitat` |
| `Player.host`/`hostID` | pointer + id | invade, `onDetach`, host death | region load (G2) |
| `AreaEvent.ai` | pointer + id | pruned when the event fires | despawn (still fires) |
| `AI.enemies` | ids | purged by `removeAI` | — |
| id counters `AIData`/`Mission`/`RegionObject`/`Cult._maxID` | statics (¬S) | rebuilt on load | G1, the RegionObject counter |

## Invariants

| invariant | relied on by | enforced at | asserted |
|---|---|---|---|
| a custos is never a host | host-death paths skip the custodes | `BaseCustosAI.canAttach` | no (structural) |
| a mission area can't be left until its mission completes | mission targets never die on the region map | `AreaGame.canLeave` (not `Game.beginRebirth`) | no (structural) |
| the player cult is `cults[0]`; only it has a base, ordeals and missions | enter/leave notify only `cults[0]` | `Game.init`, `MetamorphosisPhaseII` | no |
| the AIData counter is rebuilt after everything else loads | new AIs never reuse a member's id | `Loader.rebuildAIDataMaxID` | no |
| every cultist in the area has a record in a live cult | `AreaGame.removeAI` and `Cult.onRemoveAI` don't null-check | `Cult.destroy` clears flags in the area | no |
| an ACTIVE cult has ≥ 1 member, the leader first | `Cult.onDeath` reads `members[0]` | `Cult.addLeader`, `Cult.destroy` | no |
| a dead AI leaves the area at once | area AI loops | `AI.die` sets DEAD and calls `removeAI` | no |
| in area mode the host is in the area's AI list | `Player.loadPost` re-link | `AreaGame.enter` | no |
| cult members only die on screen: in the current area, or as the dying host | the region host's cult flag can't go stale (`Cult.destroy` clears only the area and habitats) | no off-screen member deaths exist | no |
| group priority stays in 0..100, team distance in 0..150, a team has ≥ 1 member | group and team logic | `Group.changeOnlyPriority`, the `Team.distance` setter, `Group.onTeamMemberDeath` | no |
| the team leaves TEAM_FIGHT whenever the player leaves the area | a blackops host dying on the region map is harmless | `Team.onLeaveArea` | no |

Asserted today (`Bot.check`): no NaN in player, group, cult money and alertness; a host in host
state; the player inside the area; no goal both current and completed.

## Neighbour ideas

Design opportunities: a system that reacts to an event while a plausible neighbour does not.
Remove a line when it ships.

- Rebirth notifies nobody: the team could lose the trail, followers could react, a mod event.
- Habitat destruction punishes only the player: the cult, the ovum or evolution don't react.
- `CultBase.storedBodies` and ovum nurture aren't connected; no nurture points for cultist,
  custos or choir hosts.
- Team-member deaths raise Group priority, but cultist deaths and rival wipes touch nothing; no
  reward for destroying a rival.
- Rivals act only through the player's base; without one they never act, draw Group attention or
  compete for recruits.
- No ordeal grants evolution or ovum progress; Metamorphosis I/II would fit.
- Group intel has two sources (brain probe, Dossier); the timeline has many. A cult intel ordeal or
  an "interrogate agent" chat option would mirror that.
- Mission events stop at death and consent; `onInvade`/`onBrainProbe`/`onNotice` could forward to
  `Mission.onEventAI`.
- `Group.neutralize`/`reopen` are invisible to cults and the timeline.
- No mod events for cult, ordeal, mission, goal, group priority or rebirth.

## History

One line per cross-system bug: the commit and the empty cell.

| commit | bug | cell |
|---|---|---|
| 6a9e4726 | a cultist host fed to the ovum stayed in the cult roster | AI death × H2/H3 × `Cult.onDeath` |
| 07fc1bd3 | a member's death failed every ordeal, not only its own | cult membership × member death × `Ordeals.onDeath` |
| 3e225586 | the ordeal death loop skipped ordeals | missions × member death × list removal |
| 82e2103e | a deferred key click hit a HUD button rebuilt after host loss | host death × HUD |
| c22f6c78 | ship parts vanished on area leave | area leave × scenario objects |

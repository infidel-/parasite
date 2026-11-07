# TODO

Known open work, deferred on purpose. Remove an entry when it is done.

## Localization

- **Extended gameplay information is English only.** The 32 `game.info` / `game.infoChange` /
  `game.infostr` lines (Options → "Extended gameplay information") are bare English, several glued from
  pieces: the roll breakdowns in `src/__Math.hx` (238, 300, 318, 361), the consent/fatigue tags in
  `src/game/Chat.hx` (486, 515, 568, 739, 867, 913, 1057), `src/game/Group.hx` (233–356),
  `src/game/Skills.hx` (178, 236, 238), `src/game/EvolutionManager.hx` (122, 196, 210), `src/game/Team.hx`
  (189, 618), `src/game/AreaGame.hx` (2829, 3222), `src/game/PlayerArea.hx` 833, `src/ai/CommonLogic.hx` 319,
  `src/effects/Withdrawal.hx` 34, `src/effects/WhitePowder.hx` 33, `src/scenario/Timeline.hx` 526. Each becomes
  one `T()` template with placeholders (the `INFO` prefix is added in `Game.hx`); about an hour plus a
  `make loc` run.
- **The Options title is spelled out letter by letter for the SPOON easter egg.** `src/ui/Options.hx:40`
  splits the literal `'OPTIONS'` into clickable letters, and the pedia article on spoon mode tells the
  player to click S-P-O-O-N in it. French keeps « OPTIONS », but a language whose title lacks those letters
  breaks both. Before such a language ships: build the letters from the translated title and translate the
  target word with it, or keep the English letters on purpose and say so in that pedia article.

## Cult

- **A host with a stale cult flag would crash on leaving an area.** Guard only, no known trigger.
  `Cult.destroy()` clears `isCultist` only in `game.area` and the habitats, and `Cult.onRemoveAI`
  throws on a missing record (`src/cult/Cult.hx:216`). Seen only by flagging a host by hand: cult
  members die only on screen, and a rival taken by `RivalBase.onSuccess` is never `destroy()`ed
  (relations.md, cult destruction row). Fix if a trigger appears: guard in `onRemoveAI`.

## Mods

- **`AI_DIE_PRE` / `AI_DIE` do not fire for a host that dies on the region map.** `AI.dieRegion()`
  (ovum, expiry, degradation) runs the cult record and the `onDeath()` hook like `AI.die()`, but not
  the mod events: their payload carries `area` and `entity`, and neither exists there. Needs either a
  region-death event or a payload with both optional.

## Found by relations mapping

Confirmed by reading the code end to end; each has its cell in `docs/relations.md`.

- **G6** `Habitat.putObject` kills the host without `AI.die`: no `npc.isDead` (the NPC respawns), no `onDeath` hook, no mod event.
- **G2** A save made on the region map with a host never runs `host.loadPost`: organ growth stops until an organ is picked again.
- **G3** `Cult.destroy()` during a base defense: the defense id survives, no defense is ever scheduled again, the team stays in TEAM_BASE_DEFENSE.
- **G4** Custodes count as outsiders in the habitat exit check, so the base habitat can't be left.
- **G5** `AreaGame.enter` re-adds the host without re-linking `npc.ai`: a second AI spawns for the same NPC.
- **G7** `RegionManager.onHostDiscovered` says an NPC host had a fatal accident but leaves it alive; its lines are bare English.
- **G8** BaseDefense attackers that vanish without dying (rebirth, despawn) leave a defense that can never finish.
- **G10** An AI spawned from a shallow AIData copy shares an `Organs` whose `_ai` points at the old AI.
- **G11** `MetamorphosisPhaseII` performed outside a habitat is used up without creating the base.

## Found by the headless tests

Each entry has the replay command; see `tests/README.md`. The harness works around these so the
suites stay green, and says so at the workaround.

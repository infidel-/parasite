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

- **A host with a stale cult flag crashes on leaving an area.** `Cult.destroy()` clears `isCultist`
  only on AIs in `game.area` and in habitats, so a host carried on the region map when its cult is
  destroyed (a rival destroyed by an ordeal) keeps it. `AreaGame.removeAI` then calls
  `Cult.onRemoveAI`, whose member lookup is null: `aidata.updateData` throws
  (`src/cult/Cult.hx:216`). Seen live by flagging a non-member host by hand; `AI.dieRegion()` already
  guards the same gap. Fix: clear the flag on `game.player.host` in `destroy()`, or guard there.

## Mods

- **`AI_DIE_PRE` / `AI_DIE` do not fire for a host that dies on the region map.** `AI.dieRegion()`
  (ovum, expiry, degradation) runs the cult record and the `onDeath()` hook like `AI.die()`, but not
  the mod events: their payload carries `area` and `entity`, and neither exists there. Needs either a
  region-death event or a payload with both optional.

## Found by the headless tests

Each entry has the replay command; see `tests/README.md`. The harness works around these so the
suites stay green, and says so at the workaround.

- **A second New Game in one session logs its opening lines under the last game's turn.**
  `Game.init` (`src/game/Game.hx` ~124) logs the version line and the hidden debug line before it sets
  `turns = 0`, so those `_LogMessage`s carry the previous game's turn count. Cosmetic. The id counters
  `AreaGame`/`AIData`/`AreaObject`/`Mission`/`CultBaseOrgan`/`RivalBaseOrgan`/`RegionObject`/`NPC`
  `._maxID` likewise carry on across a restart (`restartPre` resets only Region and Cult), which is
  harmless in play. Workaround: `test.Headless.newGame` zeroes them. Fix: move `turns = 0` above the
  first `log`, and reset the counters in `restartPre` if seed-for-seed replay inside the GUI matters.

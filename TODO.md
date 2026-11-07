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
- **An old save's unvisited city area is generated at its old shrunk size.**
  `AreaGame.migrateCityGrid` (`src/game/AreaGame.hx:330`) grows only areas that were already
  generated, and `generate()` (`:947`) re-sizes old military bases, labs and caves but not cities.
  So a pre-1.0 save's city area entered for the first time after the upgrade is built 90 wide with
  the unreachable streets the migration exists to fix, and the next load migrates it after all.
  Replay: `make test args="--run roundtrip:save/region-cult4-t58-v0.20.json.gz:1:50"`. Fix: give
  cities `info.width`/`info.height` in `generate()`, as the lab gets.
- **Re-migrating such an area on the next load can crash the load.** For the v0.21 rival-base save,
  that second load throws in `CityAreaGenerator.addCrosswalks` (via `rebuildCells` ←
  `migrateCityGrid` ← `World.loadPost`), so the game does not load. Replay:
  `make test args="--run roundtrip:save/region-cult-rival-base-t234-v0.21.json.gz:1:50"`.
  Probably gone with the fix above; check `rebuildCells` on a grid that was generated shrunk.
- **A failed load leaves a half-wiped game running.** Loading a save whose mod classes are missing
  (four fixtures need the pickpocket mod's `BurglarKingAI`) answers "Load anyway?" with an
  exception, then the game carries on with `game.area == null` and the HUD throws on the next
  update. `Game.save` already guards against saving over a slot from that state. Replay: move
  `parasite/dev/pickpocket` aside, then
  `make test args="--run fuzz:save/military-base-t155-v1.0.2.json.gz:1:200"`.

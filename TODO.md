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

- **The cult base has no pedia article.** `MetamorphosisPhaseII` adds `cultBase`, which does not exist in
  `src/const/PediaConst.hx`. Forma (keys, organs, custodes, Corpus Basilica) would go there; it needs a
  2560x1440 image.
- **A custos can't be crafted on a Porta Costarum from Forma.** With a custos picked, Enter or a click on
  a gate opens the tend menu (an organ is there), though `validateCustos` allows the tile. A tend row
  "Craft <custos> here" or a modifier would cover it.

- **A host with a stale cult flag would crash on leaving an area.** Guard only, no known trigger.
  `Cult.destroy()` clears `isCultist` only in `game.area` and the habitats, and `Cult.onRemoveAI`
  throws on a missing record (`src/cult/Cult.hx:216`). Seen only by flagging a host by hand: cult
  members die only on screen (a rival taken by `RivalBase.onSuccess` now goes through `destroy()` too).
  Fix if a trigger appears: guard in `onRemoveAI`.

## Found by the headless tests

Each entry has the replay command; see `tests/README.md`. The harness works around these so the
suites stay green, and says so at the workaround.

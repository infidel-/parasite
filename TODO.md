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

# Headless game tests

The real game logic, run under node with no renderer and played by bots. They catch crashes, stuck
states, broken invariants and saves that do not survive a load.

| run | what it does |
|---|---|
| `cd src && make` | builds the game, then runs the **quick cut** (`--quick`, ~21 runs, ~5 s) |
| `make test` | the full soak: every suite, 20 seeds, 1000 steps (~1 min on 6 cores) |
| `make test args="--suite fuzz --start s21 --count 50"` | one suite, chosen start points and seeds |
| `make test args="--run <id>"` | replay ONE run: the id a failure prints |

Arguments are `--suite all|smoke|fuzz|compat|roundtrip|tutorial`, `--start new,s1,save/<file>`,
`--seed N`, `--count N`, `--steps N`, and for the tutorial `--goal GOAL_X` (default
`GOAL_ENTER_SEWERS`) and `--reach P`. Add `--full` to print a known failure's whole report, `--stop N` to
write the state before step N as a save, and `--trace` to keep the game's own console output.

## How it works

- **The real game, with leaf stubs.** `src/test/Headless.hx` boots `Game`, `UI`, `GameScene`,
  `render.View`, `Sounds` and `Images` as `Main` does, minus the canvas, the warm and the menu.
  `tools/test.mjs` stubs only the leaf browser APIs underneath (THREE, the DOM, WebAudio) with a
  bottomless proxy, the trick `tools/genrun.mjs` uses. Stubbing `game.scene` or `game.ui` instead
  would hand logic a truthy proxy wherever it reads a value back (`view3d.liftDepart`, the `play*`
  booleans, the `scene.images` job tables). The view is never shown, so `View.running` stays false
  and logic takes its own non-3D path.
- **What is real, not stubbed:**
  - the canvas size, which drives the view rect, spawns and sounds;
  - `window.host`, an in-memory save map plus the sound list from `app/sound`;
  - `Math.random`, seeded per run. `Std.random` compiles to it, so a run id is a replay.
- **The seams in shipped code.** `#if headless` in `GameScene.draw` releases the window queue the 3D
  reveal would release. The boot calls `Sounds.init`, which soundmanager's onready would. The proxy
  answers `firstChild` with null, so the HUD's `while (firstChild != null)` loops end.
- **One run per process.** `--plan` lists a suite's run ids, `--run <id>` plays one, and the parent
  runner pools a process per id over the cores. Two games in one process do not roll the same: the
  s1 preset then s11 drew a different timeline than s11 alone. A process is the only clean slate,
  and the only way a run id is a replay.
- **The bot** (`src/test/Bot.hx`) uses the player's own entry points: `ActionsHud.action(i)`,
  `keyAction`, `UI.handleMovement` (numpad codes), Escape through `UI.onKey`, a window's
  `action(i)` and `UI.closeWindow`. The only UI rules it copies are the three navbar gates (Evo,
  Cult, Body). Its choices come from its own `gen.Rng` stream. It has two policies:
  - **random**: weighted picks among moves, actions, windows and Escape;
  - **goal**: walks the tutorial chain the way a player would.

  The goal policy works like this:
  - **Hosts.** It walks to the nearest calm, unarmed human the way a mouse click walks
    (`setPath`), attaches, hardens its grip and invades. A dog is ridden to a human, and the
    parasite steps out next to them.
  - **Evolution.** It evolves Brain Probe in the Evolution window.
  - **Learning.** It learns the host's items in the Body window, and probes the brain until the
    host's health is down to 3.
  - **Sewers.** For ENTER_SEWERS it learns the sewer hatch and uses it.

  Wherever the goal policy has no opinion, the random policy picks. **Measured** (2026-11-05,
  seeds 1-40): 53% reach ENTER_SEWERS, median 94 turns. Most failures die to police once the area's
  alertness climbs, because the bot never changes area. Raising that rate means teaching it to
  travel; raise `--reach` with it.

## Suites

| suite | runs | checks |
|---|---|---|
| `smoke` | one run over N seeds in one process | a new game lands in an area; Wait passes turns; one seed saves the same twice, and its hash matches across processes |
| `fuzz` | `new` and the 11 console stage presets (`s1`..`s31`) × seeds | random play; after every step: no throw, no `UI.onError` alert, the invariants, not stuck (300 steps with no turn) |
| `compat` | every fixture save | it loads through `Game.load` (old saves too), then 200 fuzz steps |
| `roundtrip` | `new`, the presets and every fixture | play a little, save, load, save: the two saves must match field for field |
| `tutorial` | new games × seeds, the GOAL policy | works through the tutorial chain to `--goal`; the suite fails when fewer than `--reach`% of the seeds get there (default 40, quick 20) and prints min/median/max turns |

**Invariants** (`Bot.check`), which check only rules the code already implies:
- no NaN in player health, energy and ap, `group.priority`, cult money, area alertness;
- a host whenever the player is in host state;
- the player inside the area;
- no goal both current and completed.

**Roundtrip ignores** `messageList`/`hudMessageList` (a load logs "Game loaded from slot N.") and
`visRev` (the renderer's sightline counter, which a load bumps). It reports each changed path once,
with ids folded (`_list.N`, `_ai[]`), and writes both saves to `tests/out/roundtrip-*-{a,b}.json.gz`.

## When something fails

A failure prints:
- the run id and the step;
- the replay line (`make test args="--run fuzz:s21:11:1000"`);
- the bot's last 30 steps and the last 8 log lines;
- a save of the state one step before, played again in a fresh process:
  `tests/out/fail-<id>.json.gz`.

To look at that state in the game, gunzip it over a slot (`parasite/save03.json`) and load it from
the Saves window.

**Known failures** are listed in `tests/known.json`: `{ "match": ["substring", ...], "todo": "where it
is filed" }`. Each failure line of a run is matched on its own, and a run counts as known only when
all of its lines match. Known runs are reported but keep make green. Each one is a TODO.md entry
under "Found by the headless tests". When it is fixed, delete the entry here and in TODO.md.

## Fixture saves

`tests/saves/<what>-t<turns>-v<game version>.json.gz`, packed with `make fixture`. **Old saves matter
most**: compat and roundtrip load every one of them on every soak. When a case is tricky or slow to
set up, make it a save the same way. `make fixture name=<what> slot=<NN>` packs
`parasite/saveNN.json` with the current version stamped. Then add its row below.

Most of them were made with the `chainsaw` and `pickpocket` mods on, and the tests run without mods.
A load then raises the game's own "different mod set" prompt, which the harness answers with *load
anyway*, as a player without the mods would. Saves that hold mod content cannot load that way (the
four marked *needs pickpocket*); `tests/known.json` files them.

The version is the one in the save when it carries one (0.19, 0.20 wrote it as `version`).
Otherwise it is *inferred* from the save's date against the `src/VERSION` history.

| file | version | format | turns | where | covers |
|---|---|---|---|---|---|
| `city-cult2-t44-v0.19` | 0.19 (stated) | 0.19 | 44 | city, host | early cult, two members |
| `region-cult4-t58-v0.20` | 0.20 (stated) | 0.20 | 58 | region | cult of four |
| `region-cult-full-t58-v0.20` | 0.20 (stated) | 0.20 | 58 | region | full cult |
| `region-cult-full-weapons-t58-v0.20` | 0.20 (stated) | 0.20 | 58 | region | full cult, armed |
| `region-cult-full-max-combat-t62-v0.20` | 0.20 (stated) | 0.20 | 62 | region | full cult, max combat |
| `habitat-cult-base-t108-v0.21` | 0.21 (inferred) | 2 | 108 | habitat | cult base, three cults |
| `region-cult-rival-base-t234-v0.21` | 0.21 (inferred) | 2 | 234 | region | rival cult base |
| `city-chainsaw-mod-t18-v0.22` | 0.22 (inferred) | 3 | 18 | city, host | chainsaw mod content |
| `corp-t30-v0.24` | 0.24 (inferred) | 3 | 30 | corp area, host | corporate building |
| `city-parasite-t3-v0.24` | 0.24 (inferred) | 3 | 3 | city, no host | the very start |
| `region-corp-cult1-t17-v0.24` | 0.24 (inferred) | 3 | 17 | region | cult of one, by a corp |
| `city-medium-parasite-t336-v0.24` | 0.24 (inferred) | 3 | 336 | medium city, no host | long game |
| `city-medium-cult8-t1116-v0.24` | 0.24 (inferred) | 3 | 1116 | medium city, host | late game, cult of eight |
| `military-base-cult8-t1116-v0.24` | 0.24 (inferred) | 3 | 1116 | military base | late game |
| `military-base-cult8-t1156-v0.24` | 0.24 (inferred) | 3 | 1156 | military base | late game |
| `military-base-t147-v1.0` | 1.0 (inferred) | 3 | 147 | military base | *needs pickpocket* |
| `military-base-t155-v1.0.2` | 1.0.2 (stated) | 3 | 155 | military base | *needs pickpocket* |
| `facility-cult4-t162-v1.1` | 1.1 (inferred) | 3 | 162 | facility | *needs pickpocket* |
| `region-facility-parasite-t158-v1.1` | 1.1 (inferred) | 3 | 158 | region, no host | *needs pickpocket* |

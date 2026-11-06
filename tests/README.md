# Headless game tests

The real game logic, run under node with no renderer and played by bots. They catch crashes, stuck
states, broken invariants and saves that do not survive a load.

| run | what it does |
|---|---|
| `cd src && make` | builds the game, then runs the **quick cut** (`--quick`, 30 runs, ~10 s) |
| `make test` | the full soak: every suite, 20 seeds, 1000 steps (404 runs, ~125 s on 6 cores) |
| `make test args="--suite fuzz --start s21 --count 50"` | one suite, chosen start points and seeds |
| `make test args="--run <id>"` | replay ONE run: the id a failure prints |

Arguments are `--suite all|smoke|fuzz|compat|roundtrip|continue|tutorial`, `--start new,s1,save/<file>`
(a start is `new`, `sandbox`, `mods`, a preset or a fixture, then console commands chained with `+`,
`_` for a space: `s1+cu_start+cu_members`),
`--seed N`, `--count N`, `--steps N`, and for the tutorial `--goal GOAL_X` (default
`GOAL_USE_COMPUTER`, quick `GOAL_TRAVEL_EVENT`) and `--reach GOAL=N,...`. Add `--full` to print a known failure's whole report, `--stop N` to
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
  - `window.host`, an in-memory save map plus the sound list from `app/sound`, and a fixture's mods;
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
  - **random**: weighted picks among moves, actions, windows and Escape. It also aims: T enters
    targeting (on key up, as `UI.onKeyUp` has it), the targeting keys rotate and confirm, and `s`/`a`
    shoot or hit a target. It answers the Difficulty window and toggles the Ovum window's marks;
  - **goal**: walks the tutorial chain the way a player would, and on through the timeline and the
    habitat to USE_COMPUTER.

  The goal policy works like this:
  - **Hosts.** It walks to the nearest calm, unarmed human the way a mouse click walks
    (`setPath`). A target with witnesses around (who would call the police) counts as further away.
    It attaches, hardens its grip and invades; a parasite running out of energy invades early once
    the grip gives that a fair chance. A dog is ridden to a human, and the parasite steps out next to
    them.
  - **Evolution.** It evolves Brain Probe in the Evolution window, and waits for it. Then, while it
    goes on with the rest, any organ improvement for EVOLVE_ORGAN, then Microhabitat. For
    GROW_ORGAN it grows an organ in the Body window.
  - **Learning.** It learns the host's items in the Body window, and probes the brain until the
    host's health is down to 3.
  - **Leaving.** It leaves an area once its alertness reaches 50, for ENTER_SEWERS, and for an event
    area it wants. A city is left by its sewer hatch (learned first), other areas by Leave Area. It
    changes host first when the host has less than 50 energy for the trip.
  - **Region map.** It travels (`PlayerRegion.setTarget`) to the event area whose location it
    knows while TRAVEL_EVENT, LEARN_CLUE or LEARN_NPC want it, and waits outside while that area's
    alertness is 50 or more (it falls by one a turn on the region map). Otherwise, and whenever it
    needs a new host, it enters the nearest calm inhabited area that is not the one it just fled.
  - **Clues.** In the event area a literate host picks up the clue papers and reads them (Body
    window), and an event participant's brain is probed until it has nothing left.
  - **Habitat.** For CREATE_HABITAT it goes down to the region map and creates the habitat under
    the area it is in. For USE_COMPUTER it rides to a human carrying a smartphone or a laptop (one
    who knows computers too, while the parasite does not, and probes that skill out of them),
    learns the device, takes it to the habitat and searches with it until the search works.
  - **Windows** are opened once a turn at most: a window with nothing to do in it is escaped, and
    opening it again straight away would loop with no turn passing.

  Wherever the goal policy has no opinion, the random policy picks. Each run prints the turn it
  reached each milestone on, and the soak tallies them. **Measured** (2026-11-06, seeds 1-40, the
  soak's tutorial seeds):

  | milestone | reached | turns min / median / max |
  |---|---|---|
  | INVADE_HUMAN | 37/40 | 7 / 16 / 33 |
  | LEARN_SOCIETY | 20/40 | 68 / 94 / 141 |
  | ENTER_SEWERS | 17/40 | 82 / 111 / 146 |
  | TRAVEL_EVENT | 17/40 | 91 / 117 / 148 |
  | LEARN_CLUE | 11/40 | 109 / 177 / 241 |
  | LEARN_NPC | 9/40 | 126 / 172 / 297 |
  | EVOLVE_ORGAN | 21/40 | 47 / 92 / 108 |
  | GROW_ORGAN | 16/40 | 80 / 119 / 186 |
  | EVOLVE_MICROHABITAT | 15/40 | 84 / 132 / 201 |
  | CREATE_HABITAT | 15/40 | 84 / 142 / 243 |
  | USE_COMPUTER | 6/40 | 174 / 237 / 279 |

  Most of the losses are deaths before LEARN_SOCIETY: until then a city cannot be left (the sewer
  hatch cannot be learned yet), and the police that witnesses call kill the host. Fleeing alerted
  police outright measured worse (9 → 4 of 40): they stay alerted, and the bot stops progressing.
  Past LEARN_NPC the losses are the same deaths, in the long stretches spent in cities looking for
  a host with a device.

## Suites

| suite | runs | checks |
|---|---|---|
| `smoke` | one run over N seeds in one process | a new game lands in an area; Wait passes turns; one seed saves the same twice, and its hash matches across processes |
| `fuzz` | `new`, `sandbox` (the sandbox scenario), `mods` (every mod in `parasite/dev` on) and the 11 console stage presets (`s1`..`s31`) × seeds | random play; after every step: no throw, no `UI.onError` alert, the invariants, not stuck (300 steps with no turn) |
| `compat` | every fixture save | it loads through `Game.load` (old saves too), then 200 fuzz steps |
| `roundtrip` | `new`, the presets and every fixture | play a little, save, load, save: the two saves must match field for field |
| `continue` | the 11 presets × 3 seeds (quick: `s1`, `s2`) | random play to step 30, on to the first quiet step (no walk, region trip, repeated action or window under way), save. Then 100 steps on a second seed, and save. A fresh process loads the quiet save and plays the same 100 steps: the two last saves must match |
| `tutorial` | new games × seeds (twice the seeds in the soak), the GOAL policy | works through the tutorial, the timeline and the habitat to `--goal`; the suite fails when fewer runs than `--reach` reach a gated milestone (default one run each for LEARN_NPC, CREATE_HABITAT and USE_COMPUTER; quick, TRAVEL_EVENT). The soak prints each milestone's reach and min/median/max turns |

**Seeds vary the setup:**
- the difficulty is `1 + seed % 3`;
- one random run in four sets it to 0 instead, so the bot answers each Difficulty window itself;
- odd seeds play with the gray INFO lines (`extendedInfo`) off, as a player has them. A debug build
  defaults them on.

**The slowest step** of each run is printed, and the soak lists its five worst (`[test] slow
step`). It is a report, not a gate; today's worst is ~0.7 s, the first entry into an area on an
old save, which generates it.

testmod's `bad*` ids are rejected on purpose, so the runner does not count those rejects as alerts.

**Invariants** (`Bot.check`), which check only rules the code already implies:
- no NaN in player health, energy and ap, `group.priority`, cult money, area alertness, AI health
  and energy;
- AI health and energy at most their max, every AI inside the area;
- host state: a host, `hostID` its id, and the host in the area's AI list; attached state: an
  attach host flagged `parasiteAttached`; parasite state: neither;
- every `enemies` id of an AI (the carried host aside) an AI in the area;
- every cultist in the area has its member record (`Cult.onRemoveAI` throws without one);
- the id counters (`RegionObject`, `AIData`, `AreaObject`, `NPC` `._maxID`) above every live id;
  a load restores them, and two of them it did not (fixed);
- `messageList` within its cap of 100;
- the player inside the area;
- no goal both current and completed.

**Continue** catches what roundtrip cannot: state that play reads and a save drops, such as a
static counter a load does not restore. Roundtrip compares the save it just loaded, so it never
plays on. Both halves reseed `Math.random` and start a new bot on the second seed. The second half
plays with the first half's profile. New games are left out, because random play ends them before
step 30. Measured 2026-11-06: 24 of 39 sampled runs compared, all identical.

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

**The same bot plays the live game** through the debug console:
- `bot run [steps] [random|goal]`, `bot step`, `bot stop`;
- `bot check` (the invariants, now);
- `bot seed [n]` (a new game on seed n's world).

It runs one step per two turn animations and stops on the first broken invariant or throw. A seed
gives the headless run's world but not its play, because the renderer draws from the same
`Math.random` between turns; the failure save is the exact state. See
[`docs/debug-surface.md`](../docs/debug-surface.md).

**Known failures** are listed in `tests/known.json`: `{ "match": ["substring", ...], "todo": "where it
is filed" }`. Each failure line of a run is matched on its own, and a run counts as known only when
all of its lines match. Known runs are reported but keep make green. Each one is a TODO.md entry
under "Found by the headless tests". When it is fixed, delete the entry here and in TODO.md.

## Fixture saves

`tests/saves/<what>-t<turns>-v<game version>.json.gz`, packed with `make fixture`. **Old saves matter
most**: compat and roundtrip load every one of them on every soak. When a case is tricky or slow to
set up, make it a save the same way. `make fixture name=<what> slot=<NN>` packs
`parasite/saveNN.json` with the current version stamped. Then add its row below.

Most of them were made with the `chainsaw` and `pickpocket` mods on. **A fixture run loads the mods
its save names** (`_activeMods`), from the dev install's `parasite/dev/<id>`, where each example's
`make` puts it (`examples/*/`, `make testmod`). `tools/test.mjs` lists them for `host.mods.list`, a
node loader hook serves `mod://`, and the boot awaits `ModLoader.load` as the menu does. A newer mod
version than the save's raises the game's own "different mod set" prompt, which the harness answers
with *load anyway*. New games and presets run with no mods. **A mod missing from `parasite/dev`
is left out**, and the four saves holding pickpocket content (*needs pickpocket*) then fail to load.

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

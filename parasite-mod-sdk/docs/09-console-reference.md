# Console command reference

The in-game console runs developer commands. Open it in-game using ";" key (not DevTools).
Type `h` or `help` for the list the build itself advertises.

> **Note on "debug":** the console is split at runtime — many commands are
> only dispatched when debug mode is on. Debug mode is toggled by an empty
> `.debug` file in the game install directory (see
> [01-getting-started.md §5](01-getting-started.md#5-enable-debug-mode-optional));
> the flag is resolved once at startup. The "Build" column below means: `all` =
> always available, `debug` = only with `.debug` present at launch.

## Mod commands (always available)

The `mods` command (alias `mo`) is available in every build.

| Command                 | Effect                                                                   |
|-------------------------|--------------------------------------------------------------------------|
| `mods` / `mods list`    | list every discovered mod with version, status, and source. Status is one of `enabled` / `disabled` / `failed` / `inactive`. |
| `mods enable <id>`      | remove `<id>` from `profile.disabledMods`. Takes effect on renderer reload (Ctrl-F5). |
| `mods disable <id>`     | add `<id>` to `profile.disabledMods`. Takes effect on renderer reload (Ctrl-F5). |
| `mods errors` / `mods err` | print per-mod failure reasons recorded during scan/import/init.       |

Enabling/disabling writes `profile.json` and prints a reload reminder; it does
not unload an already-loaded mod mid-session.

## Other commands

| Command                         | Build         | Effect                                              |
|---------------------------------|---------------|-----------------------------------------------------|
| `cfg` / `config`                | all           | show config; `config <option> <value>` sets one     |
| `debug renderstats`             | all           | toggle render stats                                 |
| `debug ai`                      | all           | AI debug                                            |
| `debug sound`                   | all           | sound debug                                         |
| `debug lights`                  | all           | lighting debug                                      |
| `debug alert` / `demo` / `leave` / `throw` | debug | misc debug subcommands                          |
| `save` (`sa`, `sav`)            | all           | save game (slot 1)                                  |
| `r` / `restart`                 | all           | restart game                                        |
| `q` / `quit`                    | all           | quit the app                                        |
| `oa<index> [level]`             | all           | grant + fire an evolution organ action by index     |
| `load` (`lo`)                   | all           | load game (slot 1)                                  |
| `give effect <name>`            | debug         | grant effect                                        |
| `give item <name>`              | debug         | grant item                                          |
| `give organ <name>`             | debug         | grant organ                                         |
| `give skill <name> <amount>`    | debug         | set skill level                                     |
| `give trait <name>`             | debug         | grant trait                                         |
| `give evolution <name> <level>` | debug         | grant evolution improvement                         |
| `go area <x> <y>`               | debug         | jump to area                                        |
| `go event <index>`              | debug         | jump to event                                       |
| `go xy <x> <y>`                 | debug         | move to coordinates                                 |
| `goal complete <id>`            | debug         | complete an active goal                             |
| `goal receive <id>`             | debug         | grant a goal                                        |
| `god`                           | debug         | toggle godmode                                      |
| `ie`                            | debug         | dump timeline (trace)                               |
| `ii`                            | debug         | dump improvements (trace)                           |
| `learn clues|event|improvements|region|timeline` | debug | learn-data commands                       |
| `set <variable> <value>`        | debug         | set a game variable (`set` alone lists variables)   |
| `s<stage>`                      | debug         | jump player to a scripted progression stage (`s` alone lists stages) — see below |
| `snd <file>`                    | debug         | play a sound (no extension; `snd` alone lists files)|
| `spa <ai type>`                 | debug         | spawn AI (`spa` alone lists types)                  |
| `spc <job type>`                | debug         | spawn civilian by job (`spc` alone lists types)     |
| `ch<stage>`                     | debug         | set up host chat/persuasion conditions (`ch` alone lists stages) — see below |
| `cu` / `cult <sub>`             | debug         | cult subcommands (`cu` alone lists them) — see below |

## Player progression stages (`s<stage>`, debug)

`s<stage>` fast-forwards a fresh game to a scripted state so you can test
content without playing through. Stages are **cumulative** — each builds on an
earlier one (e.g. `s22` runs the stage 2, 2.1, and 2.2 setup in sequence). `s`
alone lists them in-game.

| Command | State set up                                                      |
|---------|-------------------------------------------------------------------|
| `s1`    | stage 1: human civilian host, tutorial done                       |
| `s11`   | stage 1.1: stage 1 + group knowledge                              |
| `s12`   | stage 1.2: stage 1.1 + ambush                                     |
| `s2`    | stage 2: stage 1 + microhabitat (sewer hatch learned)             |
| `s21`   | stage 2.1: stage 2 + camo layer, dopamine, computer use           |
| `s22`   | stage 2.2: stage 2.1 + biomineral (built)                         |
| `s23`   | stage 2.3: stage 2.2 + assimilation cavity (built)                |
| `s24`   | stage 2.4: stage 2.1 + group knowledge                            |
| `s25`   | stage 2.5: stage 2 + ambush                                       |
| `s3`    | stage 3: stage 2.3 + spaceship (alien scenario only)              |
| `s31`   | stage 3.1: stage 3 + ready to launch                              |

Several stages assume the `alien` scenario; `s3`/`s31` bail out with a message
on other scenarios. Some need a current host or a specific location to apply
cleanly — run them from a fresh game start for predictable results.

## Host chat/persuasion stages (`ch<stage>`, debug)

`ch<stage>` sets up the conditions needed to exercise host chat/persuasion. `ch`
alone lists them in-game.

| Command | State set up                                          |
|---------|-------------------------------------------------------|
| `ch1`   | host affinity + social skills (psychology, coaxing, coercion, deception) |
| `ch2`   | ch1 + host high consent                               |
| `ch3`   | ch1 + host max affinity and consent                   |
| `ch4`   | active chat target gets full consent (needs a target) |

## Cult subcommands (`cu`/`cult <sub>`, debug)

All cult subcommands act on the first player cult (`game.cults[0]`); they print
`No cult found.` if none exists. `cu`/`cult` alone lists them in-game.

| Command            | Effect                                                             |
|--------------------|--------------------------------------------------------------------|
| `cu gr`            | give +10 to all cult resources and +100k money                     |
| `cu br [amount]`   | give base resources — +flesh/blood/bone (default 100)              |
| `cu def [cultID]`  | add a rival base-defense ordeal (random active rival if no ID)     |
| `cu tdef`          | add a team base-defense ordeal                                     |
| `cu t`             | advance one cult turn                                              |
| `cu u1`            | upgrade a random free level-1 follower to level 2                  |
| `cu r [power]`     | recruit a follower — power is `combat`/`media`/`lawfare`/`corporate`/`political` (default `combat`) |
| `cu po [power] [idx]` | add a profane ordeal — `po` lists powers, `po <power>` lists that power's ordeals, `po <power> <idx>` adds one |

## Useful checks while developing a mod

- `mods` — confirm your mod is `enabled` (not `failed`/`disabled`).
- `mods errors` — read the stack if your mod failed to load.
- `give item mod-mymod-trinket` (with `.debug`) — confirm registered content is
  grantable.
- `give skill mod-mymod-lockpicking 50` (with `.debug`) — confirm a registered
  skill.

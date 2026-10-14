# Sound generation (AI SFX)

The `fal-sfx` MCP → `sounds-src/<area>/` → `make sounds` → `app/sound/` pipeline. Loaded on demand;
`CLAUDE.md` keeps one row pointing here.

**New findings go here, not into `CLAUDE.md`.** One bullet per lesson, the number that proves it
inline. When a lesson invalidates an old bullet, replace it rather than appending a second.

## The rules

- **EVERY NEW SOUND GETS A BAKE-OFF: one take on each of `elevenlabs`, `sonilo` and `cassette`, then
  the user picks by ear.** It is cheap enough to never skip: a 20 s loop costs **$0.04 + $0.036 +
  $0.01 = $0.086** across the three. The per-second prices do not predict the winner. In the first
  corp bake-off ElevenLabs won 2, Sonilo 3 and CassetteAI 1, and on two sounds ElevenLabs and Sonilo
  were both judged good. Do not pick the winner yourself; the measurements below can rule a take OUT
  but never in.
- **Measured preference, from the user's listening:** ElevenLabs SFX v2 is best for nuanced, quiet
  ambients; Sonilo v1.1 is second; CassetteAI is sometimes good (it won the CCTV whine).
- **Stable Audio 3 is NOT FOR AMBIENTS.** It lost every sound of the bake-off, and every take FADES
  OUT: the last 50 ms measured **6-49 dB** under the first. The seam crossfade then blends that fade
  into the loop and leaves a dip. It stays in the MCP for one-shots, where a fade-out tail is harmless.
  It is the only model that takes a `seed`.
- **MIRELO IS GONE, NEVER BRING IT BACK.** `mirelo-ai/sfx1.6` costs $0.01/s, **5x** ElevenLabs. It won
  none of the 7 sounds, and was **$1.40 of the $2.15** bake-off. Its native loop seams were clean;
  that bought nothing the bake's crossfade does not.
- **AN AMBIENT LOOP MUST NOT CARRY A DISTINCT EVENT.** The printer was dropped outright: the takes
  were good, but a print run repeating every 20 s reads as a broken record, not a room. An occasional
  bubble in a cooler hum passes; a recognisable action does not. Brief an object loop as a STEADY
  state.
- **THE WORLD IS ALWAYS NIGHT** (there is no day/night cycle): every outdoor brief ends in "at
  night". The facility's first birds were a daytime chirp and were re-rolled as night birds.
- **No sirens, no dog barks, no voices** in an ambience: they read as a real alert or an actor.
- **Write the brief per sound, plus the area's style tail.** `art/sounds.json`'s `style` is appended
  verbatim, like `textures.json`'s. Corp uses: *"clean modern corporate office building interior,
  close-miked, dry, realistic field recording, no music, no voices"*.
- **Loudness is the bake's job, not the prompt's.** The raw takes ranged **-9.9 to -63 LUFS**; one
  static gain puts every one on the entry's target.

## The pipeline

1. **Generate with `generate_sfx`** (`~/git/fal-sfx-mcp`): `model`, `prompt`, `name` (the sound's name inside its area, NO area prefix: `vent`, not `corp-vent`),
   `area`, `duration`, `loop`, plus optional `seed` and `variants` (1-4).
   - It writes `sounds-src/<area>/<name>-<model><N>.wav`, 16-bit 44.1k, and never overwrites a file.
   - With `register` on (the default) it appends the take to `art/sounds.json` with its prompt,
     model, endpoint, seed, measured duration and cost.
   - For a bake-off pass `register: false` and `area: "<area>/_bakeoff"` — FLAT, **never a
     sub-folder per sound** (asked for: one folder to listen through). The file names already say
     the sound and the model. Keep the losers out of the manifest, or `make sounds` ships them as
     variants.
2. **Adopt the winner.** Move it to `sounds-src/<area>/<name>-<model>1.wav`, add its entry to
   `art/sounds.json` (or re-run it with `register` on). **Move the losers to
   `sounds-src/unused/<area>/`, never delete them** (asked for: a runner-up is often right somewhere
   else, as the washroom's sonilo take is for the facility).
3. **Bake with `make sounds`** (`tools/sounds.py`). Each variant becomes
   `app/sound/<area>/<name><N>.mp3`, and the game key is **`<area>/<name>`** (`corp/rack`):
   - N is the take's POSITION in the entry, and the `-<model>` part is dropped, so takes from two
     models can sit in one key without colliding;
   - the audio is downmixed to mono (nothing in the game pans);
   - a one-shot has its leading silence trimmed;
   - a loop that the model did not loop natively gets an equal-power (`qsin`) crossfade from its tail
     into its head, `seam_ms` long, so the file comes out that much shorter;
   - a 40 Hz high-pass, 12 dB/octave (two poles; one pole was too gentle, asked for), cuts rumble. A loop is
     filtered as two copies back to back and the second kept, so the filter's state at the head is
     what the tail left: measured on `city/warehouse`, the wrap step stayed 51 against a p99
     sample-to-sample step of 406, and the length unchanged;
   - one static gain is applied to `lufs` (`default_lufs` if unset), followed by a -1 dBFS limiter;
   - the result is encoded at `default_bitrate`.
4. **Self-check** with `python3 tools/sounds.py --check`. On synthetic audio in a temp dir it asserts:
   mono output, target loudness within 1 LU, the seam length, two models' takes landing as variants 1
   and 2, and the old-sound refusal.

The game picks the new mp3 up with no further code change. The main process's
`MainElectron.listSoundFiles` lists `app/sound/` plus its sub-folders, as forward-slash paths. This is
a MAIN-process handler, so a change to it needs an app restart; `make reload` does not pick it up.
`Sounds.hx` then groups `<area>/<key><digit>.mp3` into one key with random variants, and plays it
from `sound/<area>/<key><N>.mp3`. **`area` is one plain folder name with no dot**, because the key is
cut at its first `.`. The bake refuses anything else.

### Manifest (`art/sounds.json`, tracked)

- **Top level:** `style`, `default_lufs` (-26), `default_bitrate` (128k), `seam_ms` (500), `sounds{}`.
- **Keyed by the game key `<area>/<name>`** (`facility/vent`), so two areas can each have a `vent`.
- **Per key:** `area`, `loop`, optional `lufs`, and `variants[]`. Each variant holds `file`, `model`,
  `endpoint`, `prompt`, `duration`, `seed`, `cost`, `native_loop` and `generated`.
- **`native_loop`** is true only when ElevenLabs was sent its `loop` flag. A native loop is never
  crossfaded.
- **Bake state:** `last_converted`, `last_sig` and `last_outputs`. A key rebuilds when a wav is newer,
  when `lufs`, bitrate, `loop` or `seam_ms` changes, or when an output is missing.

## In game: positional sounds

### Where a sound is heard from: `src/SoundPath.hx`

Every positional sound, loop or one-shot, measures the PATH from the player, not the straight line.
- A search runs out from the player's cell: 8-way, a diagonal costs 1.41, and a diagonal may not cut
  past a blocked corner.
- A cell passes sound when `area.canSeeThrough` says so AND it holds no closed `Door`. **A glass door
  is see-through when shut**, so the door is checked on its own (`SoundPath.doorsOf`, built once per
  area by a caller that searches every frame).
- **Distance is to the source's FACE.** A source cell that passes sound is 0 itself (a cooler, a
  vending machine: both walkable). A blocked source (a rack, a vent in a wall, a shut door) gives 0
  to the passable cells around it. Measured with the old rule (full at d ≤ 1): standing on the
  cooler and next to it both played 100%, reported as "adjacent sounds the same as one tile away".

### One-shots: `Sounds.playNow` with `x,y`

~22 call sites go through it: AI barks (`AI.emitSound`), shots, splats, doors, arrivals, phone and radio.
- Within `listenRadius` (10) by a way round: `effectsVolume × (1 - d/10)`, linear as before.
- **No way round: the straight line through the wall at -18 dB** (`SoundPath.MUFFLE` 0.126). Asked
  for: a fight behind a shut door is dull, not silent.
- Past 10 straight-line cells: silent, **except the alert cues** `ai-arrive-*`, `ai-phone`,
  `ai-radio`, which keep the old 10% floor (they warn of police and calls). It used to be 10% for
  everything, through every wall.
- Measured at effects 50: open way, 3 cells → **40**; same distance behind a wall → **4.4**; 12 cells
  → nothing; `ai-phone` at 12 → **5**. `debugSoundEnabled` prints the path and the fraction.
- `opts.volume` (0-100) skips all of it: a caller that worked its level out itself.

### Loops: `render/AreaSounds.hx`

A loop goes through `Sounds.updateLoop(key, frac, base)`. It is lazy: created on its first audible
frame, then never stopped, only set to volume 0, so crossing the edge of a range does not restart it.
`onEnterArea` zeroes every loop. Every loop is an `AreaSounds` kind on `ambientVolume`, the barrel
fire included. A kind with several variants (`city/store1/2`) picks one AT RANDOM when its loop is
created and keeps it for the session, since the loop is never dropped.
- **`gate`** (optional) counts a source only while it returns true: the slums' failing lamps buzz
  only while lit (`LightCone.ConeSet.on`).
- **Level:** `(1 - d/range)^2`, squared because linear amplitude barely moves near the source.
  Measured on the cooler (range 2, -8 dB at the time, slider 100): on it **39.7**, next to it
  **10.0**, one more tile **0**. Only the nearest source of each kind counts.
- Eased over 2 x `BASE_MS` (raw dt), so a step, or a door closing, fades rather than cuts.
- **`duty`** cycles a kind on and off (each phase 0.5-1.5x its mean): the fridge's compressor.
- **Ceilings:** no panning, and a wall is all or nothing for a LOOP (no partial muffling).

### Intermittent ambience: `AreaSounds` events

A one-shot every `gap` seconds or so (each roll 0.5-1.5x), from a random one of its cells within
`range` by PATH, at `ambientVolume × (1 - d/range)^2 × gain` through `AreaSounds.once`. A roll with
no cell in reach plays nothing, so an event is never heard through a wall.
- **AN EVENT IS THE ROOM, NOT AN ACTION.** Asked for, and refused for microwave, kettle, coffee
  machine, toaster, printer and an at-the-stall flush: those are something SOMEONE DOES, and with
  nobody there doing it they read as a ghost. A phone ringing unanswered, a tap dripping and a toilet
  flushing behind the wall are things a building does by itself.
- **A ring must not sound like `ai-phone`**, which means "someone just called the police".

### Tuning: `render/SoundSources.hx` `DB`, the one table

`updateLoop` and `once` multiply in the kind's gain from `DB`, tuned in sound mode (`X` in
street-debug, see [`debug-surface.md`](debug-surface.md)), which copies the changed lines to paste
back. The volume is clamped at 100, so a gain over 0 dB is lost at a full slider: a kind that should
be tunable UP gets its headroom from the bake — the beds are baked at **-36** LUFS and pulled to
-42 (level with the corridor bed's -42.1) by **-6.0**. Reported as "the room bed does not change
when I scroll": it sat at 0 dB and 100%, so every notch up was clamped. The corridor bed is a shipped
file at 0 dB and can only be tuned DOWN. History: the corp machines went in at -8 (cooler -16) and
were raised 6 dB after listening, because they sat far under the one-shots.

### Corp: `render/corp/CorpSounds.hx`, driven from `CorpArea.tick`

| key | sources | type | range (path cells) |
|---|---|---|---|
| `corp/rack` | `fit == CorpFurniture.FIT_RACK` (server room and security wall racks) | loop | 5 |
| `corp/elevator` | `elevator` objects | loop | 4 |
| `corp/vending` | `CorpDeco.cells(K_VENDING)` | loop | 3 |
| `corp/cctv` | `CorpSecurity.videoCells` | loop | 3 |
| `corp/cooler` | `CorpDeco.cells(K_COOLER)` | loop | 2 |
| `corp/window` | outer glazing, `TILE_CORP_WINDOW1..V3` (~120 cells a floor) | loop | 2 |
| `corp/fridge` | `CorpDeco.cells(K_FRIDGE)` | loop, duty 40 s on / 60 s off | 3 |
| `corp/phone` | `CorpDeco.cells(K_PHONE)` (`CORP_TABLE_PHONE`, ~13 a floor) | event, gap 60 s | 4 |
| `corp/drip` | `K_TAP` cells plus washroom basins (a fixture in a run) | event, gap 16 s | 2 |
| `corp/flush` | none: the washroom bed's own event, at the bed's level | event, gap 80 s | — |

- **Beds**, crossfaded one-hot over 4 x `BASE_MS`, picked off `generatorInfo.getRoomAt`:
  `ambient-corp` (corridor), `corp/room`, `corp/cubicle` (`ROLE_CUBICLE`, the computers' hum) and
  `corp/washroom` (`ROLE_TOILET`, the pipes).
  - Doorways are in no room rect, so they are corridor. The reception IS a room rect but plays the
    corridor bed: its counter replaces the front wall. The lift's 9 cells are in no rect but count
    as a ROOM (asked for: no corridor bed in the lift). A room whose save has no `role` takes `room`.
  - Corp's `AreaInfo.ambient` is `AMBIENT_NONE`. **Never alternate `setAmbient` for this:** SM2's
    `createSound` with an id that already exists returns THE SAME object, so a fade-in and a fade-out
    fight over one sound.
  - Measured: stepping from a corridor into a cubicle, the corridor bed went 0.93 → 0.54 (300 ms) →
    0.04 (1.8 s).
- **Corp has no vents**: `BLDG_VENT` is never laid by the corp generator, so `corp/vent` had no
  source on any floor. The loop moved to the facility.

### Facility: `render/facility/FacilitySounds.hx`, driven from `FacilityArea.tick`

The clone of `CorpSounds`, with the outdoors split off. Facility's `AreaInfo.ambient` is
`AMBIENT_NONE`; the 2D underground lab still plays `ambient-facility` through `setAmbient`.

| key | sources | type | range (path cells) |
|---|---|---|---|
| `facility/vent` | `vent` objects, on WALL cells | loop | 3 |
| `corp/rack` (reused) | `m.deco` `FIT_RACK`, `FIT_RACK_LOW` | loop | 5 |
| `facility/machine` | `FIT_MACHINE`, `FIT_ANALYSER` | loop | 3 |
| `facility/generator` | `FIT_GENERATOR` (hangar, 2-3) | loop | 6 |
| `corp/fridge` (reused) | `decoration` frames 8/0 (fridge), 8/1 (freezer) of `FIT_CABINET` | loop, duty 40/60 | 3 |
| `corp/drip` (reused) | `m.tableSink` (lab sinks) + `FIT_BASIN` | event, gap 16 s | 2 |
| `facility/drain` | `m.drain` (`floor_drain` objects) | event, gap 40 s | 2 |
| `facility/birds` | tree tiles `TILE_TREE1..TILE_BUSH-1` (~280 cells) | event, gap 20 s, night birds | 6 |
| `facility/car` | `Surf.ROAD` (~260 cells) | event, gap 45 s, 3 variants | 8 |
| `corp/flush` (reused) | none: the washroom bed's event | event, gap 80 s | — |
| `facility/pa` | none: at the summed level of the four INDOOR beds, so never outdoors | event, gap 180 s | — |

- **Beds**: `ambient-facility` (corridor, doorways: indoor and in no room rect), `facility/lab`
  (every room rect, offices and stores included — asked for), `facility/washroom` (`ROLE_TOILET`),
  `facility/hangar` (`FacilityModel.inHangar`, asked FIRST: the hangar is a room rect with a null
  role, like a lab), `facility/park` (`Surf.GRASS` and the paths through it, `FacilityModel.isParkPath` — asked
  for: the path is the park, not the exterior), `facility/exterior` (any other outdoor cell).
  Baked at -36, DB -4 = the corridor's measured **-40.0**. Measured at slider 100: each bed 62.2 in
  its own zone, the others 0-0.9 (the tail of the fade); corridor 98.6.
- **A reused corp key shares its DB gain**: tuning `corp/rack` in either area moves both.
- **An event over a DENSE cell set plays mostly far away.** It picks a random in-range cell, and with
  ~280 tree cells most are 4-6 away: birds measured **0.1-0.5** next to a tree, against drip **7.9**.
  Ceiling of the random pick; weight it to the nearest when that matters.
- `exterior-sonilo1` became the wilderness's `wild/road`. The day birds are in `unused/facility/`
  as `birds-*-day.wav`.

### Military base: `render/military/MilitarySounds.hx`, driven from `FacilityArea.tick`

Played INSTEAD of `FacilitySounds` in a base, which is drawn by the facility renderer. The base's
`AreaInfo.ambient` is `AMBIENT_NONE`, so the old `ambient-military` bed no longer plays.

| key | sources | type | range (path cells) |
|---|---|---|---|
| `military/fence` | `TILE_MIL_FENCE`, `TILE_MIL_FENCE_TORN` (the whole ring) | loop | 2 |
| `military/idle` | `TILE_MIL_HUMVEE` origins (every parked humvee) | loop | 5 |
| `military/radio` | the `safe` object (one per base, in the HQ armory) | loop, 2 variants | 4 |
| `military/generator` | `FIT_GENERATOR` in the hangar | loop, gain -9 (the facility's -3 picked as too loud) | 6 |
| `military/vent` | `vent` objects | loop, 2 variants | 3 |
| `military/truck` | `Surf.ROAD` past the gate | event, 2 variants, gap 45 s | 8 |
| `military/drip` | `TILE_MIL_SINKS` (the latrine's basins) | event, 2 variants, gap 16 s | 2 |
| `military/squelch` | `TILE_MIL_RADIO_RACK` (the comms room's racks) | event, 2 variants, gap 25 s, DB -12 | 4 |
| `military/flush` | none: the latrine bed's own event, at the bed's level | event, 2 variants, gap 80 s, baked -36 | — |
| `military/jet`, `city/helicopter` (reused), `military/range` | none: far one-shots, gaps 150 / 200 / 120 s | event, 2 variants each (heli: city's) | — |

- **Beds**: `military/latrine` and `military/comms` (`ROLE_LATRINE` / `ROLE_COMMS` off
  `generatorInfo.getRoomAt`, asked for: "latrine needs its sounds, bed, sink and events ... so does
  comms"; DB -5 / -6, measured 56.2 and 50.1 at slider 100 in their rooms, indoor bed 0.0 there),
  `military/room` (any other room rect under a roof; asked for as "default room bed, quieter one than
  corridor", the ElevenLabs take of a bake-off, DB -10 = the corridor's -4 less six: measured 31.6 in
  a barracks against the corridor's 63.1), `military/indoor` (the rest of the roof: corridors and
  doorways, which are in no room rect), `military/hangar` (2 variants),
  `military/yard` (open ground inside the fence), and the margin outside the fence wears its terrain
  band's own wild bed (`wild/forest`, `wild/plains`, `wild/mountain`), split by
  `AreaGame.isOutsideBase`. Within 4 rows of the road's centreline it is the wilderness highway's
  `wild/road` instead, as in `WildSounds`. Indoor, hangar and yard are baked at -36, like every bed.
- The helicopter is the only key still borrowed (`city/helicopter`).
- **A far one-shot is loudest in the open**: full on the yard and margin beds, 0.4 under a roof.
- Measured at slider 100 on a fresh base: each bed 63.1 in its own zone (road 62.7 on the road,
  plains 0.4 there); fence 7.9 one cell off the ring; radio 14.1 beside the safe; idle 10.6 at the
  motor pool.
- **`military/floodlight` was cut** on the user's ear after it shipped; its take stays in
  `sounds-src/military/` and its entry in `art/sounds.json`, unplayed.
- **The klaxon from the plan was dropped unheard**: an alarm-like one-shot reads as a real alert, and
  alerts are a gameplay state in a base.
- `yard-sonilo1-day.wav` in `unused/military/` was judged good for a DAY base. There is no day yet.

### Underground lab: `render/lab/LabSounds.hx`, driven from `LabArea.tick`

The lab is `AMBIENT_NONE`; everything it sounds like is here. `LabSounds` holds the area it was built
for, and `LabArea` hands it the rebuilt vat set (`setVats`) so the vat cells refill in place.

| key | sources | type | range (path cells) |
|---|---|---|---|
| `lab/bubble` | the four vat roots, gated off as each is purged | loop | 4 |
| `lab/cryo` | cryobank, cold bank, cryo pod, stasis pod, SR-203 | loop | 3 |
| `lab/centrifuge` | the centrifuge cylinder | loop | 4 |
| `lab/incubator` | incubators, embryonic unit, specimen racks and cases, bio-printer, gestation ring | loop | 3 |
| `lab/console` | the console machines and every computer desk | loop | 3 |
| `lab/buzz` | the sputtering ceiling fixtures (`LabLamps` phase != 0) | loop | 2 |
| `lab/vent` | the corridor's strip-light cells (the lab has no vent objects) | loop | 3 |
| `lab/lift` | the lift car's cell | loop, ungated | 4 |
| `lab/klaxon` | every door, gated on the lead's alarm (`leadTriggerDone`) | loop | 8 |
| `lab/drip` | the vat cells | event, 2 variants, gap 14 s | 3 |
| `lab/knock`, `lab/hiss` | the pump machines (reactor, piped capsule, UPW, dial tank, switch rack); hiss also the cryo set | event, gaps 30 / 25 s | 5 / 4 |
| `lab/thump` | the caged units (hatch box, tentacle console, sheeted cage, cage case) | event, gap 40 s | 4 |
| `lab/shaft` | the lift | event, 2 variants, gap 35 s | 6 |

- **Beds**, one-hot over 4 x `BASE_MS` off `generatorInfo.getRoomAt`: `lab/lobby`, `lab/vat`,
  `lab/workshop`, `lab/storage`, `lab/research` by room role, `lab/corridor` anywhere else (corridor,
  doorways), and `lab/dead` in the vat chamber once the lab has died. All baked at -36.
- **The lab dies** when all four vats are purged: every machine loop is gated off, the vat chamber's
  bed crossfades to `lab/dead`, `lab/powerdown` (2 variants) plays once area-wide, and the tannoy
  (`lab/pa`, every ~180 s at the beds' level) stops. The klaxon keeps going: it is on battery.
- **One-shots off the lab's state**: `lab/purge` and `lab/drain` at a vat as it is purged;
  `lab/arrive` once as the car starts down on entry; `lab/depart` replaces `object-elevator` when
  `Elevator.onAction` leaves the lab; `lab/door-open` / `lab/door-close` replace the door kinds
  (`Door.soundKey`).
- **Cut on the user's ear before shipping**: `lab/incinerator` ("it's off") and `lab/pump` ("too loud,
  no need"); every take of both is in `sounds-src/unused/lab/`. The pump machines still knock and hiss.
- **"Very quiet" is the raw take, not the bake**: research came back at -49.9 LUFS and vat at -46.4,
  and the bake lifted both to -36.4 like every other bed.
- Measured at slider 100, seed 9: each bed 50 in its own room; bubble 17 beside a vat; console 9-14,
  cryo 9, incubator 9 in range; klaxon 5 at the vat pads, far from a door. Purging all four fired
  purge + drain four times, powerdown once, and swapped the vat bed for dead.

### City: `render/CitySounds.hx`, driven from `CityArea.tick`

Each tier (`area.typeID`: slums `AREA_CITY_LOW`, medium, downtown `AREA_CITY_HIGH`) has its own three
beds and its own one-shots; the loops are shared. All three tiers are `AMBIENT_NONE`.
- **Beds**, one-hot over 4 x `BASE_MS`, off `city.tiles`: MAIN = a Road cell inside some 4x4 all-Road
  square (only the 4-wide main road has one) or a Walkway next to one; STREET = any other Road or
  Walkway; ALLEY = Alley. Keys `city/<tier>-main|street|alley`, tiers `slums`/`medium`/`downtown`.
  Baked -36, DB -4. The medium street was the old shipped `ambient-city` until it got its own bake
  (asked for); `ambient-city` now plays nowhere in 3D.

| key | sources | type | range |
|---|---|---|---|
| `city/diner`, `city/store`, `city/laundromat` | open cells 4-adjacent to an OPEN shop (`Building.shop` 0, 1, 3, `shopOpen`) | loop | 3; no diner or store in the slums (asked for: they are all broken) |
| `city/warehouse` | around `WorldCtx.style.isSpecial(b.facade)`, ONE IN THREE by position | loop | 4 |
| `city/sewer` | `sewer_hatch` objects | loop | 2 |
| `city/lampbuzz` | `SceneBundle.flickCells`, gated on the flicker (slums) | loop | 2 |
| `ambient-fire` | `burning_barrel` objects (was `LampShadows.driveFireLoop`: straight-line, on screen only, effects slider) | loop | 4 |
| slums: `city/bottle`, `city/can`, `city/rats` | Alley cells | event, gap 40/35/30 s | 6/6/4 |
| slums: `city/crackle` | barrels | event, gap 8 s | 4 |
| slums: `city/screendoor` | none | event, gap 70 s | — |
| medium: `facility/car` (reused) | Road | event, gap 30 s | 8 |
| medium: `city/shopbell`, `city/garage` | open shops / open garages (shop 2) | event, gap 40/25 s | 4/5 |
| medium: `city/horn` | none | event, gap 60 s | — |
| downtown: `facility/car` (reused) | Road | event, gap 15 s | 8 |
| downtown: `city/horn`, `city/helicopter` | none | event, gap 25/240 s | — |

- **The play button's preview follows the wheel** (`Sounds.previewRetune`): asked for, the dB moved and
  the sound playing did not.
- **Warehouses are thinned to one in three** (`(col*31 + row*17) % 3`): a medium city has ~40 of 220
  buildings, and all of them humming covered most of the streets.
- `city/busbrake` was baked and dropped ("bad"). The slums alley was re-rolled: the first takes had
  a metallic rattle (the brief said "shacks" and "gutters"); the brief now says dilapidated brick.

### Wilderness: `render/wild/WildSounds.hx`, driven from `WildArea.tick`

`AREA_GROUND` is `AMBIENT_NONE`. The band is `Terrain.bandAtArea` (as `WildBand.use`).
- **Beds**: `wild/forest`, `wild/plains`, `wild/mountain`, and `wild/road` within 4 cells of the
  highway's centreline (`WildRoad.distTo`) where the area has one — the facility exterior's sonilo
  take, earmarked for it. Baked -36, DB -4.
- **Events**: `facility/car` on road cells (8, gap 45) in every band; forest `wild/owl` (trees, 8, gap
  40) and `wild/twig` (trees and bushes, 3, gap 25); plains `wild/coyote` (none, gap 120); mountain
  `wild/rockfall` (`TILE_ROCK`/`ROCK_LARGE`, 6, gap 35). `wild/gust` was baked and dropped ("bad
  everywhere").

### Sewers: `render/sewer/SewerSounds.hx`, driven from `SewerArea.tick`

`AREA_SEWERS` only, and it is `AMBIENT_NONE`. `SewerArea` also renders `AREA_HABITAT`, which keeps
`ambient-habitat` through `setAmbient` (`sounds` stays null there). A sewer area exists only as a
mission map, off the region grid: to test one, `region.createArea('AREA_SEWERS')` then
`setLocation(LOCATION_REGION)`, `setLocation(LOCATION_AREA, area)` (`go area` cannot reach it).

| key | sources | type | range |
|---|---|---|---|
| `sewer/tunnel` / `sewer/chamber` | beds, one-hot on `model.room` (the 5x5 rooms) | bed | — |
| `sewer/manhole` | `sewer_exit` objects: the street seeping down the shaft | loop | 5 |
| `sewer/trickle` | midpoint of each `SewerWater.layout(m).streams` spine | loop | 2 |
| `sewer/pipe` | `SewerProps.places` for `sewerPipe` + `sewerCable` | loop | 3 |
| `city/lampbuzz` (reused) | flickering wall lamps (`phase > 0`), gated on `wallGlow.on` | loop | 2 |
| `sewer/drip` | `layout.pools` | event, gap 12 s | 4 |
| `sewer/rats` | `SewerDebris.build(m)` litter (~250 cells) | event, gap 30 s | 5 |
| `sewer/knock` | pipe and cable props | event, gap 45 s | 6 |
| `sewer/rumble`, `sewer/surge` | none | event, gap 90 / 60 s | — |

- Wall lamp `i` is `lampPosts[m.lamps.length + i]` and `wallGlow.on[i]`: the wall posts follow the
  node posts, pushed in the glow set's order. Measured: the lamps are dark ~20% of the time, and the
  buzz eased 0.43 → 0 through an outage and back to 1.
- `sewer/cover` (a car over the manhole cover) was baked and dropped.

## Levels (measured with ebur128, 2026-10-08)

| file | LUFS | role |
|---|---|---|
| `ambient-fire.mp3` | -26.4 | the positional-loop peer, and the `default_lufs` source |
| `ambient-corp1.mp3` | -42.1 | the area bed under it |
| `object-elevator.mp3` | -29.6 | one-shot |
| `door-glass-open1.mp3` | -32.8 | one-shot |
| `attack-pistol1.mp3` | -16.3 | one-shot, the loud end |

The baked corp loops land at **-26.4** (cooler **-27.2**: the limiter trims its glug peaks).

## Models (fal.ai, prices from `/v1/models/pricing`, 2026-10-08)

| `model` | endpoint | price | range | notes |
|---|---|---|---|---|
| `elevenlabs` | `fal-ai/elevenlabs/sound-effects/v2` | $0.002/s | 0.5-22 s | native `loop` |
| `sonilo` | `sonilo/v1.1/text-to-sound-effects` | $0.0018/s | 0.5-180 s | inaudible provenance watermark |
| `cassette` | `cassetteai/sound-effects-generator` | $0.01/clip | 1-30 s | whole seconds only |
| `stableaudio` | `fal-ai/stable-audio-3/small/sfx/text-to-audio` | $0.0206/clip | 1-120 s | seed; fades out, never ambient |

- **Costs are COMPUTED from that table:** fal's results carry no cost. `FAL_KEY` cannot read the
  usage API ("not permitted"), so the real bill is only on the fal dashboard.
- **None of the newer music models is wired:** music is out of scope. fal has Lyria 3/3.5, ElevenLabs
  Music and MiniMax Music 3.

## Traps

- **A take can come back CLIPPED, and the bake cannot fix it.** The first elevenlabs phone peaked at
  0 dBFS with 11 clipped samples (`astats` "Peak count") and was audibly distorted; the bake's gain
  and limiter only move a broken waveform up or down. Screen every take's peak and peak count
  before the user listens: a take at 0 dBFS with a peak count over ~2 is OUT.

- **ElevenLabs' `pcm_44100` is NOT headerless on fal.** fal wraps it in a RIFF header (`audio/L16`,
  2 channels). Decoding it as raw s16le mono made a 1 s take **2.00 s** long and an octave low.
- **A key may not end in a digit or contain a `.`.** The game reads a trailing digit as the variant
  and cuts the name at the first dot. `generate_sfx` refuses such a name.
- **ElevenLabs returns SILENCE for a prompt that asks for quiet.** It happened on 2 of 10 takes:
  - `cctv` ("thin... faint") came back at **-63 LUFS**;
  - the room tone ("quiet... soft... faint") at **-65.3**; re-rolled with those words dropped, it
    came back at **-37.7**.

  Loudness is the bake's job: brief the CHARACTER, never the level. Measure before listening.
- **ffmpeg 4.4's `alimiter` auto-levels by default.** The bake passes `level=0`, or the limiter would
  push the gain back up after the static gain had set it.
- **The seam crossfade survives the mp3 encode, but the browser loop may not.** SoundManager
  re-starts an HTML5 `<audio>` for each loop, which is the same ceiling `ambient-fire` already lives
  with. Listen in game before calling a loop seamless.

## Bake-off log

| date | area | sounds | winners | cost |
|---|---|---|---|---|
| 2026-10-09 | corp | rack, vending, cooler, printer, cctv, elevator, vent (20 s loops, 5 models) | rack, vending: elevenlabs · cooler, elevator, vent: sonilo · cctv: cassette · printer: dropped (too distinct for a loop) | $2.146 |
| 2026-10-09 | corp | cubicle, washroom, window, fridge (loops) · flush, phone, drip (one-shots) | cubicle, window, drip: elevenlabs · fridge, washroom: cassette · flush: sonilo (baked -36, "must be quieter") · phone: elevenlabs, third roll (the first take CLIPPED: 0 dBFS, 11 clipped samples, audibly distorted; a softer "gentle low-volume warble, no distortion" brief fixed it) · washroom sonilo kept for the facility | $0.58 |
| 2026-10-10 | facility | lab, hangar, park, exterior (beds) · machine, generator (loops) · drain, pa, birds, car (one-shots) | lab, hangar, exterior, machine, generator: elevenlabs · park, pa: sonilo · drain: cassette + elevenlabs (2 variants) · birds, car: all three as variants 1-3 · pa cassette CLIPPED (0 dBFS, peak count 6), out unheard · exterior sonilo kept for the wilderness | $0.67 |
| 2026-10-10 | city, wild | 8 city beds, 6 city loops, 10 city one-shots, 3 wild beds, 5 wild one-shots, night birds | city: diner, downtown alley/main/street, horn, rats, sewer: elevenlabs · bottle, can, garage, helicopter, lampbuzz, laundromat, medium alley/main, screendoor, shopbell, slums main/street, store, warehouse: elevenlabs + sonilo (2 variants; bottle, horn, garage elevenlabs and can, helicopter sonilo had screened CLIPPED and were picked by ear anyway) · crackle: cassette + sonilo · busbrake: dropped · slums alley: re-rolled (metallic), "quiet" in the brief gave elevenlabs -60 / sonilo -53 LUFS, re-rolled again without it, sonilo won · wild: coyote, forest, rockfall: elevenlabs · mountain: elevenlabs, then swapped for sonilo (raw -56.7 LUFS, baked up 20 dB) · owl, twig: elevenlabs + sonilo · plains: cassette · gust: dropped · birds: elevenlabs | $2.17 |
| 2026-10-10 | city | medium-street (bed, replaces `ambient-city`) | elevenlabs | $0.09 |
| 2026-10-10 | sewer, wild | tunnel, chamber (beds) · manhole, trickle, pipe (loops) · drip, rats, knock, cover, rumble, surge (one-shots) · forest re-roll | chamber, drip, manhole, pipe, surge: elevenlabs · knock, rats, rumble, trickle: elevenlabs + sonilo (knock sonilo and trickle elevenlabs had screened CLIPPED, picked by ear) · tunnel: cassette + elevenlabs · cover: dropped · forest elevenlabs came back -52 LUFS ("barely any wind"), re-rolled; sonilo won | $0.77 |
| 2026-10-10 | military | yard, indoor (beds) · floodlight, fence, idle, radio (loops) · jet, range (far one-shots) | fence, floodlight, yard: elevenlabs · idle: sonilo · indoor, jet, radio, range: elevenlabs + sonilo · radio, range, jet cassette had screened CLIPPED (296 / 2,567 clipped samples, 0 dBFS), lost by ear anyway · yard sonilo kept as a day bed | $0.68 |
| 2026-10-10 | military | hangar (bed) · generator, vent (loops) · truck (one-shot); replacing the facility's | generator: elevenlabs (gain -9, "make quieter") · hangar, truck: elevenlabs + sonilo (hangar sonilo fades out 39 dB at its tail, picked by ear anyway) · vent: cassette + sonilo | $0.31 |
| 2026-10-11 | military | latrine, comms (beds) · drip, flush, squelch (one-shots) | latrine: sonilo · comms: elevenlabs · flush: elevenlabs ×2, both screened CLIPPED (16 and 8.5 peaks, the second a "no distortion" re-roll) and picked by ear ("both 11labs are ok") · squelch: elevenlabs (re-roll) + sonilo (re-roll, 3 peaks at 0 dBFS); both first takes CLIPPED (15.5, 5) · drip: cassette + elevenlabs · flush cassette CLIPPED (36), re-rolled clean, lost | $0.29 |
| 2026-10-13 | lab | lobby, corridor, vat, workshop, storage, research, dead (beds) · bubble, pump, cryo, centrifuge, incubator, console, buzz, vent, lift, incinerator, klaxon (loops) · drip, knock, hiss, thump, shaft, pa, purge, drain, powerdown, arrive, depart, door-open, door-close (one-shots) | arrive, buzz, centrifuge, dead, depart, door-open, door-close, knock, pa, purge: sonilo · bubble, console, corridor (sonilo "fine but not so horror"), cryo, drain, hiss, klaxon, lift, lobby, research, storage, thump, vat, vent, workshop: elevenlabs · drip, powerdown, shaft: elevenlabs + sonilo · incubator: cassette · incinerator, pump: cut | $2.02 |

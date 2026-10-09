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
   - For a bake-off pass `register: false` and `area: "<area>/_bakeoff/<name>"`. Keep the losers out
     of the manifest, or `make sounds` ships them as variants.
2. **Adopt the winner.** Move it to `sounds-src/<area>/<name>-<model>1.wav`, add its entry to
   `art/sounds.json` (or re-run it with `register` on), and delete the `_bakeoff` folder.
3. **Bake with `make sounds`** (`tools/sounds.py`). Each variant becomes
   `app/sound/<area>/<name><N>.mp3`, and the game key is **`<area>/<name>`** (`corp/vent`):
   - N is the take's POSITION in the entry, and the `-<model>` part is dropped, so takes from two
     models can sit in one key without colliding;
   - the audio is downmixed to mono (nothing in the game pans);
   - a one-shot has its leading silence trimmed;
   - a loop that the model did not loop natively gets an equal-power (`qsin`) crossfade from its tail
     into its head, `seam_ms` long, so the file comes out that much shorter;
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
- **Keyed by the game key `<area>/<name>`** (`corp/vent`), so two areas can each have a `vent`.
- **Per key:** `area`, `loop`, optional `lufs`, and `variants[]`. Each variant holds `file`, `model`,
  `endpoint`, `prompt`, `duration`, `seed`, `cost`, `native_loop` and `generated`.
- **`native_loop`** is true only when ElevenLabs was sent its `loop` flag. A native loop is never
  crossfaded.
- **Bake state:** `last_converted`, `last_sig` and `last_outputs`. A key rebuilds when a wav is newer,
  when `lufs`, bitrate, `loop` or `seam_ms` changes, or when an output is missing.

## In game: positional object loops

A looping sound tied to world objects goes through `Sounds.updateLoop(key, frac, base)`. It is lazy:
the loop is created on its first audible frame, then never stopped, only set to volume 0 so that
crossing the edge of a range does not restart it. `onEnterArea` zeroes every loop. The barrel fire
(`ambient-fire`, on `effectsVolume`), the corp machines and the corp beds (on `ambientVolume`) share it.
Volume is a FLOAT on the 0-100 scale (SM2's HTML5 path takes a fraction), and `updateLoop` multiplies in
the kind's gain from **`render/SoundSources.hx` `DB`, the one tuned table**: corp machines **-2.0 dB** (rack, cctv and elevator -6.0),
fire and the corridor bed 0, the cooler -10.0. History: the machines went in at -8 (cooler -16) and were
raised 6 dB after listening, because they sat far under the one-shots. The volume is clamped at
100, so a gain over 0 dB is lost at a full slider: so a loop that should be tunable UP gets its headroom from the bake: `corp/room` is baked at
**-36** LUFS and pulled to -42 (level with the corridor bed's -42.1) by `DB` **-6.0**. Reported as
"the room bed does not change when I scroll": it sat at 0 dB and 100%, so every notch up was
clamped. The corridor bed is a shipped file at 0 dB and can only be tuned DOWN. It is tuned in sound mode (`Shift+S` in street-debug, see
[`debug-surface.md`](debug-surface.md)), which copies the changed lines to paste back into `DB`.

- **Corp: `render/corp/CorpSounds.hx`, driven from `CorpArea.tick`.**

  | key | sources | silent at (path cells) |
  |---|---|---|
  | `corp/rack` | `fit == CorpFurniture.FIT_RACK` | 5 |
  | `corp/elevator` | `elevator` objects | 4 |
  | `corp/vent` | `vent` objects | 3 |
  | `corp/vending` | `CorpDeco.cells(K_VENDING)` | 3 |
  | `corp/cctv` | `CorpSecurity.videoCells` | 3 |
  | `corp/cooler` | `CorpDeco.cells(K_COOLER)` | 2 |

- **WALLS AND CLOSED DOORS BREAK IT: the distance is a PATH, not a straight line.**
  - Every frame a search runs out to 5 cells from the player's cell: 8-way, a diagonal costs 1.41,
    and a diagonal may not cut past a blocked corner.
  - A cell passes sound when `area.canSeeThrough` says so AND it holds no closed `Door`.
  - **A glass door is see-through when shut**, so the door is checked on its own.
  - **Distance is measured to the source's FACE.** A source cell that passes sound is 0 itself; a
    cooler or a vending machine can be STOOD ON (both walkable). A blocked source (a rack) gives 0 to
    the passable cells around it.
    - Measured, with the old rule (full at d ≤ 1): standing on the cooler and standing next to it both
      played 100%, reported as "adjacent sounds the same as one tile away".
- **Level:** `(1 - d/range)^2`, squared because linear amplitude barely moves near the source.
  - Measured on the cooler (range 2, -8 dB at the time, slider 100): on it **39.7**, next to it **10.0**, one
    more tile **0**.
  - The level is eased over 2 x `BASE_MS` (raw dt), so a step, or a door closing, fades the sound
    rather than cutting it.
  - Only the nearest source of each kind counts.
- **Ceilings:** no panning, and a wall is all or nothing (no partial muffling).
- **Corp beds: `ambient-corp` in corridors, `corp/room` in rooms**, both driven by `CorpSounds`
  and crossfaded over 4 x `BASE_MS`.
  - The test is `generatorInfo.getRoomAt(cell) == null`, so doorways count as corridor. The
    reception IS a room rect but plays the corridor bed (its counter replaces the front wall, so it is
    open to the corridor). The lift's 9 cells are in no room rect but count as a ROOM (asked for: no corridor bed
    in the lift).
  - Corp's `AreaInfo.ambient` is `AMBIENT_NONE`. **Never alternate `setAmbient` for this:** SM2's
    `createSound` with an id that already exists returns THE SAME object, so a fade-in and a fade-out
    fight over one sound.
  - Measured: stepping from a corridor into a cubicle, the corridor bed went 0.93 → 0.54 (300 ms) →
    0.04 (1.8 s).

## The old-sound guard

**`make sounds` never touches a sound it did not make.** Its output lives in the area folders, so it
can never land on the 220 shipped files, which sit flat in `app/sound/`. Inside an area folder, a key
is REFUSED when any `<key>.mp3` or `<key><digit>.mp3` already there is missing from that entry's own
`last_outputs`. That covers a mod's sound and an entry renamed onto a taken key. Nothing in `app/sound/` is
ever deleted. One consequence: a take dropped from an entry leaves its old mp3 behind, and the game
still plays it. Delete it by hand.

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

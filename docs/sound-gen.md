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

1. **Generate with `generate_sfx`** (`~/git/fal-sfx-mcp`): `model`, `prompt`, `name` (the game key),
   `area`, `duration`, `loop`, plus optional `seed` and `variants` (1-4).
   - It writes `sounds-src/<area>/<name>-<model><N>.wav`, 16-bit 44.1k, and never overwrites a file.
   - With `register` on (the default) it appends the take to `art/sounds.json` with its prompt,
     model, endpoint, seed, measured duration and cost.
   - For a bake-off pass `register: false` and `area: "<area>/_bakeoff/<name>"`. Keep the losers out
     of the manifest, or `make sounds` ships them as variants.
2. **Adopt the winner.** Move it to `sounds-src/<area>/<name>-<model>1.wav`, add its entry to
   `art/sounds.json` (or re-run it with `register` on), and delete the `_bakeoff` folder.
3. **Bake with `make sounds`** (`tools/sounds.py`). Each variant becomes `app/sound/<name><N>.mp3`:
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

The game picks the new mp3 up with no code change. `ModRegistry.mergedSoundList` scans `app/sound/`
flat, and `Sounds.hx` groups `<key><digit>.mp3` into one key with random variants.

### Manifest (`art/sounds.json`, tracked)

- **Top level:** `style`, `default_lufs` (-26), `default_bitrate` (128k), `seam_ms` (500), `sounds{}`.
- **Per key:** `area`, `loop`, optional `lufs`, and `variants[]`. Each variant holds `file`, `model`,
  `endpoint`, `prompt`, `duration`, `seed`, `cost`, `native_loop` and `generated`.
- **`native_loop`** is true only when ElevenLabs was sent its `loop` flag. A native loop is never
  crossfaded.
- **Bake state:** `last_converted`, `last_sig` and `last_outputs`. A key rebuilds when a wav is newer,
  when `lufs`, bitrate, `loop` or `seam_ms` changes, or when an output is missing.

## The old-sound guard

**`make sounds` never touches a sound it did not make.** A key is REFUSED when any `<key>.mp3` or
`<key><digit>.mp3` already in `app/sound/` is missing from that entry's own `last_outputs`. That covers
the 220 shipped files, a mod's sound, and an entry renamed onto a taken key. Nothing in `app/sound/` is
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
- **One ElevenLabs take came back silent** (`cctv`, **-63 LUFS**). Measure before listening.
- **ffmpeg 4.4's `alimiter` auto-levels by default.** The bake passes `level=0`, or the limiter would
  push the gain back up after the static gain had set it.
- **The seam crossfade survives the mp3 encode, but the browser loop may not.** SoundManager
  re-starts an HTML5 `<audio>` for each loop, which is the same ceiling `ambient-fire` already lives
  with. Listen in game before calling a loop seamless.

## Bake-off log

| date | area | sounds | winners | cost |
|---|---|---|---|---|
| 2026-10-09 | corp | rack, vending, cooler, printer, cctv, elevator, vent (20 s loops, 5 models) | rack, vending: elevenlabs · cooler, elevator, vent: sonilo · cctv: cassette · printer: dropped (too distinct for a loop) | $2.146 |

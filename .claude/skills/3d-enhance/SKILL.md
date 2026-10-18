---
name: 3d-enhance
description: Study one 3D area of the parasite game (city / facility / sewers / habitat / wilderness), find what is thin or missing, and propose ranked enhancement variants — lighting, effects, glb props, emitted geometry, textures, and reuse of what other areas already ship — ordered by visual impact per draw call. Use when asked to enhance, dress, improve, add detail/atmosphere/clutter to a 3D area, or "make <area> look better". Proposal-first: nothing gets built until the user picks a variant.
---

# 3D area enhancement

Four phases: **study → inventory → rank → build the picked one**. Stop after phase 3 and let the
user choose. Never build the whole list.

The art style is FIXED and not up for improvement: moody-night roguelike, flat matte, dark, low
value, even flat lighting, no specular, no photoreal. A good addition is invisible AS an addition —
it looks like it was always there.

**"Dark" is a VALUE rule and it was being read as a saturation rule.** Surfaces are desaturated
because a wall really is grey; OBJECTS keep their own colour, and a manufactured thing that comes
back grey is a bug — 9 of 38 props shipped neutral before this line was written. Value and chroma are
independent: `facility/lot-cone` sits at luma 47 with a channel spread of 45. Pick an accent hue
AGAINST the light, not with it: the compound is lit by a `0x46536b` ambient, a `0x56668c` hemisphere
and a `0x8294c0` moon, so a blue prop disappears into the lamp and a warm one survives it.

`CLAUDE.md` carries the always-on guards; the detail lives in `docs/3d-models.md`,
`docs/3d-textures.md`, `docs/debug-surface.md` and `docs/3d-render.md` (skills `3d-art`,
`live-debug`). Do not restate them. This skill is only the part they do not cover: how to read an
area, what is reusable, and what each kind of addition COSTS.

## Phase 1 — study the area as it is

Dispatch: `src/GameScene.hx:286` → `render/View.hx` (`show` / `showFacility` / `showSewer` / `showWild`).

| kind | area types | render module | style knobs | live hook |
|---|---|---|---|---|
| city | `AREA_CITY_LOW/MEDIUM/HIGH` | `render/CityArea.hx` + `render/world/*` | `world/CityStyle.hx`, `DowntownStyle.hx`, `SlumsStyle.hx` (slots in `world/AreaStyle.hx`) | `__check`, `__occ`, `__dbg` |
| facility | `AREA_FACILITY` | `render/facility/*` | `facility/FacilityStyle.hx` | `__facility()` |
| sewers / habitat | `AREA_SEWERS`, `AREA_HABITAT` | `render/sewer/*` | `sewer/SewerStyle.hx` | `SewerModel.demo()` |
| wilderness | `AREA_GROUND` | `render/wild/*` | `wild/WildStyle.hx` + `WildBand.hx` | `__wild()` |
| militaryBase, undergroundLab, corp | — | **no renderer** — falls through to `showSewer`, so they draw as tunnels | — | — |

Read in this order, no skipping:

1. the kind's `*Area.hx` header + `build()`. It names every layer IN BUILD ORDER and the comments say
   why each exists. That list IS "what is already there" — do not re-derive it by grepping.
2. its `*Style.hx`. Everything tunable without touching render code lives there.
3. `docs/3d-render.md` verdict table — grep the area name and every layer name. Rows record what was
   already tried **and rejected** there. Re-proposing a rejected idea is this skill's main failure
   mode (see: sewer ledge-rim darkening, per-cell wall variants, sewer chunking).
4. live, if the game is running: **`make reload-load`** (plain `make reload` lands on the main menu,
   where no area is built and every hook below reads nothing), then the hook — `__facility()`,
   `__wild()`, `__check` — for what this seed ACTUALLY built (counts, positions, per-structure
   state). `node sshot.mjs --wait` for a frame. Console `go area <x> <y>` teleports, `go xy <x> <y>`
   moves inside the area.

Note for the proposal: which layers are thin (count 0 or single digits), and **what the gameplay
camera actually sees**. Gameplay is a zoom lerp capped at `parasiteZoom` 0.30 / `hostZoom` 0.60, and
tactical is pinned top-down at 1.0 — measured in the tunnels, wall FACES are 0.67% of the view while
ledge TOPS are 14.68%. Dressing a surface nobody looks at is the cheapest way to waste a pass.

**That number prices a SURFACE, and it is NOT a veto on OBJECTS.** % of view is a REACH number, not a
quality one (Phase 4 repeats it) — the sewers shipped wall decals AND a grime band at that same
0.67%. A prop is priced by SILHOUETTE: at a measured 65.6° facility pitch a 2-unit prop still
projects ~0.8 units of screen height, occludes floor and takes a shadow, which is why the park trees
and the lot cones read fine. And **check ORIENTATION before calling a wall unseen** — the rig rests
at yaw 180 plus a walkway side-angle and an RMB orbit, so a run's walls are edge-on one way and
broadside the other: measured 49.4% of a facility's corridor wall faces broadside (120 of 243).
Never carry a pitch or coverage finding from one run, one wall or one surface to a whole family.

## Phase 2 — inventory what already ships

Reuse beats generation; a prop from another area costs one `models.json` label and no art budget.

- props: `python3 -c "import json;print(sorted(json.load(open('art/models.json'))['models']))"`
  (36 today, under `sewer/`, `wild/`, `facility/`, `habitat/`, plus `street-lamp`/`street-lamp2`)
- textures: same one-liner over `art/textures.json` (200 today: `city/`, `downtown/`,
  `slums/`, `sewer/`, `wild/`, `facility/`, `decals/`, `fx/`)
- area-agnostic systems worth borrowing before writing anything:
  - `particles/LampLights.hx` — the shared 12-slot spotlight pool, keyed on distance to the PLAYER
  - `LightCone.hx` (+ `LightConeOpts`) — additive shafts; colour and top radius are per-area knobs
  - `particles/PropLights.hx` / `FlameLights.hx` / `MuzzleLights.hx` — same pooled discipline
  - `world/PropGlow.hx`, `world/PropShader.hx` — surface glow, motes, sway, pulse, arcs folded into
    the material a prop already draws with
  - `decals/Decals.hx` + `DecalBatch` — flat ground/wall decals, merged per image
  - `world/Debris.hx`, `sewer/SewerDebris.hx`, `wild/WildDebris.hx`, `facility/FacilityDebris.hx` —
    seed/grid-deterministic clutter scatter, never persisted
  - `world/VisionMask.hx`, `world/IndoorMask.hx` — canvas masks sampled inside existing materials
  - `particles/Sprites.hx`, `particles/GroundSprite.hx` — pooled frontal quads
  - `world/WorldCtx.wallMounts` (facility) / `world/WallDecals.hx` (city) / `sewer/SewerDetail.hx`
    `decals` — the WALL as a placement surface, which every area kind but the wilderness already uses
  - `facility/FacilityGeom.hx` (`face`/`pane`/`cap`/`add`/`geom`) and `world/Geom.hx` / `MeshBuf.hx` —
    emitted boxes with the game's own tiling textures

## Phase 3 — rank by impact ÷ cost

Cost tiers, every number measured and logged in `docs/3d-render.md`:

| tier | what | cost |
|---|---|---|
| 0 | **style knob + existing texture** | 0 render code. "Weeds in medium courtyards: 4 style knobs + 1 texture, zero render code, 1 draw call" |
| 0 | **folded into a material that already draws** | 0 calls, 0 passes, 0 geometry — PropGlow motes, PropShader sway/pulse, VisionMask LOS, contact-shadow strips riding an existing `InstancedMesh` |
| 1 | **rides an existing batch** | a decal on the shared `DecalBatch` group, a placement appended to an existing `InstancedProp`, a mesh merged into a structure's own fading mesh. Still one call |
| 2 | **one new `InstancedMesh` / merged mesh** | +1 call per material, whatever the instance count. A second material over the same placements (lit/dead, solid/ghost) is +0 idle with a `Models.cull` mask |
| 3 | **new emitted geometry with a new texture** | +1 call per distinct texture — a wall box costs 3 (walls, worn, roof) |
| 4 | **new glb prop** | +1 call, but the bill is TRIANGLES: a TRELLIS prop is ~5k tris over a 40px silhouette, so its tris are sub-pixel and cost barely moves with resolution. Whole park in frame = 3.6M tris, 31.4ms GPU before `toLambert` |
| 5 | **new light source** | never. `NUM_SPOT_LIGHTS`/`NUM_POINT_LIGHTS` are in every lit material's program key — adding one recompiles the world. Claim a pool slot, or make the light additive geometry (a cone, an emissive map) |
| 6 | **new post pass / AO** | GTAO measured +140 calls, +5.4ms, and flips the frame GPU-bound. Default off |

Two more that decide ties: transparent/additive overlays are pure fill and the integrated-GPU bill
(the floor alone is 32% of the frame, never attacked); `castShadow` is baked into the program key
while `receiveShadow` is a uniform and free to flip.

## Phase 4 — the proposal

One table, best impact-per-tier first, then a short "what I would do first" line. Nothing else.

| # | variant | what it adds to the frame | where it lands | tier | cost | fits because |

Rules for the list: 4–8 variants, each buildable on its own, no variant that only makes sense after
another. Say the cost as a bound, not rounded to zero ("+1 call worst case", not "free"). Every
variant names the file it edits. If a variant needs new art, say gen or reuse and which label.

The list must SPAN the families — lighting, FX, glb prop (reused **and** generated), emitted
geometry, texture, decal, wall-mounted — and any family it leaves out gets ONE line saying why. Four
decals and a knob is not a search. "Reuse beats generation" is a tiebreak, not a veto on generating.

An effect must be MOTIVATED by something already in the area's fiction — a light that has a fixture,
grime under a thing that drips. Standing note from a rejected pass: *% of frame changed is a REACH
number, not a quality one — a big reach makes an unmotivated effect worse.*

## Building the picked one

- deterministic placement: hash the cell/seed, not `Math.random()` (roof furniture is the one legacy
  exception and it reshuffles on re-entry).
- object-anchored FX are FRONTAL (fixed yaw, `Sprites.TILT`), never camera-facing billboards.
- never stretch a texture — tile on both axes off world position or face length.
- props draw Lambert (`Models.toLambert`); only `roughness`-dialled habitat props keep MeshStandard,
  so do not plan on a specular highlight.
- new glb path → add a warm entry in `View.hx`'s `Models.get` chain, one per material variant.
- `cd src && make`, then `make reload-load`, then verify with the hook and numbers — not by eye.
- a surface's built value is `built_linear` in `art/textures.json` (stamped by `make tex`); measure
  anything it does not hold — a frame region, an atlas cell — with `python3 tools/pix.py`.
- A/B with `perf street` on a pinned free-cam, interleaved, median, same view.
- append the entry to `docs/3d-changes.md` and one row to `docs/3d-render.md`, including failures.

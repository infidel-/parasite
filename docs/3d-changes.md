# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-08c.md` and its predecessors.

## The park lawn gets overlay patches and a few standing tufts (2026-08-30)

The compound park — the game's ONLY park; `citygen.CityModel.Tile` has no grass concept at all — was
one merged mesh carrying one tiled diffuse map, `facility/grass` at 9.0 repeat, with no mottle, no
vertex colour and no second layer. One map over 360 cells reads as felt. Both fixes already existed:
the overlay-patch idiom (`render.world.Lawns` for slums back yards, `render.wild.WildPatches` for the
wilderness, sharing `render.world.CoverageMask`) and `render.wild.WildGrass`' cross-quad tufts.

**New `render.facility.FacilityLawn`, the third `CoverageMask` caller.** It splits the two parents
down the middle for stated reasons: a compound is FLAT so it takes Lawns' single unsubdivided mesh
rather than WildPatches' relief lattice, and every surface here is mask-patched so it takes
WildPatches' material (`FrontSide`, `PATCH_ALPHA` 0.85, `VisionMask.patch`) rather than Lawns' bare
one. Gating on `Surf.GRASS` excludes the park path, kerb and lot for free — the generator writes that
path as plain walkway. The tufts are **calls into `WildGrass`, not a copy**: its `tuft()` writes
up-pointing normals and its `material()` cancels three's `DOUBLE_SIDED` flip of exactly those, one
mechanism in two places that a second copy would drift out of step with. `tuft()` was at 11 args and
needed a caller-supplied ground height (it sampled `WildHeight` internally, which answers nonsense
outside a wilderness), so it became `TuftOpts`.

**A CHROMA SOURCE MUST BE BIMODAL IN DISTANCE-FROM-KEY, and that histogram is the acceptance test —
not the coverage percentage.** The first `facility/grass-lush` drop asked for grass "a little lighter
than dark olive" and landed subject mean 62/69/65 against a backdrop gpt had vignetted to 77/79/84 —
**19 apart, and the histogram climbed monotonically with no valley**, so every `tol` from 18 to 24 ate
blades and left grey. Re-prompted for grass *much darker* than the backdrop, with halos and gradients
on the grey banned in as many words: **50.4% of the frame at distance 0-2, an empty valley from 6 to
45, subject from 45 up**, and the backdrop came back at 89/91/98 — the requested colour, no vignette.
`background:"transparent"` was tried on the same prompt and **failed this job**: it painted a
continuous field over a dark teal wash (opaque 59.1%) and cut only around blade edges — no islands, no
gaps. The API alpha is a better CUT but does not give island SHAPES. `lift` 0.9 fitted against the
neighbour: source 0.0282 linear would composite to 0.63x the lawn, past the wilderness earth patch's
0.70x and into the sewer-valve hole failure; built it is **0.0390 against the lawn's 0.0499**, which
at α 0.85 composites to **0.0406 = 0.81x**.

**An independent per-cell roll cannot cover a park this size, and that is the transferable result.**
Tuned to ~2% a cell it deals about nine seeds over a 14x30 lawn, and nine independent samples clump:
over 3,600 synthetic parks, **20% come back with a bare band of 5+ columns of 14**, worst 10 — and the
live park drew exactly that, all seven seeds inside three columns with the west half left flat. This
is `FacilityAreaGenerator`'s own `PARK_CLUMP_STEP` finding one layer down, rediscovered. Replaced by a
**stratified roll — one hash-placed seed per `PATCH_STEP` 7 block** — which takes that failure to
**7%** and its worst to 8, and on the live park spreads seeds over **7 columns instead of 3**. Still
pure deterministic hash, no rng, nothing persisted, so a park saved earlier gets its patches on
re-entry. Landing: 8 seeds, 21 cells, **24.3%** of the lawn (`__facility().patches.strong`).

**`strong` is measured over the LAWN'S OWN BOUNDS, not the mask canvas.** The canvas spans the whole
400-unit area rect, where a park's blobs are a fraction of a percent however overgrown they are — the
first cut of the hook reported 0.22% and said nothing.

**The tufts had to leave the patches, and the count the wilderness tuned is far too low here.** They
started confined to the marked cells, which left the bare lawn — the thing this layer exists to fix —
as flat felt. Opened to every plain lawn cell, denser inside a patch (`TUFT_LAWN` 3, `TUFT_PATCH` 5).
The counts are the surprise: **a compound park is planted far denser than the open ground the
wilderness tuned its 1-3 per cell against.** The live park measures **72.5% under trees and bushes**
(163 bush cells, 93 tree, 5 bench) leaving only **99 plain cells of 360**, so one tuft a cell put 108
blades over a 14x30 lawn and read as nothing at all. 3/5 puts **315** in, and that is where the ground
stops being felt.

**The park's trees read blurry against the grass and the walkway, and texels/tri could not see why.**
Reported as "they look blurry compared to grass/ground/walkway — why, much more polys?" It is not
polys; sharpness is **texels per world unit**, the UV area in texels over the world triangle area,
area-weighted at the `h` the game draws the prop at. Measured across the park:

| surface | texels / world unit |
|---|---|
| grass tuft sprite (256x192 over 1.5 x 0.9) | 171 / 213 |
| overlay patch (512 @ `PATCH_TILE` 3.0) | 171 |
| `bush-low` @ h 1.1 | 108 |
| ground / walkway / lawn (512 @ `GROUND_TILE` 9.0) | **57** |
| `tree-conifer` @ h 7.5 | 44 |
| `tree-broadleaf-full` @ h 9.5 | **25** |

The ground never suffers this because it TILES — 57/unit however large the surface. A prop's atlas is
finite and spread over the whole model, so density falls as the prop grows: the broadleaf wraps one
512² over **292 u² of canopy** and lands at less than half the ground it stands on.

**And the existing `tex` rule argued FOR that, which is the transferable part.** Texels-per-triangle
was fitted to the decimate-a-100k-master route, where atlas and tri count shrink together. These props
are `tris: -1` — generated AT the budget — so Runware baked a **2048² atlas for a 4.9k-tri mesh**,
~862 texels/tri at source. `tex: 512` threw away ~16x the texels while still reporting a healthy
53/tri. Both trees to `tex: 1024`: broadleaf **25 → 49.3**, conifer **44 → 86.9**, off source atlases
that genuinely hold the detail. `bush-low` stays 512 — at 108 it was already sharper than the ground.

**Anisotropy was the first suspect, was fixed, and was NOT the cause.** `Textures.loadTexture` sets
`anisotropy = 4` on everything loaded by hand while `GLTFLoader` leaves its textures at **1**, so
props were the one thing in the frame unfiltered — `RenderConfig.MODEL_ANISO` in `Models.get` closes
that, and it is free. But in a frozen A/B (`ANIM_SPEED = 0` so the tufts could not move between
captures, HUD masked, identical pinned pose) forcing 1 → 4 moved **0.25% of pixels by more than 2,
mean delta 0.086**, where `tex` 512 → 1024 on that same pose moved **2.98%, mean delta 0.47** —
**twelve times the effect**. A first attempt at the anisotropy diff reported 9.33% and max delta 251
and was pure artefact: the wind was running and the grass swayed between the two shots.

**Every tuft was capped by a 1px line, and it was the texture WRAP — reported as "a thin 1 pixel line
on top".** `render.Textures.loadTexture` hands every caller `RepeatWrapping`, because nearly
everything it loads tiles. A tuft quad maps uv 0..1 across the sprite exactly ONCE, so v=1 sits on the
texture's outer edge and bilinear there wraps around and blends in row 0. `wild/grass` is authored
side-on **rooted in the frame's bottom edge**, which makes its two outer rows the worst possible pair:
measured, the top row (blade tips, v=1) is **0% opaque, maxA 0**, and the bottom row (the roots) is
**66.4% opaque at alpha up to 255, mean 152**. So the wrap laid a half-strength line of ROOT along the
top edge of every quad, blending to ~128 — over this material's `alphaTest` of 102, so it survived the
cut. `map.wrapS = map.wrapT = ClampToEdgeWrapping` in `WildGrass.material`, on the returned texture
rather than in the shared loader, since the loader's other callers do tile. **This was never park-only
— the material is shared, so the wilderness had it too on every tuft in the area.**

**163 bushes were one bush repeated, and `PropPlace.scale` was sitting there unused.** Decomposing
every instance matrix in the live park: conifer 49 instances at exactly 7.5057, broadleaf 44 at
9.8876, bush-low 163 at 2.1238 — `distinctScales: 1` on every plant batch. `FacilityGround.green`
rolled three hashes a cell (x jitter, z jitter, yaw) and never touched size, while `Models.PropPlace`
carries an optional `scale` whose own comment states the failure ("a batch is ONE glb drawn many
times, so without this a stand of trees is one tree repeated") and `WildProps` sets it on every row.
New `GreenProp.scaleJit`, off the HIGH bits of the yaw hash (which spends only its low ones on
`% 6283`) — the same one-hash-two-ranges split `WildProps` uses. Now 29/24/77 distinct scales in the
visible set, spanning **0.904-1.100** of base.

`FacilityStyle.PLANT_SCALE_JIT` is **0.10**, deliberately under half the wilderness's spread for these
same three glbs (conifer 0.20, broadleaf 0.22, bush 0.28): that is wild growth, this is planted stock
in a maintained compound. Two things had to follow it and one deliberately did not:
- **`sink` rides the instance scale** — `y: surfY(GRASS) - sink * h * s`. The ragged trunkless fringe
  being buried shrinks when the tree does, so a fixed burial leaves a small broadleaf standing on its
  own torn edge. `WildProps.sit` records the same coupling for the same glb.
- **the bush overhang survives it, measured rather than assumed.** A +10% bush is radius 1.155 against
  the 1.05 `lean()` was fitted to, and lean's recorded minimum rim-to-boundary clearance was +0.945.
  Live over 79 bushes: **+0.845**, exactly 0.945 − 0.105. Still clear, so `lean` needed no change.
- **the BENCH takes `scaleJit` 0** and is the only row that does. It is manufactured — the wilderness's
  guard rail is alone at 0 in its own table for that reason — and `bins()` places the litter bin off
  this bench's fixed half-extents (`BIN_SIDE` / `BIN_BACK`, both fitted against a 3.57-unit seat), so
  a scaled bench would walk its bin off the corner.

**The park's wind runs at HALF the wilderness's rate, and that is free.** A compound park is a
sheltered box of buildings and perimeter wall; at the shared 0.28 a walled lawn leaned like open moor.
`WildGrass.material` took a `rate` argument (default `WildStyle.WIND_RATE`) because the rate is a
**uniform and not a program define** — so both callers still compile ONE program and share one cache
key, and only the clock is shared by identity, which is what lets a single `tick()` drive every blade
in either area. Amplitude untouched: the blades travel as far, they just take twice as long. Verified
live off `renderer.properties`: park `wildWindRate` **0.14** against `WildStyle.WIND_RATE` 0.28, amp
0.11 both, key `wildGrassvisMasksindoor` unchanged, programs unchanged — phase **0.941 rad/s** against
the wilderness's 1.882, a lean cycle of 6.7s against 3.3s.

**Cost, pinned pose, 15 interleaved samples per side:** **+2 draw calls, +1,466 tris** (tufts 1,260,
overlay 206). GPU is **below this machine's noise floor and the A/B inverts**: at the low count 7.00ms
on vs 6.91ms off over ranges 4.41-22.03 against 4.47-22.10, and at the shipped count 4.64 on vs
**5.77 off** — adding geometry "faster" twice over. 60 FPS throughout. Take the calls and the tris;
there is no GPU number to take. Warm: `FacilityModel.demo()` had **no GRASS cells at all**, so
neither material would have been built in the warm scene — a park strip added, and the facility warm
goes **+11 → +13**, the two new permutations (`visMaskbindoor` and `wildGrassvisMasksindoor`), with
entry still at the standing +4 depth-only residue. Mask alignment verified live: **235-246** at every
marked cell centre, **0** at all 64 lawn cells beyond kernel reach.

**Verdict: landed.**

## The warmup phase gets a screen, and the warm splits by area kind (2026-08-30)

The boot pre-warm ran **300ms after the menu had already painted** (`Main.hx:50`), and its head is one
uninterrupted synchronous block — three `CityGen.generate` + three `World.build`, a sewer scene, a
facility scene, the FX parking, the DoubleSide clone pass. So the menu appeared, started its own
30fps `MainMenuGL` loop, and then froze solid. Then ~20 glbs landed one at a time, each running three
scene traversals and a matrix bake in `Models.get` on whatever frame it arrived. That is what "the
game starts from hitches" meant.

**What landed.** A `#warmup` div in `app.html` — black, centred, `warmup phase` plus three dots — up
from the document's **first paint**, before `parasite.js` has parsed, and removed by `Main` only when
the warm settles; `game.ui.state = UISTATE_MAINMENU` moved into that same reveal. `View.warmup` grew
`?onDone`, a `catchError` (it had none), and two numbers on its existing log line.

**Measured, and this is the entry's point.** The whole warm behind the screen was **sync 636ms /
total 7593ms** — repeatable, 104 programs. 6.9s of that is 20 glb file reads plus the ~20 blob
texture decodes GLTFLoader makes from their embedded atlases. A 7.6s boot screen for art most
sessions never reach, so the warm was **split by area kind**: boot warms the city only (`warmup`),
and the tunnels and the facility each warm on the **first entry to that kind** (`warmKind`, called
from `GameScene.draw3D` inside the `fader.cover` callback, so it runs under black that is already up).
Boot went **7593ms → 4625ms**, 104 → **72** programs; the facility warm is **+11 in 1695ms**, the
tunnels **+20 in 345ms**, and a repeat call on any kind is **0ms**. 72+11+20 = 103 against the old
104 — one program short, not chased.

**Traps.**
- **`catchError` on a `Dynamic` is emitted verbatim.** `Three.hx:187` types `compileAsync` as
  `Dynamic`, so `.then` works (dynamic call) and `.catchError` compiles to a literal `.catchError`,
  which no promise has — a runtime `TypeError` on the very path meant to keep the boot screen from
  sticking. Fixed by holding the chain in a typed `js.lib.Promise<Dynamic>` local, which is the only
  reason that local exists.
- **A screen that paints before the game exists has NO settled font, and there are two reasons, not
  one.** Every face in `fonts.css` is `font-display: swap`, so a first paint shows fallback glyphs and
  the real face replaces them — and `--text-font-title` is itself overwritten from the saved config in
  `Config.hx:170`, inside `new Game()`, after that paint. So the words changed twice, and the middle
  state was the `:root` default `Orkney-Regular`, which is not what the game runs in (this box:
  `Cruiser2015`). Pinning one face only freezes the middle state. Fix: the text is `color:
  transparent` in `app.css` and `Main.init` adds `.ready` off `document.fonts.ready` — attached AFTER
  `new Game()` on purpose, so the load it waits on is the CONFIGURED face and not the default. Safe
  because `Config.fontsTitle` is a fixed list, every entry declared in `fonts.css` in the head, so
  none of them can arrive later from a mod stylesheet.
- **The dots must animate OPACITY.** The sync head blocks the main thread for ~0.8s; only
  compositor-driven properties keep running through that. Idiom copied from the existing animated
  ellipsis at `app.css:878-894`. Three keyframes on one clock rather than `animation-delay`, because
  a delay shifts the whole cycle including the clear and gives a rolling shimmer, not `.` → `..` →
  `...`.
- **No inline `<script>`/`<style>`** — the CSP in `app.html` pins the one existing inline script by
  sha256. Markup plus a rule in `app.css`; `style-src` allows inline, `app.css` is `'self'`.
- Each per-kind warm now builds its own throwaway composer, so it also **renders** its scene — which
  closes the standing gap that only the city warm scene was ever rendered and `compileAsync` never
  reaches the shadow-map depth materials. The facility warm needed `fitMoon` over the compound for
  that pass to have a caster.

**Given up on purpose:** the wilderness still has no warm scene, and it loses the incidental preload
of the three tree/bush glbs it shared with the facility park. `warmKind` returns immediately for it,
exactly as before this change.

**Not verified in game.** Everything above is measured headless — the boot screen and its log from a
reload, the per-kind warms driven directly on the live `View` through
`parasiteHx['game.Game'].inst.scene.view3d.warmKind(...)`. The `draw3D` call site was not exercised
by an actual area entry, because that needs clicking through the autosave prompt and this box's save
is the user's.

**Verdict: landed.**

## The warm scenes move out of View, and the DoubleSide split turns out to be broken (2026-08-30)

`View.hx` was **1518 lines and 442 of them (29%) were `warm*`**. The layering told the same story
without being asked: of the 23 reaches into `render.facility.*` / `render.sewer.*` from `View`,
**20 sat inside that block** — `FacilityGeom`, `FacilityGlow`, `FacilityStyle.LAMP_HEAD_Y`,
`SewerStyle.PROP_MODELS` and the rest. The 3 outside are the legitimate seam (`new SewerArea`,
`new FacilityArea`, one `isOfType`). A warm scene is a COPY of a real build, and the copy was living
in another package from the original, where drift is invisible.

**What landed.** `render.Warmup` (shared: the retained `hold`, `compile`, the DoubleSide split),
`render.CityWarm`, `render.sewer.SewerWarm`, `render.facility.FacilityWarm` — each next to the
builders it copies. The whole coupling to `View` turned out to be **three values**: `renderer`,
`camera`, `lampPool`. `View` keeps `warmup` and `warmKind` — the guards, the timing, the logs, the
catches — and goes **1518 → 1184**.

**The trap, and it was a live bug.** The DoubleSide clone pass (three draws a transparent DoubleSide
material as two single-side passes, each its own program) ran on the CITY scene only. Moving it into
`Warmup.compile` so every kind gets it exposed two defects in the pass itself:
- **`Material.clone()` copies neither `onBeforeCompile` nor `customProgramCacheKey`** — three's own
  `copy()` lists neither, the obituary `render.world.VisionMask.patch` already carries. So a clone of
  a patched material warmed the UNPATCHED key.
- **`USE_INSTANCING` is read off the OBJECT, not the material**, so a clone hung on a plain `Mesh`
  warms a different program from the one an `InstancedMesh` source draws.

Measured by diffing `__progs()` key sets across an A/B build: boot **72 → 64 programs, and all 8 are
programs the game never uses** — every one of them carried three's DEFAULT `customProgramCacheKey`
(`'onBeforeCompile() {}'`), i.e. an unpatched clone of a patched material. Nothing was lost: the
`indoor` (4) and `propCore` (2) keys are identical in both sets, because the patched front/back
programs were already cached by the explicit front/back meshes `GasCloud3D`/`Sprites.warmupMeshes()`
build for themselves.

**Extending the split to the other two kinds bought 0 programs.** The facility warm scene holds 2
materials matching the predicate (`FacilityGlow`'s vertex-coloured additive, a `LightCone`) and the
tunnels 1, and their front/back programs were already cached — the trailing `comp.render()` was
covering them incidentally. Kept anyway: coverage is now by construction rather than by whatever the
camera happened to frame.

**No warm regression.** Per-kind deltas match exactly: facility **+11**, tunnels **+20**, total 95,
city and wilderness **0 in 0ms**, repeat calls **0ms**, 3 held scenes, `Warmup.hold` replacing
`View.warmHold` as the debug path. Ms are IO-bound and not comparable — the same sewer warm read
3696ms and 458ms on two runs of the same build, ordered differently.

**Verdict: landed.**

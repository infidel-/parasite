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

## Props draw MeshLambert, and the shrub stops casting a shadow (2026-08-31)

The facility frame is **97.8% prop triangles**: 1,307,322 tris in a culled follow view, of which the
built world — ground, walls, roofs, floors, kerbs, paint, doors, tables, lawn — is **28,424**. The
rest is seven instanced glb batches, each drawn TWICE (main + moon shadow, same instance buffer).
With the whole park in frustum it is **3,624,932** (163 shrubs at 4955 tris, 84 railing segments at
5056, 49 conifers, 44 broadleafs).

**Attribution, integrated Radeon, `view3d.perf.lastGpuMs`, medians of interleaved runs.** Props
swapped material-by-material with the geometry untouched, at 1040x647: base (MeshStandard) **9.02ms**
-> Lambert **6.26** -> Basic **4.77** -> Basic untextured **4.49** -> props hidden **3.49**. So of the
5.53ms the props cost, raw geometry for 1.28M tris is **1.00ms**, texture fetch 0.28, Lambert lighting
1.49, and **the Standard-over-Lambert premium 2.76 — 31% of the whole frame**. Shadow pass off
(-639k tris) is only **-0.54ms**, i.e. **0.08ms per 100k depth-only tris**.

**The reason tris matter here is NOT vertex throughput, it is 2x2 quads.** Projected median silhouette
at 1040x647: shrub **42px** for 4955 tris = **0.56 px per front-facing triangle**, bin 0.46, railing
1.39 (conifer 4.4, broadleaf 5.8). A sub-pixel triangle still costs a full quad, so the fragment
shader runs per-triangle, not per-pixel. Measured signature: over 0.24 / 0.67 / 2.30 MP the props cost
4.36 / 5.34 / 9.71ms (fit: **3.74ms fixed + 2.6/MP**) while the rest of the scene runs 1.51 / 3.63 /
10.55 (0.46 + **4.39/MP**, i.e. pure fill). Prop cost is triangle-linear; world cost is pixel-linear.

**Shipped.** `Models.toLambert` swaps every glb material at load — `map`, `normalMap`, `aoMap`,
`emissive*` carried, `roughness`/`metalness`/MR map dropped. The switch that keeps a prop on
MeshStandard is the glb's own `roughnessFactor < 1`, which is what `models.json`'s `roughness` dial
bakes: only the 4 habitat props (0.30-0.45). Verified live after the build — 26 props Lambert, 4
Standard. And `FacilityGround.GREEN` gains `casts`, false for the shrub alone: 163 domes 42px across
were 45% of the park's triangles for a moon shadow of a few lawn pixels.

**Confirmed on the SHIPPED build at a real 1920x1017**, against the original materials reloaded from
the same glbs by a second in-page `GLTFLoader` with the live `onBeforeCompile` carried across, so both
sides ran the identical `VisionMask` shader. Gameplay view: **18.48ms / 42.9fps -> 12.25ms / 60fps
(vsync)**, tris 1,307,386 -> 1,015,041. Split: the material is **-5.94ms (-32%)**, the shrub shadow a
further **-0.29ms** for -292k tris — which is the point of the entry, since that shadow was 22% of the
frame's triangles and 2.4% of its time. Whole park in frustum (cull frozen): **29.17ms / 29.9fps ->
17.45ms / 46.7fps (-40%)**, 3,624,996 -> 2,817,331 tris. The 29.17 reproduces the 30fps this started
from.

**The trap:** `renderer.info` has `autoReset = false` here (`View.hx:1165` resets by hand), so `tris=`
is the sum over ALL passes. Half of a facility tri count is the shadow pass, and dividing a saving by
the headline number understates it by 2x.

**Budget it leaves.** At 1080p on the iGPU, 60fps = 16.6ms, of which the non-prop world is a **10.2ms
floor** (fill, tri-independent). Props get 6.4ms: at Standard's 0.59ms/100k that was ~1.1M tris, at
Lambert's 0.28 it is **~2.3M**. The 3.6M worst case is still over — the next lever is triangles, and
it is `bush-low` (45% of park tris, split ratio 1.79x, the only plant `error` might decimate).

**Verdict: landed.** Largest single win measured in the facility.

## The parking entry gets a checkpoint (2026-08-31)

Two new props at the compound gate — a boom barrier across the drive and a glazed guard booth on the
bay beside it — plus the one lamp mast the lit-line rules can never place, and a guard post in the
tile grid. `render.facility.FacilityEntry` owns the arithmetic; `FacilityPaint`, `FacilityLamps` and
`game.AreaGame.initSpawnPoints` read it. **Nothing is persisted and no tile changes**: the entry is
already the only lot cell within the sidewalk band's width of the road (`FacilityPaint.isEntry`), so
its bounding box IS the hole, and every compound already saved gets its checkpoint on re-entry.

**The barrier's PROPORTION was a prompt problem, not a settings one.** Asked for "an arm about five
times as long as the pedestal is tall" in an ordinary three-quarter prompt, gpt returned widest/height
**1.93** — a full-height cabinet with a stub. `Models.instanced` scales uniformly, so at that aspect
the cabinet has to stand **2.6 m** for the arm to cross one 4 m lane, which from this camera reads as
a second booth. Restated as the FIRST paragraph, in caps, with the parts placed in the frame by hand
("the pedestal occupies only the far LEFT eighth"), it came back at **6.81**, and the game sizes off
that: `BARRIER_H` is the PEDESTAL's height.

**Then the same prop cost a THIRD generation, and that one is the real finding: "three-quarter" is
about the ATLAS, not the silhouette.** The fixed-proportion drop was a near-flat SIDE ELEVATION. Its
mesh was fine — **2 components at 86.2/13.8**, 1.22x split, correct proportions — and its **texture
was junk**: the arm's top and back faces are not in a side view, so TRELLIS invented them, and the
baked hazard stripes came back bleached and disagreeing chart to chart. Re-shot ISOMETRIC at ~35°
from one corner, with the top face AND a side face of every part in frame and the stripes stated to
wrap continuously over the edge, the same object baked a coherent atlas: **3 components at
71.0 / 28.9 / 0.1**, 1.26x, widest/height **7.36**, so `BARRIER_H` 2.0 is a 1 m cabinet under a
**14.7-unit** span across the 16-unit entry. That drop touched the frame edge (margin l 13 r 2 t 0),
which is the other new tool: **`propstat --fit 80`** shrinks the subject about the centre and re-lays
it on the flat backdrop — scale 0.947, margins → 89/79/187 — holding the composition where a re-roll
gives a different one. Its key has to measure the backdrop gpt ACTUALLY painted: keyed against
nominal `#5a5d63` the vignette sits ~24% opaque, invisible when `lift` re-lays the whole frame and a
**hard rectangle border** when `fit` pastes a sub-rect.

**Its `baseColor` is deliberately OFF the 46-52 family, at 82/72/65.** The isometric bake came back
warm and LOW-CONTRAST — orange chevrons on tan where the reference painted brick red on off-white —
and the family factor (fitted at `[0.09,0.12,0.2]` = 46/45/48) left the arm a black bar with the
chevrons gone. `baseColor` is a per-channel multiply and cannot add contrast back; the only lever is
level, and a hazard-striped boom is high-vis paint that should be the brightest thing at an unlit
gate after the booth's own windows. Fitted live on the material's `color` at the game camera.

**A flat emissive mask is right for a LENS and wrong for a WINDOW RUN.** (This paragraph and the next
are SUPERSEDED by *The guard booth stops being a prop* below — the booth has no glb, no atlas and no
generated emissive map any more. `--modulate` itself stands; nothing here uses it today.) The booth's
glazing lit by
`emissive.py`'s flat tinted mask came back as a **white card stuck on a black box** — the same failure
`facility/lamp-post` logs for its whole-head box, one scale up. Dropping `emissiveStrength` 2.2 → 1.1
live only dimmed the card: the halo went and the card stayed, because **the failure is uniformity, not
level**. New `--modulate` multiplies the mask by the glb's own base map, whose panes already sit ~3x
over its mullions, so the glow lands on the glass and the frames stay dark for free. Lit texels
**255 → mean 117**, so the strength goes the other way — **3.5** against a window pane's
`WINDOW_EMISSIVE` 2.2 — and only the panes then clear `BLOOM_THRESHOLD`.

**Booth `error` 0.05, not the usual 0.005.** At 0.005 meshopt floors a BOX at **11,364 tris** (23
texels/tri at `tex` 512, under the 43-55 band); 0.05 lands **7,431** (35). The number that predicts
blur is texels per WORLD unit, and at `BOOTH_H` 4.4 that is **55** against the ground's own
512/`GROUND_TILE` 9.0 = **57**, so 512 is matched to the surface it covers.

**Verified live** on a generated 65x50 south-layout compound: entry cols 58-61 / rows 44-45, booth
(57,43), gate mast (62,43) — masts **24 → 25** — barrier centred on the hole. **0 paint quads overlap
the booth cell** (the bay run that opened it is gone, its neighbours at col 56 and col 61 untouched),
and `spawnGuards` puts a security guard on **(58,43)** off the new `importantGuardSpawnPoints` entry.
`calls` 57-59 in the free-cam gate view, GPU 8.3-9.2ms; two batches of one instance each, so there is
no perf question to answer here.

**Verdict: landed.**

## The guard booth stops being a prop (2026-08-31)

Reported from the game: *"converted booth has surprisingly awful texture. why do we even need to
generate a 100k booth which is < 10 real polygons?"* Both halves are right, and the second one is the
finding.

**`propstat` on the shipped drop is a straight REJECT, and the entry above talked itself past it.**
40 connected components, largest **58.1%**; 3.14x split, so undecimatable at any `error`; albedo
**91/97/104** against the prop family's 46-52. The `models.json` note argued the component count was
a false positive because "the preview shows a box, not a blob cloud" — the preview showed a box
because a box is what it is, and the gate was reporting, correctly, that the SURFACE had been
shattered into forty pieces. A rectangular object with four flat faces has no business going through
a mesh generator at all.

**The replacement is 34 triangles in three draw calls**, built in `FacilityEntry` off
`FacilityGeom.face` / `pane` / `cap` — the same public emitters `FacilityTables` has used for a bench
since it was written, for the same reason, written down in its own header: *"a bench is a BOX … six
quads a cell against a glb's unwrap lottery."* 16 wall tris (four faces, each split around the
glazing band), 10 roof (a cap on the grown rect plus its fascia), 8 glass. Three visibility changes
in `FacilityGeom` (`pane`, `add`, `geom` → public) and no duplicated code.

What that buys beyond the tri count is the part the atlas could never do: the booth wears the
compound's OWN `wall-exterior` and `roof`, tiled world-aligned at `WALL_TILE`/`ROOF_TILE`, so its
texel density is the buildings' and its courses line up with them — instead of a 2048 atlas spread
over a 4-unit box and then resized to 512. And its glowing band is the same `window-ribbon-lit` art
every window run in the area already draws, so **`emissive.py --modulate`, `booth-emissive.png`, the
hand-editable `booth.png` `texSrc` and the whole `models.json` entry stop existing** — as does the
`FacilityWarm` row that was there only because an `emissiveMap` is a program define.

**The glazing is OPAQUE, and that forced its own emissive level.** A run's panes are half-transparent
by design (`tools/textures.py`'s `glass_alpha` keys the bright half to 128) because a window is read
from both sides of one wall; on a BOX that means looking in the near face and out the far one, at an
interior nobody is going to model. Opaque, `transparent` is off and there is no sorted pass, while
`alphaTest` still kills the art's cut margin. But at the run's `WINDOW_EMISSIVE` **2.2** the booth was
a white lantern with its mullions blown out — four faces at the camera at once, none of them sunk in
a reveal, none of them dimmed by an alpha of 128. New `FacilityStyle.BOOTH_EMISSIVE` **1.4**, fitted
live against the lab windows across the lot: a bloom halo, and the frames still legible under it.

**It also wanted its own ROOFING, and "lighter" was the wrong axis to fix it on.** Wearing the
buildings' `facility/roof` — bitumen membrane under gravel ballast — a 4.3-unit kiosk cap read as one
more piece of the aggregate the lot is paved in. The fix is a different MATERIAL, not a lighter
bitumen: new `facility/booth-roof`, painted steel decking with standing seams, on the same
`ROOF_TILE` 9.0 as the roof it replaced (the art carries 13 seams, so a **0.69-unit pan** — 0.35 m at
the half-metre unit, a real standing-seam pitch — about six of them across the slab, at 512/9.0 = 57
texels per world unit, the ground's own density). The fascia band moved from `WALL_TILE` to
`ROOF_TILE` with it, so the trim is a slice of the same pan as the cap above it. As generated the art
is **0.1886 linear**, 6.9x the bitumen roof and a white card at night, so it is lifted DOWN: 1.8 / 1.6
/ 1.4 A/B'd live on the material's own `color` in one pinned frame — 1.8 is smooth dark grey and
answers "less concrete" but not "lighter", 1.4 makes the cap the brightest thing in the lot after the
lit windows — and **lift 1.5** bakes to **0.0849**, 3.1x that roof and 2.6x the wall.

**Its shadow had HOLES in it, and the cause was already written down one file over.** The glazing
band is cut OUT of the walls (a face floor-to-sill, another head-to-eave), so with the glass mesh not
casting, the opening is a real hole in the caster and the moon shines straight through the box — a
bright band across the middle of the ground shadow, which is exactly the parallelogram of moonlight
`FacilityGeom.addPane` records for a non-casting window run inside a building. Same one-line fix, and
opaque here rather than alpha-keyed so it casts solid with nothing to tune. The ROOF now casts too:
`addRoof` refuses that for a building's, but that rule is about a roof over a whole lot under a moon
box that follows the player, and this is a 4.3-unit cap — not casting it, the shadow stopped at the
WALL line and the overhang, the one feature of the silhouette, threw none.

**That left a SECOND set of holes, and the lesson is that the shadow pass does not look from the
camera.** The roof slab was a cap plus four fascia bands and nothing underneath — deliberately, on
the same reasoning `FacilityTables` gives for leaving its bench lip open: the camera pitches 51° down
and a ray reaching under a `BOOTH_EAVE` overhang has already met the wall. True of the CAMERA and
irrelevant to the LIGHT. A `FrontSide` material renders BACK faces into the shadow map, so from above
the top cap's front face is culled and an open-bottomed box casts only from the inside of its own
fascia. Adding the soffit (`FacilityGeom.capDown`, now public) closes the slab: roof **10 → 12 tris**,
and the soffit is the face actually carrying the slab's shadow. The wall and glass rings never had
this problem — a closed vertical tube's back faces ARE its silhouette from any direction.

**And it BLOCKS.** The booth is still render-only — nothing is stamped on the tiles for it, which is
what keeps the checkpoint retroactive — so the block is derived the same way everything else at this
gate is: `AreaGame.gatePost` became `gate()`, returning the booth's bay alongside the guard post, and
`initSpawnPoints` (which already runs on generation AND on load) caches it in a transient `_boothX/Y`
that `recalcTile` reads. It gained the renderer's own both-flanks-are-bays guard, and that is
load-bearing rather than tidy here: `FacilityEntry.find` draws no booth at all if either flank fails,
so blocking on a weaker test walks the player into an obstacle that is not on screen. It still SEES
through — the box is glazed on four sides and `VisionMask` blocks on walls alone. Live: (57,43)
unwalkable, 56 and 58 untouched, `getPath(55,43 → 59,43)` detours through row 42, the guard post at
(58,43) unchanged.

**The barrier stays a prop, and the split is the rule.** An arm, a counterweight and a cabinet is a
shape worth generating — 1.26x split, 3 components at 71.0/28.9/0.1. A box is not. So the question to
ask before spending $0.03 is not "will TRELLIS manage this?" but *"is this thing's silhouette worth
generating, or is it axis-aligned slabs I could emit exactly?"*
> SUPERSEDED by "The boom barrier stops being a prop too, and the line moves" — the barrier did not
> stay a prop, and this paragraph drew the line in the wrong place.

**Verified live** on the same compound: `__facility().batches` drops from 7 rows to 6 (booth gone,
barrier still 1). The three booth meshes read 16/10/8 tris, footprint 3.4 x 3.4 centred on (30, −26),
walls −0.2 → 4.2 on the kerb-dropped asphalt, roof 4.2 → 4.5 at 4.3 wide, glass 1.5 → 3.6 — every
number the constants predict. Walls cast, roof does not, `make models` reports 31 up to date.

**Verdict: landed.**

## The boom barrier stops being a prop too, and the line moves (2026-08-31)

Reported from the game as two complaints in one breath: *"texture issues for the red-white part are
still there"* and *"3k tris for a box and a bar seems like a lot"*. They are the same complaint, and
the entry directly above is why they were still open — it wrote down "a box is not a prop, **but the
barrier stays one**: an arm, a counterweight and a cabinet is a shape worth generating". That
exemption survived exactly one entry.

**The barrier scored the same way the booth had.** `propstat` on the shipped `barrier.glb`: **3,098
tris**, 2.07x split (undecimatable), **3 connected components with the largest holding 65.9%** — a
REJECT by the gate's own rule — and an albedo of **145/125/105** against the prop family's 46-52. The
`models.json` note carried a `baseColor` of 82/72/65 fitted by hand, 30 points off the family, with a
paragraph explaining that the bake had come back "warm and LOW-CONTRAST — orange chevrons on tan
where the reference painted brick red on off-white" and that `baseColor` is a per-channel MULTIPLY
and so cannot add contrast back. That note was a workaround written down as a justification.

**The test was wrong, not the exemption.** "Is it a box" is a rule about SHAPE, and an arm plus a
cabinet genuinely is more shape than a kiosk. But a boom barrier is not carried by its outline at
all — **it is carried by its hazard bands**, and that is a SURFACE. So the question that actually
predicts the outcome is *is this object carried by its silhouette or by its surface?* A silhouette is
what a mesh generator is for. A stripe pattern is what a tiling texture is for: it cannot lose
contrast, cannot smear, holds its density at any length, and costs $0.01 to repaint.

**Built, it is 22 triangles.** `FacilityEntry.barrier` emits a cabinet (four `face` calls and a `cap`,
**10 tris**, no floor) and the boom (four faces, a `cap` and a `capDown`, **12 tris**), against
**3,098**. The whole checkpoint is now **58 tris** in 5 meshes. The arm's LENGTH is derived from the
gate hole rather than named, which is the one thing the prop could never do: `Models.instanced` scales
a glb uniformly, so its height fixed its reach and the barrier spanned 14.7 units whatever the
generator had cut. Here the two ends are the hole's own outer cell boundaries.

**The art is prompted UNIFORM TOP TO BOTTOM, and that is load-bearing rather than stylistic.**
`FacilityGeom.face`/`cap` take ONE period for both axes, so on a 0.3-unit-thick bar `v` is a thin
horizontal slice of the image at an arbitrary offset — and a different one on the sides (`y/t`) from
the lid (`z/t`). Vertical bands with no vertical structure make every slice identical, so the bands
line up across the lid and both sides for free and no second period is needed (contrast
`FacilityTables.panel`, which needed one). Measured on the drop: **max row deviation 0.010 on a mean
of 0.311, i.e. 3.3%**. The wrap is a band boundary too — left edge mid-red, right edge white.
`BARRIER_ARM_TILE` 6.0 over the art's six bands gives a **1.0-unit band** (0.5 m at the half-metre
unit, a real boom's pitch), ~13 along the arm, at **85 texels per world unit** against the ground's 57.

**`lift` could not do the level fit, and that is worth knowing generally.** The art lands at **0.311
mean linear** — high-vis paint, 9.5x the asphalt. `lift` is a GAMMA, and on two-tone art a gamma moves
the two tones the wrong way round: it darkens the ALREADY-DARK red far harder than the white, so lift
1.6 takes the red to **0.0276** (under the asphalt it stands over) and blows the red/white ratio from
**6.8x to 13.8x** — white dashes floating, red gone. A scalar on the material's own `color` is LINEAR,
holds both the ratio and the hue, and moves only the level, which is the one thing that is wrong. So
the arm gets its own tiny `addArm` rather than a plain `FacilityGeom.add`. `BARRIER_TINT` A/B'd live
at the game camera: **0.40** red gone, **0.55** muddy brick, **0.75** signal red from 22 units up and
still plainly dimmer than the booth's lit windows two cells away. The red fails first every time.

**And the boom needed its underside**, which is the booth roof's lesson repeated one entry later: it
hangs at y 1.3–1.6 over open asphalt, so every ray through it exits the bottom, and a `FrontSide`
material renders BACK faces into the shadow map. `capDown` closes it. The cabinet needs none — it
stands ON the ground, where those rays land under the box itself. Verified live as a solid unbroken
shadow bar the full length; the moon throws it only 0.82 x / −1.24 z, a stripe hugging the bar.

**Verified live**: `__facility().batches` 7 → 6 rows (barrier gone from the prop path, so `EXTRA` is
down to fence + bin and `green` stays index-aligned). Cabinet 1.2 × 2.0 × 1.2, arm 13.8 long at
y 1.3–1.6 × z 0.34, the two abutting exactly at the cabinet's far face; mouth x 32.0–48.0 (4 cells),
tip 0.6 short. Arm `color` 0.75, casts. `make models` reports 30 up to date — `facility/barrier`
deleted along with its 100k master, its reference and its built glb.

**Verdict: landed.**

## The checkpoint's four follow-ups, and a mast bug they uncovered (2026-08-31)

Four things reported against the rebuilt barrier in one pass, plus a fifth that turned out to be a
placement bug older than any of this.

**The cabinet wanted art of its own.** It shipped in `facility/booth-roof` — the booth's painted
decking, on the argument that a machine housing standing beside a kiosk wants the kiosk's material —
and that came straight back as wrong. It is: a LID material reads as a lid material stood on end.
New `facility/barrier-post`, louvred dark grey-green steel, built the same way the arm's art is
(vertical, uniform top to bottom, so one UV period serves the sides and the lid). **0.0441 linear**,
which puts it between the asphalt it stands on (0.0329) and the park lawn (0.0414) and at half the
roof it used to wear (0.0849) — a dark box UNDER a pale cap instead of more of the cap, so no `lift`.
`BARRIER_CAB_TILE` **4.8** over the art's 16 slots gives a 0.3-unit louvre pitch, 4 across a 1.2-unit
face: deliberately coarser than realism wants, because from 18–55 units up a 7.5 cm slot is one pixel
and reads as noise. That constant is derived from the slot count and moves with a repaint.

**And it took two drops, which is the part worth keeping.** The first was prompted "COMPLETELY
UNIFORM FROM TOP TO BOTTOM" and gpt drew the slots with **rounded ends a few pixels inside the top
and bottom edges**. A rounded end is a horizontal feature, so it is a tile SEAM — and it showed up as
a plain band with slot stubs under it **10% up** the cabinet's faces (`v = y / TILE` crosses a whole
number at world y = 0, which is 0.2 above the kerb-dropped base) and **somewhere else entirely on the
lid**, because `cap` maps `v` to `z` where `face` maps it to `y`. Reported as "the box texture needs
to be a bit lower on the quads", which is exactly right about the side faces and is not a fix: a `v`
offset hides one of the two seams and leaves the other, and both positions move with the gate's world
position, so there is no per-compound shift that works. The art was the fix. Re-prompted with the
slots stated to run OFF the edges and be cut flat by them, and the tiling stated on **both** axes:
max row deviation **0.00706 → 0.00150** linear, a 4.7x improvement that puts it level with the arm,
and the top and bottom rows now differ by **0.0078** per pixel, i.e. it really does tile vertically.
**The lesson generalises to any art for an emitted box: ask for "tiles seamlessly on both axes", not
for "uniform" — uniform is what you want and tiling is what makes it true.**

**It also intersected the kerb.** The cabinet started flush with the gate hole's own boundary, and
the kerb edging protrudes `WALKWAY_BORDER_W` over the lower surface at every curbed edge — the same
fact `FENCE_INSET` already exists for. `BARRIER_INSET` is **two** of those: one width clears the
edging and the second is the gap. Live: x 32.4–33.6 against a boundary at 32.0.

**And the bar ended on half a band.** World-aligned UVs put the band grid on the WORLD while the
arm's length is derived from the gate, so the free end landed wherever the arithmetic left it —
reported as the tip split red/white. The art is laid out red-first and white-last, so a `u` that
reaches a whole number at the tip ends on the END of a white band, and `map.offset.x = ceil(u) − u`
is a pure PHASE change: same period, same texel density, nothing stretched. `Textures.loadTexture`
builds a fresh `Texture` per call, so the offset belongs to that one mesh. Live: 47.4 / 6.0 = 7.9,
offset 0.1, sampled 8.0 exactly, and the tip draws as a full white band.

**Then the lamps.** Two more reports — the mast beside the booth "goes onto the kerb and on empty
space", the gate's own mast "too low, goes into the walkway AND on top of the walkway" — and they are
one bug. **A mast stands on a VERTEX, a corner shared by four cells, but takes its `y` from ONE of
them.** That is harmless everywhere else in the compound, and the reason is worth stating because it
is what makes the entry special: the free axis runs ALONG the kerb, so the two cells it straddles are
the same surface, and the 0.2 step is only ever crossed on the AIM axis, where the kerb edging covers
it. The hole punched through the sidewalk band breaks exactly that — at its corners the four cells
are not one surface. The booth-side mast stood on walkway with **three** quadrants hanging over the
drop into the hole; the gate mast stood on lot with the **fourth** buried in the band.

The fix rides machinery that was already there. The free axis already had a step-back rule (a bay
divider otherwise stands the mast in the paint); it gained a second trigger — the + side carrying a
different surface — and one step settles both cases. Booth mast x **32 → 28**, gate mast z **−24 →
−28**, mast count still **25**, and every base now reads 0.01 (walkway) or −0.19 (lot) with no mixed
corner left. The gate mast is 6 units from the boom rather than 2, which is the cost: −28 is the
nearest clean vertex on that flank, since moving it in x instead would put a post in the gateway —
the one thing the lit-line rules refuse outright.
> The gate mast's −28 is SUPERSEDED by "Every mast stands on the walkway" below, which puts it back
> at −20. The free-axis rule itself stands and still fires.

**Verdict: landed.**

## Every mast stands on the walkway (2026-08-31)

Reported as a dichotomy, and it was sitting in plain sight in the `LINES` table: *"normal lamps are
all on walkways while park and parking lot ones are on ground/asphalt. let's put them on walkway too
(NOT on kerb)."* The table read

    { on: WALKWAY, by: ROAD }      // stands on the pavement, lights the road
    { on: LOT,     by: WALKWAY }   // stands on the TARMAC, lights the pavement
    { on: GRASS,   by: WALKWAY }   // stands on the LAWN,   lights the pavement

so two of the three rows were written the wrong way round. **The fix is not a new rule — it is those
two rows swapped**: `on: WALKWAY, by: LOT` and `on: WALKWAY, by: GRASS`. A lamp column is planted in
paving; it is not planted in a parking bay or a flower bed.

**And it costs no repositioning**, which is the part worth knowing. The placer puts the mast on the
VERTEX at the corner of the `on` cell facing `by` — and that vertex is the boundary between the same
two cells whichever way round the row is written. So swapping `on` and `by` moves nothing: it changes
which side of the kerb the base sits on (`surfY` reads the mast's own cell) and which way the head
faces, and nothing else.

Three tests had to follow the mast across, because all of them were written against it standing on
the lot: the parking-entry exclusion and the bay-divider surface test now read `h.col + DC[dir]`, and
`FacilityPaint.runStart` walks from there with `dir ^ 1` (the opposite of any of the four). The FREE
axis is untouched by the swap — the two cells differ only along the AIM axis — so the bay-phase
arithmetic is unchanged. `isParkPath` went the other way and got simpler: it is now asked of the
mast's OWN cell, which is literally what it tests for (a walkway with lawn across it both ways),
where before it had to be asked of the neighbour.

The gate's own mast comes back with it. It was pushed manually on the LOT flank, and the free-axis
rule from the entry above then walked it a full cell into the car park to escape a mixed corner —
*"lol, you moved the barrier lamp a full tile away"*. On the sidewalk BAND instead (`lampCol` is
outside the hole, so the band's own rows are still pavement there), taking the barrier's own row —
`FacilityEntry.barrier`'s expression verbatim, so mast and boom line up across the mouth. It lands at
z **−20**, two units from the boom rather than six, on a clean 2/2 kerb line.

**Verified live**: every mast base now reads **0.01** where the set was a mix of 0.01 and −0.19; the
four park lamps sit in one even column **down the path** (col 7 at x −170, z −106/−82/−58/−34, six
cells apart) instead of on the lawn beside it; the gate mast is at (48, −20). Mast count **25 → 29**,
because the `(col + row) % LAMP_SPACING` gate now runs on the walkway cells and a different set
qualifies.

**Verdict: landed.**

## Cars park in the lot, and a per-channel `baseColor` browned their windows (2026-08-31)

*"let's add a couple of cars — generate one model and put a few near the parking lot entryway."* The
generate half needed no argument: a car is nothing but its OUTLINE, which is exactly what the
silhouette-vs-surface test two entries up says a mesh generator is for, and the opposite of the booth
and the boom standing ten units from it. One gpt reference shot isometric from above a front corner,
`--lift 73` (gpt returned it at p50 47 — the band that makes TRELLIS read darkness as shadow and
invent an albedo).

**It shipped on the 100k-master route first, and that was wrong — the split ratio lied again.** The
master measured **1.47x**, comfortably inside the "offline decimate works" band, so it took the
`tree-broadleaf-full` treatment: `error` swept (0.005 floors at 9,037 tris, 0.05 at 7,583, 0.2 at
7,579, so the asymptote is reached by 0.05 for a free −16%). Reported straight back from the game:
*"texture became quite shit possibly due to decimation. can you generate 10k tris from the get go?"*
Correct on both counts. The decimated glb's own atlas measured **2.68x**, i.e. meshopt had shattered
the very thing the master's 1.47x was supposed to guarantee. **The ratio describes the master's atlas
and says nothing about what the decimation does to it** — precisely what `facility/trash-bin` already
records, one step worse.

Regenerated at `decimationTarget` 10000 → **9,773 tris at 1.65x**, `tris: -1`. Runware unwraps and
bakes AFTER its own decimation, so the atlas is authored FOR 9,773 tris (429 texels/tri at 2048)
instead of being a 95k atlas dragged down with the mesh. Components read 11 at 32.6% and the gate
calls that a REJECT; it is not one — outer shell (1,593 unique positions), a cabin floor (1,335) and
a greenhouse interior (1,322) because the body is HOLLOW, a bulkhead (118), and **114 / 109 / 106 /
92 at x ±0.156..0.201, y −0.185..−0.039, at the four corners in z**, i.e. the wheels. Eight pieces
hold 98.0%.

**`tex` is 1024 and the per-triangle rule would have shipped 512.** That rule looks at 9,773 tris and
calls 512 a healthy 27 texels/tri. Measured the other way — area-weighted UV texels over world area
at the `h` the game draws it — 1024 lands on **58.7 texels per world unit** against the
ground/walkway/lot tiling's own 512/`GROUND_TILE` 9.0 = **57**, level with the asphalt the car stands
on; 512 would have halved that. This prop hits the trap harder than `tree-broadleaf-full` did, and
the reason is worth keeping: **the atlas is spread over the three inner surfaces too**, 221.8 square
units of skin for a car showing about half of it.

**The `baseColor` finding is the one to carry, and it belongs to the retired bake.** That one came
back TEAL — atlas mean 60/91/104, tri-sampled 51/80/93, from a near-neutral cool 70/73/76 reference —
so `propstat` suggested the usual per-channel fit, `[0.65, 0.27, 0.2]`, which neutralises the mean by
lifting R against G and B. Built and looked at from the game camera, **every windscreen and side
window came out rust brown**. The cast was not uniform over the model: the body was teal and the dark
glazing was not, so a factor with a 2.4x R-to-G ratio corrects the body and warms the glass by the
same 2.4x. **A per-channel factor is only right when the cast it corrects belongs to the whole
surface; here it belonged to one material.** Same shape as the boom barrier's `lift`-vs-`color`
finding one entry up: when two tones must keep their relationship, the correction has to be the one
that cannot change it. The at-budget bake has no cast to correct at all (63/67/74 atlas, 64/68/73
sampled, tracking the reference's own hue), so its `baseColor` is a plain level fit — flat **0.53**,
landing it at 46/49/53.

Placement is `render/facility/FacilityCars.hx`, render-only and derived like everything else at this
gate: the bays are not stored anywhere, they fall out of `FacilityPaint.runStart`'s own rhythm, so a
car lands centred in a painted spot rather than beside one. Bays are sorted by distance from the gate
mouth and the nearest `CAR_COUNT` filled, with one in `CAR_EMPTY` left open — there is one car model,
so a solid run of them is one car repeated, the obituary `GreenProp.scaleJit` already carries for 163
identical bushes, and a size spread is not available on a manufactured object. The only variety left
is a hashed half-turn, which is free.

**Verified live**: batch `models/facility/car.glb` count **5**, three in a row at z −172 (x 4/12/20,
one bay apart, yaw 0) and two at x 4 (z −156/−148, yaw −π/2) — the two kerb runs either side of the
mouth, each car's length on its bay's depth axis. Material color 0.53 flat, map 1024. The 100k master
and its duplicate reference are deleted; `models-src/facility/car-src.png` is the archive.

**Verdict: landed.**

## A 2-cell window run stops drawing all three panes (2026-08-31)

*"there are 3tile and 2tile wide windows and they utilize the same texture, that looks dumb because
it scales."* Exactly right, and it was the common case rather than the corner one: **27 of the 45
runs a generated area deals are 2-cell**. `pane` emitted `u` 0..1 whatever the run's length, so a
2-cell opening drew the whole three-pane ribbon squeezed into two cells' width — the same window at
two thirds scale, next to its full-size neighbour on the same facade.

**The answer is a SECOND ART, `facility/window-ribbon-2tile-lit`** — the same unit with one mullion
and two panes, hand-derived by the user from the three-pane drop. How many panes a run shows is a
property of the image and not of the geometry, so that is where it should be said.

**Cropping the three-pane art was tried first and rejected, and it is worth knowing that it WORKS.**
Binning the built art's 464 columns by luminance puts its four dark members at u
**0.0000-0.0345 / 0.3211-0.3578 / 0.6422-0.6767 / 0.9655-1.0000** — frame, mullion, mullion, frame,
all 16-17px — so a crop can be cut at the first mullion's LEFT EDGE (`0.3211`, not a flat ⅓, which
cuts 6px into it and leaves the opening's left edge two thirds the thickness of its right) and
anchored at u = 1 to keep the right frame whole. Built that way it drew correctly. It is still the
worse answer: a crop can only ever hand back a strip of an image authored for a different pane count,
its offset has to be re-measured against the art whenever either changes, and its 2-pane strip
carries three members to the other's four so its panes come out 1.7% narrow. *"not good enough"* —
and a second file states the same thing once, in the place that owns it, for the same runtime cost.

**Measure against the LOADER's own threshold, not a convenient one.** `Textures.loadAlphaCropped`
skips alpha <= 8, and read back off the live material it crops the new art to **316x161 = 1.963**
against the three-pane one's 464x160 = 2.900. The source measures 1.972 at a stricter cut — a third
of a percent, a 0.01-unit stretch, but there is no reason to carry the wrong number. The three dark
members are 16/17/16px with the mullion dead centre, so its panes come out the same width as the
other's: the same pane, one fewer of them.

**The height had to follow, and that is the half of this that reads from across the lot.** Nothing is
ever stretched, so a run's height is its width over the aspect of the art it draws — new
`FacilityGeom.paneTall(len)`, called by BOTH passes over `m.windows` (the one that records the hole
for the wall emitter to leave, and the one that fills it). A 2-cell run goes from **2.76 tall on a
1.62 sill to 4.08 on 0.96**, against a 3-cell run's 4.14 on 0.93. The two lengths now stand level on
the same facade, which is the correct answer and not a coincidence: **a pane is a pane**, so a
shorter opening is fewer of them and not smaller ones.

The art drops in with nothing else to re-tune, because it is the parent with the third pane cut away:
same 1024 canvas, same y band, same left origin, and `glass_alpha [136,128]` still lands — luma over
the opaque content is bimodal at frame 16-127 **31.2%**, glass 144-207 **56.4%**, a 0.25% valley
between, within a point of the parent on every band.

**Then the new art showed a thin slit along the top of every 2-cell window with the interior visible
through it** — *"its just a little too low… increase scale a little?"* — and the cause is worth
keeping because it is a property of the CUT and not of this drop. Dumping the built art's top rows:
**row 0 comes back at alpha 4.4**, against `addPane`'s own `alphaTest` 0.02 * 255 = **5.1**. So the
outermost texel row is discarded and the glass is one row short of the opening. The three-pane art
never showed it only because its own top row happens to land opaque (alpha 254); the rest of the
image is identical, frame rows 1-15 dark and glass from row 16.

The fix is `WINDOW_OVERLAP` **0.025**: the pane quad is drawn 1.25% bigger at each edge, **in both
axes so the art keeps its aspect and nothing is stretched**, grown along the run's own axis (never
across, which would move the quad off the glazing slab's face rather than lengthen it). That is 0.051
world units = **two texel rows** at either art's density — one would close the slit, two also cover
the bilinear tap that reads the discarded row's neighbour. The extra is invisible because the glazing
slab is `GLASS_T` 1 thick inside a `WALL_T` 2 wall, so it sits half a unit behind the wall face on
both sides and the overhang is buried in masonry. The head and sill caps keep the opening's true
size; only the glass grows.

**Verified live** on a facade carrying both (structure 0, row 6, runs at cols 17/21 len 3, 25/28 len
2, 31 len 3, 35 len 2, 40/44 len 3): the pane materials read **464x160, 316x161, 464x160, 316x161**
with `repeat` 1 and `offset` 0 on all four, every 2-cell opening draws two panes at the 3-cell run's
own pane size, the heads line up, and the slit is gone from a camera looking down on the head.
`paneTall` 4.075 / 4.138, sills 0.962 / 0.931. Both structures with windows carry both lengths, so
pane meshes go **2 → 4**.

**Verdict: landed.**

## The lab buildings get a parapet, and a roof to stand things on (2026-09-01)

The facility's roof was a flat plane of tiled quads at `ROOF_Y` 6.0 with the wall stopping dead at
it and nothing standing on it — from a camera pitched 51 degrees down, a lid. The city has solved
both halves for years (`render/world/roofs/Parapets.hx`, `RoofDetails.hx`) and the facility
inherited neither. The hangar is skipped whole; its roofline is a job of its own.

**The parapet is a MITRE, and getting that wrong is the entry.** Every band's outer plane sits at a
constant `PARAPET_INSET` = `(CELL - WALL_T)/2` = 1.0 in from the cell boundary — never at `slab()`'s
plane, which is `GLASS_T` on a glazed cell and would jog the ring half a unit in and out at each of
the ~90 window-run ends. It costs one `capDown` soffit per glazed band (the ring oversails the
thinner slab) and buys a dead straight roofline plus a joint test that never compares planes.

A joint between two perpendicular bands then had **one** growth number per end — retract `T` at a
convex corner, extend `T` at a concave one — and it was wrong in a way no number printed: **both the
outer and the inner face retracted, so the T x T corner square's own OUTWARD face was never
emitted.** Photographed at every building corner as a vertical slot you can see straight through
onto the deck; a raycast down the slot at 910px x 250..430 came back `roof.png` at y 6.0 for five
consecutive samples between two `booth-roof` hits at 7.35. The fix is five parts per band, not one:
**both OUTER faces run to the corner and meet in a line, both INNER faces stop one thickness short**,
so the square is enclosed and solid. The coping's two fascias mitre the same way one thickness wider.
Only the coping's TOP keeps an owner/yielder split, because it is the one HORIZONTAL part and two of
them meeting would overlap and z-fight — z-bands own every corner, x-bands yield, which is
`Parapets.parapetRing`'s always-emitted corner post transposed to an axis rule.

**`carries`, not `isWall`.** A door cell never enters `structure()`'s `for (dir in 0...4)` loop, so
keying the band predicate on `isWall` opens a 4-unit gap over each of the area's exterior doors.
`slab()` on a door cell is already inset by exactly `PARAPET_INSET`, so the band runs straight over
the opening with no case of its own.

**The cladding costs NO draw call** — it merges into `wOut`, which is the exterior wall's own buffer
at the same texture and the same world-aligned UVs, already casts and receives, and is already
`VisionMask`-patched at the same XZ. `wall-exterior.png`'s horizontal joints are on a 192px pitch =
1.125 world units at `WALL_TILE` 6.0 with no vertical composition, and `WALL_H == WALL_TILE`, so the
panel course simply carries up past the roofline.

**The coping took three materials to get right and the first two are the finding.** A coping has to
read as a LINE along the roofline or the parapet is just a taller wall. Mean linear luminance:
`facility/wall-exterior` **0.0323**, `city/coping` **0.0320**, `facility/window-head` **0.0462**,
`facility/booth-roof` **0.0849**. The street's own `city/coping` is within **1%** of the wall — a
coping nobody can see, and a material `color` scalar can only move it DOWN, so brightening it needs a
`lift` on a new `textures.json` entry, i.e. new art after all. `window-head` at 1.43x was built,
shipped and photographed at the game camera: **indistinguishable from the cladding under it**, and it
took painting the material pure red in a live frame to prove the geometry was there at all. Shipped
on `booth-roof`, 2.6x the wall and 5.1x the bitumen roof behind it — the guard booth's own painted
steel decking, on `ROOF_TILE`, because a coping IS a lid and that is not the mistake the barrier
cabinet made borrowing it. It is the parapet's one draw call per structure; it does not cast (the
cladding under it does, and at the moon box's 0.088 units/shadow-texel a 0.25-tall band overhanging
0.12 adds three texels to a silhouette already thrown).

**On the roof: two generated props and one box.** `facility/roof-ac` (a condenser, 5,619 tris) and
`facility/roof-dish` (a comms dish, 5,800), both generated AT the budget with `tris: -1`. The dish
took two references and the first is the lesson: an open square-tube pedestal with three thin feed
struts and a clipped cable came back **20 components at 74.4%** — the lace-and-holes case. Repainted
as ONE SOLID CONNECTED OBJECT (closed tapered pedestal, one thick arm, unbroken shell) it comes back
**8 at 47.8% with the top five holding 93%**, and those five ARE its parts. The raw largest-share
number went DOWN and the prop got better; the orthographic preview (`tools/emissive.py` over the
whole bbox, everything selected) is what settled both it and the AC's 88.6%. Split also fell 2.28x ->
1.48x on the repaint. The access hatch is merged geometry — a box, so the booth's own rule — 10 quads
in the coping's material.

**`propstat`'s per-channel `baseColor` was wrong on the AC, which is `facility/car`'s finding on a
prop with only ONE material.** The bake is 55/64/60, neutral leaning very slightly green, so the fit
that neutralises that mean is `[0.87, 0.64, 0.73]` — a 1.36x red-to-green ratio that turns a
grey-green steel box **TAN**. Seen standing on a grey roof and invisible in every number propstat
prints. A flat **0.72** keeps the hue and moves only the level.

**Placement is strided, not capped.** Candidates are interior floor cells whose four neighbours are
also this structure's interior floor (which is what keeps everything clear of the wall ring the
parapet stands on), thinned on `(col*3 + row) % 5`. A running cap on top of a row-major scan spent
the 31x24 building's whole allowance on **rows 8 and 9** with the rest of the deck bare; striding the
list to `ROOF_PROP_MAX + 2` spreads it — rows 8, 9, 16, 17, 19, 25, 26, 28 across cols 18-38. One
dish and one hatch per building, the hatch nearest the middle where a stair core comes up.

**They have to go when the deck does.** `Models.cull` already took an optional `mask`, so the two
batches take `reveal[structOf[i]] < 0.5` on top of the frustum test; the hatch is merged into the
structure's own fading roof mesh through a generalised `addRoof` -> `addDeck(scene, b, tex, fades,
shell)`. Verified with the free cam PINNED over structure 0's roof and only the player moving:
player inside -> AC drawing **0**, dish **0**; player outside -> **7** and **1**, exactly that
structure's own. The hatch reads `opacity 0, visible false` for structure 0 while structure 1's stays
at 1, and both copings stay opaque and visible throughout — the roofline survives the fade, which is
the rim's whole job. It is a hard cut at 0.5 and not a cross-fade (`ponytail:` a per-instance alpha
attribute is a lot of machinery for a prop the player is walking under at the time).

Live: parapets **110 cells / 635 quads** and **78 / 453**, hangar **skipped, 0/0**; 14 condensers, 2
dishes, 2 hatches. Cost, measured in one pinned game-camera frame by flipping `visible` on the six
new objects: **111 -> 101 calls, 41,302 -> 33,270 tris**. 0 console errors, no persisted change.

**Verdict: landed.**

## Five reports off the parapet build, and two sources that never tiled (2026-09-01)

*"a) z-fighting from 2-tile wide window. b) probe polygon should display texture name under the
texture. c) upper parapet part should use concrete blocks tex. c) upper parapet bottom quad is
missing. d) wall parapet continuation wall-exterior is not seamless."* All five confirmed, all five
fixed. Two of them are the same lesson about a tiling source, and one is a rule this repo already
wrote down and this code then broke.

**`WINDOW_OVERLAP` made the pane coplanar-and-overlapping, which is exactly what the deleted
`WINDOW_EPS` row said could never happen.** The wall above and below an opening is emitted on the
WINDOW CELL's own slab (`structure()`'s sill/head pair at `FacilityGeom.hx:411,453`), i.e. the
GLAZING plane, and `pane` is flush with it. That was safe while the pane matched the opening exactly
— the emitter cuts the hole rather than painting over it — and stopped being safe the moment the pane
grew 0.051 past the head and the sill to cover the texel row `alphaTest` eats. Two coplanar quads
overlapping is the case `docs/3d-render.md`'s standing note is about: **give it a physical gap, not
`polygonOffset`**, which has lost three times here and would be dropped outright anyway, since the
pane casts through a swapped depth material. New `WINDOW_EPS` **0.02** (`Buildings.OVERLAY_EPS`,
tuned there against this exact question: 0.06 read as a gap, 0.01 as flush) widens the pane's rect on
the CROSS axis, which pushes both faces off the plane at once, each in its own outward direction. It
cannot re-open the old seam **because of the overlap**: the pane already runs past both caps and into
the flanking cells' butt caps, so a hair of standoff moves within geometry that covers it.

**A coping is not a kiosk lid — `facility/coping`, its own art.** `booth-roof` was reached for
because it MEASURED right, not because a coping is made of painted steel decking; the level was the
only part worth keeping, and the new stones are lifted onto **0.0840** against its 0.0849. Same
VERTICAL-JOINTS, UNIFORM-TOP-TO-BOTTOM construction as `barrier-arm`: `band` emits the cap and both
fascias through `face`/`cap` on ONE period, so the 0.25-tall fascias sample **2.8% of the image**
(`y/9.0`) and the top cap a different slice again (`z/9.0`).

**The drop did not tile, and neither did `wall-exterior` — same fix, and the second one is what
report (d) was.** gpt draws a regular pattern on an exact pitch and then cuts the frame wherever it
likes. `wall-exterior`: 192 px courses, but **79 px below the last joint and 175 above the first**,
so the wrap made ONE course 254 px = 1.5 units against its neighbours' 1.125 — invisible for two
years because `WALL_H == WALL_TILE` means a wall spans v 0..1 and never wraps, and the parapet is the
first thing to run past 1.0. Measured, top row against bottom **5.24/255 on a 1.73 row step**.
Coping: six stones on a 204.75 px pitch with the sixth joint cut at the edge, **48.5** left-to-right.
Both corrected in the SOURCE — crop to a whole number of periods between two joint CENTRES, resample
back to 1024, feather what the crop could not land — rather than re-rolled: it holds the composition
fixed and costs nothing. Source seams **0.00** on both.

**Then measure the BUILT file, because the downscale un-tiles a joint sitting on the edge.** The
coping's source measured 0.00 and its 512 output came back at **7.88 on a 3.04 column step**: a joint
centred on column 0 is split across the two sides, and `tools/textures.py`'s resample blends each
half with its own neighbours only, so half a joint lands at each edge. **Rolled 128 px** so the wrap
falls on flat stone and the built tile measures **2.05**, under its own noise. `wall-exterior`'s
built vseam is **0.35** against a 1.73 row step, five times under it.

**The coping's underside was a deliberate omission and a wrong one.** "Nothing downward-facing at the
roofline is ever seen" is true of the DECK, which is enclosed; the coping oversails `COPING_OUT` on
both sides and its underside is the only thing there to see from under the parapet. One `capDown` on
the `P_COPE` extents — one quad, not the two 0.12 strips, since the middle 0.6 is buried either way —
which inherits the corner mitre for free. Coping quads per band **3 → 4**; parapet totals **635 →
749** and **453 → 535**, exactly +1 per band (114 and 82).

**`PolyProbe` now names the art under each pane**, because `name` is the only provenance that
survives: a cropped or chroma-keyed variant hands three.js a CANVAS, so `image.src` is gone, and a
glb's maps are embedded. All four `Textures` loaders stamp the path, and `Models.get` stamps it on
every map a glb carries (base and emissive both). `three.Texture` gained a typed `name` field rather
than an `untyped` write.

**Verified live**: probe on the parapet reads `textures/facility/coping.png`; a raycast under the
overhang hits `coping.png` at y **7.100** across the whole 0.12 strip; a 2-cell run photographed
head-on has clean head and sill. One trap worth keeping — **the free cam cannot judge any of this**:
every shell surface is `VisionMask`-patched, so away from the player it sinks to the fog colour and
a coping painted pure RED for an A/B did not show at all. Set `VisionMask.uFloor.value = 1` for the
look, and reload after.

**Verdict: landed.**

## The window capping was right in one reveal state and wrong in the other (2026-09-01)

Reported from the game: the wall top over a window run wears `facility/window-head`, which is correct
while the roof is transparent and wrong while it is up.

`FacilityGeom.capTop` picked its buffer off one flag — `glazed ? head : rim` — so the band it lays at
`ROOF_Y` was aluminium capping over glazing and bitumen everywhere else. That band is IN the roof deck
plane. How much of it shows from outside is arithmetic: a glazed cell is `GLASS_T` 1.0, so its slab
spans 1.5..2.5 of the cell and the band is 4.0 x 1.0; the parapet reaches `PARAPET_INSET` 1.0 +
`PARAPET_T` 0.6 + `COPING_OUT` 0.12 = **1.72**, and the fading deck starts at 2.5. **0.78 x 4.0 per
glazed cell is bare, at 108 of them in a generated area** — measured, 65 on the big lab and 43 on the
small one.

Built art: `facility/roof` **0.0275** linear against `window-head` **0.0352**, and the tile pitch
differs 3x (`ROOF_TILE` 9.0 vs `HEAD_TILE` 3.0). The read is the pattern, not the level.

**Both states want a different texture in the same place, so emit both.** One extra call after the
existing one, `capTop(roof, head, m, col, row, false)` — the same extents into the FADING deck buffer
with the deck's own art — and the capping sinks `HEAD_DROP` 0.02 out of plane under it. `capTop`'s
first parameter is now `deck` rather than `rim` for exactly that second call; no argument was added.

**Sink the capping, not the deck.** The deck has to stay dead flat with the rest of itself, and what
the capping abuts is a rim band it can sit 0.02 under unseen at this camera. A physical gap and not
`polygonOffset`, per the standing note.

**`FacilityArea.apply` already was the crossfade** — `mesh.visible = opacity > 0.02` and
`depthWrite = opacity > 0.5` — so nothing had to be told about the swap. Measured inside structure 0:
deck `visible false / opacity 0 / depthWrite false`, capping drawing clean underneath.

**Verified**: every one of the 65 + 43 capping quads at y 5.98 has an exactly coincident deck quad at
y 6.0 (rect keys compared off both index buffers). A/B in one pinned pose by pushing the capping to
6.04 and back — the old build puts a pale strip along the whole roofline of the south and east walls;
the new one is unbroken bitumen. Stepping inside, the capping is back over every run. +108 quads into
meshes that already exist: no draw call, no new material.

**Verdict: landed.**

## The hangar meets the ground, and gets an arched roof to be a hangar (2026-09-01)

Four reports in one pass: the hangar's walls hanging in the air, its roof wanting to be curved metal
on a real circular arc, and the parking lot wanting debris.

**(a) Two defects under one wall, not one.** `baec60d` dropped `Surf.LOT` to `-KERB_DROP` (−0.2)
while every wall in `FacilityGeom` was emitted from a literal `0.0`. `FacilityStyle.KERB_DROP`'s own
header had predicted it — *"raise the pavement and every wall base floats"* — and assumed the 2-cell
pavement apron protected every structure. `generateHangar` is the one that has that write
**commented out** (`FacilityAreaGenerator.hx:265-269`), so the whole hangar perimeter is asphalt at
−0.2. The second defect was hiding inside the first: `FacilityGround`'s masonry riser closed the slot
at the CELL BOUNDARY, but the wall cell's own margin strip is laid at the *neighbour's* height by the
`floorStrips` pass, so both sides of that riser sat at −0.2 and it stood in the lot as a **0.2 fin one
unit off the wall**, with the gap it was meant to close still open behind it.

Fixed the way `FacilityEntry` already fixed the guard booth standing on the same asphalt: **the
masonry goes down to meet the ground, the ground does not step up to meet the masonry** — new
`FacilityStyle.WALL_BASE = -KERB_DROP` through the wall faces, `butt` and `jamb`, plus a `threshold`
pair on every exterior door cell (there is no masonry under a lintel, so the hangar's side door had
the same slot with nothing to close it). The riser branch then deleted, not kept. Everywhere else the
skirt is free: it hangs under an opaque plane whose top edge is its own top edge, and a camera
pitched 51 degrees down cannot see under a step. Measured live: `wall-hangar` and `door-hangar`
minY **0 → −0.2**, and the lot mesh reads **`nY 1`, min = max = −0.2 over 2,368 tris** — dead flat,
so the fin is gone.

**(b)/(c) The vault is DERIVED, not drawn.** Span and rise are the only inputs: for a chord S and a
segment height H the tangent-chord angle gives `tan(theta/2) = H/(S/2)`, so `theta = 2·atan(2H/S)` is
half the subtended angle and `R = (S/2)/sin(theta)`. On the generated hangar: span **38**, rise
**3.42**, **R 54.49**, **40.8 degrees of arc** — a small piece of a big circle, which is what "much
less than a half-circle" asks for. Live: 96 tris = **48 quads = 3 × 16 seg**, y 6 → **9.42**
(= ROOF_Y + rise, exactly), and **9 distinct heights over 17 columns** — the symmetry a circular
segment must have, and a cheaper proof than any picture.

Three things it turned on. **The arc is walked BACKWARDS when the ridge runs along x**: the two
orientations map (along, cross) onto (x, z) with opposite handedness, so one winding rule emits an
upward-facing vault for one and an invisible downward-facing one for the other (`addDeck` is
`FrontSide`) — one sign cancels it and the winding is written once. **v runs on ARC LENGTH, not the
chord projection**, or the ribs crowd together toward both springings, which is "never stretch" on a
curve. And the vault is a **SHARED-VERTEX grid** rather than n loose quads: `MeshBufTools.quad`
pushes four fresh vertices every call and `geom` derives normals with `computeVertexNormals`, so
loose quads shade FLAT — and a faceted barrel is the one failure a curve cannot survive, its whole
read being that it is smooth. `MeshBuf` has no emitter for a shared grid because every other surface
in this game is flat enough not to want one.

The flat deck is skipped on a hangar (dead geometry under the vault, and dead transparent overdraw);
the **rim stays**, capping the wall head under the springing. Vault and both crescents ride ONE
buffer at `addDeck(..., fades = true)`, so walking in opens the shed exactly as walking into a lab
building opens its deck and `FacilityArea.ease` needed to be told nothing.

**The art existed and the LEVEL did not.** `city/roof-metal` is already ribs one way and lap seams
the other, which IS a fall line and a sheet lap — no generation spend. But it measures **0.0913
linear**, 2.4x the hangar's own cladding (0.0373) and brighter than the coping (0.0840), which is the
brightest thing on a roofline by design; on a vault that size it is a white lid. A second label
`facility/roof-hangar` on the SAME source with `lift 1.32` lands it on **0.0450**, a shade over the
cladding it springs from. A second label rather than a lift on the city entry, which would repaint
every metal warehouse in the city.

**(d) Litter and junk, and they are not each other's fallback.** `FacilityDebris` fills the
`debris()` hook `FacilityArea` had been reserving (*"the lot pass is what will scatter it"*) — the
`WildDebris` shape with its distance falloff replaced by a two-tier EDGE test, because litter does
not fall off smoothly with distance, it collects where something stops it blowing. **41 fragments
live, 0 draw calls** (shared `DecalBatch`). But those atlas rows are the only alpha-capped block in
`entities64` (peak 127), so litter can never read as more than scraps — hence three new props at one
batch each: `facility/lot-cone`, `lot-tyres`, `lot-reel`, all generated at budget, all free-yawed
because dropped junk lies any way up where a parked car and a roof condenser take a quarter turn.

Two prop notes worth keeping. `lot-cone`'s reference came back at subject p50 **88 with a subject
margin of MINUS ONE** — the mirror of the `sewer/bags` failure, a subject too BRIGHT to segment
against its own backdrop; `propstat --lift 72` fixed value and margin (→ 22) in one pass while
holding the composition, so no re-roll. And `lot-tyres` asked for **mid-grey sun-faded** rubber
rather than black on purpose, which is the `sewer/bags` lesson applied before the fact: it came back
**1 component at 100%**, the cleanest drop of the three despite being a stack of toroids with real
holes through it.

Cone (2 at 71.6%) and reel (6 at 44.5%) both trip `propstat`'s raw 90% gate and neither is a reject —
the orthographic preview settles both, as it did for `roof-dish`: the cone's two pieces are its shell
and its square base (the shipped conifer's 51/49 shape) and the reel's top five hold **97.6%** and
are its flanges, barrel and hub boss.

**Verdict: landed.** +3 draw calls for the lot props, ±0 for the vault (the hangar's flat deck mesh
goes as the vault arrives), 0 for the litter. No persisted change: everything is derived from the
saved cell grid, so every compound already saved gets all of it on the next draw.

## The vault was fitted to the wrong rectangle, and its gables were roofing (2026-09-01)

Four reports off the entry above. Three are the same object.

**The vault overhung one gable by exactly one cell**, reported as the roof being too big. It took its
box from `st.ox1..ox2` — the structure's own bbox pulled out by one cell for the wall ring — and that
is right only when the bbox is the pure interior. It is not: `findStructures` floods over `isIndoor`,
and **a door cell finalises to plain corridor lino**, so a doorway in the wall ring is already inside
the fill's bbox and growing it by another cell lands a whole cell outside the masonry *on that side
alone*. The generated hangar has one side door, at col 44 in a west wall that runs at col 44, so
`ox1` came back 43 and the roof hung 4 units past the wall — while the other three sides landed
correctly, which is what made it read as an odd bulge rather than as an oversized roof.

What made it invisible to the debug block is worth more than the fix: `span`, `rise`, `radius` and
`arcDeg` are all measured across the SHORT axis and were all correct. Only the ridge was long. The
box is now measured off the cells the structure OWNS — walls, doors and floor — which is the ring
itself and needs no assumption about what the bbox means. Live: `ridge` **54 → 50**, and the vault
mesh's x extent now equals the wall mesh's to the unit (`[-23, 27]` both). `ridge` is now in
`__facility().roof.hangar` for exactly this reason.

**The gable crescents were in the roof buffer and are cladding.** They were emitted with the arch, in
`ROOF_HANGAR` sheet metal, in the fading deck — so a hangar had a horizontal seam at `ROOF_Y` where
one material butted another, and walking in took both gable ends away with the lid. A gable is the
wall carrying on upward, which is the same object the lab buildings' parapet ring already is: it goes
in `wOut`, the structure's own exterior buffer, at `WALL_TILE` on the cross axis and on y, which is
`FacilityGeom.face`'s own mapping for a wall running that way. **Same mesh, same course, no draw
call, and it stays when the roof fades.** The seam is gone because there is no longer a join —
verified straight-on at both gables, the corrugation runs unbroken from the asphalt to the arch.

Normals checked rather than eyeballed, since a reversed crescent is invisible and not inverted:
**30 outward / 2 inward per end, and the 2 are the zero-area triangles at the springings** where
`ys[i] == ROOF_Y` makes the quad degenerate. Vault: 32 tris, all up.

**The side doors hung in the air**, which is `WALL_BASE` reaching the one place it could not. A leaf
stands on the floor at y = 0 and the surface a doorway opens ONTO need not be that floor — the hangar
is the one structure that opens straight onto the dropped lot. The hinge cannot move: it is what the
swing turns about and what `DOOR_H` is measured from. So the leaf grows a **skirt** downward instead,
with **v going negative over it** and the art already loaded `ClampToEdgeWrapping`, so the skirt
samples the leaf's own bottom texel row — no second art, no stretch, and everywhere but the hangar it
is buried under an opaque plane whose top edge is y = 0. Live: leaf local y **[0, 4] → [−0.2, 4]**,
head unchanged.

**And the litter was halved** — 0.06/0.26 → 0.03/0.13, the ratio held at 4.3x so it still collects
against the edges. Verified as arithmetic rather than by eye, because the accept test is
`h % 1000 < chance * 1000` and `h` does not depend on `chance`: over the 878 candidate cells the
window takes **225 → 113, a ratio of 0.502**, with `mix` measured uniform across its ten deciles
(67–105 against an expectation of 88). Note the old entry's "41 fragments" was a `DecalBatch` **draw**
count and is camera-dependent; the stable number is the spot list, which reads 53 at the new rate.

**Verdict: landed.** −1 draw call (the crescents merge into a mesh that already existed), no
persisted change.

## A solid door was spilling light, and every exterior door gets a lamp instead (2026-09-01)

**The hangar threw a lit trapezoid across the lot out of a sheet of steel.** `FacilityGlow` spilled
out of every exterior doorway, on the reasoning its own comment states — "a facility door is glazed
and `objects.Door.canSeeThrough` is true for it, so the light crosses a shut leaf as readily as an
open one". True of the seven `GLASS` doors the generator deals, false of the eighth. The gate is
`look`, the painted pair the leaves draw with, which is the one field that already says whether
light passes: `GLASS` spills, `METAL` and `CABINET` do not. Measured on the generated compound —
27 doors, 8 exterior, and exactly one of those solid.

**What a solid door gets instead is a lamp over it, and so does every other exterior door.** The
read being bought is "that dark rectangle is a way in", and that only works if a lit doorway is
always lit the same way; restricting it to the hangar would need a test with no principle behind it,
where `FacilityGlow.outward` already answers "does this doorway face outdoors" for free.

**No glb, and the rule already settled it.** A hood on a wall is axis-aligned slabs — the guard
booth's finding. Emitted it is **four quads** (three sides and a top; no back, it is against the
masonry, and no underside, this camera pitching 51° down) in `wOut`, the exterior cladding's own
buffer, at the wall's own tiling art and world-aligned course. **Zero draw calls**, exact
proportions, no unwrap lottery. Generated it would have been ~5k tris for something 1.4 units wide.
The stronger silhouette-vs-surface test agrees: a box hood has neither an outline worth generating
nor a pattern worth painting, and what actually reads is the glow on it. (The NOT-A-GLB half of that
still stands; the `wOut` / zero-draw-calls half does not — see the next entry, where the hood takes
its own art because the cladding made it read as a lump of wall.)

**The warm hue costs no material.** `LAMP_COLOR` is a cool 0x9db4d4 shared by every mast, fixture
and glow quad in the compound, so a doorway lit in it is one more lit surface; amber, it is a way
in. The additive mesh is already `new Color(LAMP_COLOR) * GLOW` with `vertexColors` on, and that
channel had only ever carried a GREY brightness — pushing the ratio
`linear(DOOR_LAMP_COLOR) / linear(LAMP_COLOR)` instead turns one quad amber inside the shared mesh,
and it is right whatever colour space `new Color` works in, both terms being in the same one.
Verified off the built buffer: the lens vertices carry **(2.373, 0.790, 0.077)**, which is that
ratio × `C_DOOR_LENS` 0.8 to rounding. The spotlight needed nothing at all — `LampPost` has carried
a per-post `color` all along. Only the CONE is a second batch, `LightCone` taking its tint as one
uniform: **8 instances at ffb347** beside the masts' 27 at 9db4d4, and **that is the one draw call
this fitting costs.**

Two things caught by measuring rather than by looking. The shared point is the **lens plane**, not
the hood's centre, so centring the box on it floated the hood **0.3 off the wall with daylight
behind it** — visible in the vertex dump (x −23.9..−23.3 against a wall face at −23.0) and not in a
night screenshot; it now reads −23.6..−23.0. And the lamp had a **ground pool** for one build, which
is not how an outdoor lamp works here: a mast draws a cone and claims a spotlight and puts no
additive quad on the ground at all, `C_POOL` and `C_SPILL` being for a room seen through its own
faded roof and for what falls out of a window. Built, it was a flat amber card lying on the lot with
the cone's own shaft landing inside it. Dropped — the cone and the pooled spotlight light the
asphalt, exactly as they do under a mast.

**Verdict: landed.** +1 draw call (the warm cone batch), no persisted change. The hood, the lens and
the spotlight all hang off one shared `FacilityGlow.lamp` point across three files, so a hood that
drifted from its own light is not a thing any of them can do alone.

## The door lamp's hood gets its own art, its cone stops at the door, and an outdoor lamp stops shadowing indoors (2026-09-02)

Three reports on the fitting landed above, and the third is not about the fitting at all.

**The hood wore the cladding and read as a lump of wall.** It rode `wOut` for the zero draw calls,
which is exactly what the parapet ring and the gable crescents are right to do — they ARE wall. A
lamp housing is not. New `facility/door-lamp`, and it is **featureless on purpose**: the box is
1.4 × 0.6 × 0.5, so `face` samples a 20%-tall slice of the image up the sides and `cap` a different
one across the lid on the same single period — the thin-bar case `BARRIER_ARM_TILE` and
`BARRIER_CAB_TILE` both record, where a horizontal feature becomes a seam in one place and a
different seam in another. Art with no feature in it has no slice to misalign, so nothing has to
tile and no second period is needed. Measured on the drop: row deviation 0.0090 and column deviation
0.0056 on a mean of 0.610. As painted it is **0.3295 linear**, the brightest source in the facility
set by a wide margin; `lift 2.3` lands it on **0.0825**, which is the coping's own 0.0851 and 2.5×
the cladding — the level this repo has twice measured as reading as a separate element on a wall.
ONE buffer for the whole compound rather than one per structure: the exterior cladding does not
fade, so there is no reveal state to keep apart. A/B'd in a pinned frame by hiding the mesh:
**calls 67 / 66 / 67**, so **+1 draw call**. `castShadow` is OFF — with it on the same A/B read
68 / 66 / 68, for two screenshots that cannot be told apart, and nothing here stands between a
caster and a surface (the only casting spotlights hang below the hood's own top and aim down).

**The cone hung off the hood's lip, because it rode the lens plane.** The shared `FacilityGlow.lamp`
point is the housing's FRONT FACE, so the shaft's top disc sat half in front of the fitting and half
depth-rejected behind it. Pulled back `DOOR_LAMP_D / 2` onto the hood's own centre line the whole
disc is inside the box, hidden by the housing's opaque faces, and the shaft comes out from under it.
Verified off the instance matrices: every cone sits at the exact centre of its hood's xz bbox.

**And it went straight through the closed door.** It took the mast's geometric radius —
`bulbY * tan(LAMP_LIGHT.angle) * LAMP_CONE.radiusMul` = **3.11** at the lens height — about an axis
only **1.3** units out from the door cell's centre, so the near side of the shell reached **half a
unit past the wall's inner face** and laid an amber arc on the floor inside the building.

**The first fix was a smaller cone, and it was wrong in a way worth recording.** A radius under 1.22
(the axis, less the shut leaves' `DOOR_T / 2` in the cell's centre plane) does keep the shell clear
of the leaves, and it was defended as the better art too — a 13° downlight against a mast's 36°.
Reported straight back from the game: **the light circle no longer matched the cone.** That is not
taste, it is arithmetic. `LAMP_LIGHT.angle` is shared by the whole pool, so the SpotLight under a
hood still throws the same wide circle a mast does, and a shaft exists to OUTLINE that circle —
`LAMP_CONE.radiusMul` is called "scale on the geometric ground radius to match the lit circle" in
its own comment. Narrowing the shaft left a pencil standing in the middle of its own pool.

**The right fix is HALF a cone, cut vertically.** A mast stands in the open and its shaft is a full
shell; a fitting bolted to a wall has its light cut off flat by the masonry, so the half that would
be inside the building is not built at all. `LightConeOpts` gains `arc` and a per-instance `yaws`,
`CylinderGeometry` already takes `thetaStart`/`thetaLength`, and the wedge is built centred on local
+z (`thetaStart = -arc/2`) then yawed to the outward normal — so no caller has to know how three
numbers its theta, and a full-circle batch keeps its single shared identity rotation and pays
nothing. The flat cut is left OPEN: a face there is a second additive surface lying flat on the
wall, which reads as a bright band up the masonry. Radius goes back to the mast's own formula.

Verified over every vertex of every instance, projected on each one's own outward normal: extent
**[0, 3.106]**. The 0 is exact — nothing is ever on the wall side of the axis plane, at any height
and for any radius. That is a stronger guarantee than the bound it replaces, which held only for one
number.

**Which then moves the shaft ONTO the wall, and that is the same fact read the other way.** The cut
plane passes through the axis, so where the axis stands is where the light is cut off. It began on
the shared lamp point — the LENS PLANE, a whole hood's depth out in the air — and the half-cone pass
put it on the hood's centre line, which still hung the cut 0.3 clear of the masonry. It sits on the
wall face now, `DOOR_LENS_EPS` (0.02) proud of it: that constant and not a new one, because it is
the same job it already does for the lens, a physical gap so two coplanar surfaces cannot z-fight —
`3d-render.md`'s standing note has polygonOffset losing that three times. Half a cone is what makes
it reachable at all: the kept wedge's top spans outward only, so a `topR` disc sitting on the wall
face is still inside the hood, where a full one would have put half of it inside the building.
Measured on every hood: cut plane **−0.02** off the masonry, cone top **y 4.75**, inside the hood's
own 4.5–5.0 band.

**The third report is a hole in `LampShadows` and not in this fitting.** The fake-shadow pass
projects an actor away from any lit `LampPost` in range and **has no occlusion test of any kind** —
it never asks whether a building is between the two. Outdoors that is invisible; in a facility, the
one area kind that is indoors and outdoors at once, it puts a shadow on a room's floor from the mast
on the kerb outside it. The bulkhead lamp only made it impossible to miss, being by construction the
closest outdoor light there can be to an indoor actor. So the fix is not per fixture:
`render.world.IndoorMask` now retains the predicate it was painted from and exposes
`indoorAt(col, row)`, the lamps are split into an indoor and an outdoor list once a frame, and each
actor takes the list its own cell is on. `indoorAt` is false wherever no mask is attached, so a
street, a tunnel and a wilderness put every lamp in one list, every actor reads that list, and
nothing outside a facility changes at all. The partition is **54 of 54 clean**: 27 masts and 8 door
lamps outdoor, 19 ceiling fixtures indoor.

**And the door spill goes entirely, which retires the `look` gate above.** Reported as visible
rectangles on the ground under the lamps. That gate — spill from a GLAZED exterior door, not from
the hangar's solid steel one — fixed the symptom it was aimed at and kept the wrong rule: glazing
was never the question. A doorway now has a hood, a lens, a half cone and a pooled spotlight, so a
flat trapezoid lying under the same lamp is a **second light in the same place**, thrown from a
different height with an unrelated shape. What actually separates a window from a door is that a
window has no fitting at all — it lights the ground by BEING A HOLE, which is precisely what the
quad draws. So the whole door branch collapses to one `door()` call for the lens.

The fake actor-shadow source goes with it. `opening()` put a `LampPost` at the wall CELL CENTRE at
`SPILL_Y` 3.0, which is the right stand-in for a light that IS the aperture and a duplicate of the
hood's own pooled `LampPost` a metre and a half further out and a metre and a half higher. Windows
keep both. Measured on the built glow mesh afterwards: **43 quads at y 0.04, exactly the 43 window
runs, and 7 at y 4.89, exactly the 7 door lenses** — no ground quad at any door cell.

**Verdict: landed.** +1 draw call (the hood mesh), one new 256² texture, no persisted change.

## A corridor is not a room, and had no light at all

Reported from the game, standing in a lab corridor: "completely empty and has no light except
ambient". Not a regression — the fixture pass walks `m.rooms`, which is `area.generatorInfo`'s
`TEMP_BUILDING_ROOM` blocks, and **a corridor is never in one**. So every corridor cell in the
compound had no light source of any kind and rendered at the flat `IndoorMask` ambient and nothing
else. Counted off the saved grid: **279 `TILE_FLOOR_LINO` cells against 384 of room tile and 88 of
hangar concrete — 37% of a 751-cell interior floor**, holding **0 of the 12 fittings**.

**That count was first written up as 405 and "more than half", and it was wrong**: the sum had swept
in `TILE_FLOOR_CONCRETE` (88), `TILE_FLOOR_TILE_UNWALKABLE` (29) and `TILE_HANGAR_DOOR` (9) — three
ids that neighbour `TILE_FLOOR_LINO` (116) in the 112–120 block and are not corridor. **Read a tile
histogram by NAME, never by summing an id range.** The conclusion did not move — 0 fittings is 0
whatever the denominator — but the denominator is the whole argument for the pass's priority.

Standing inside, `ROOF_FADE` 0.0 drops the fading deck to nothing, so a corridor reads as
`rim 2u | floor 8u | rim 2u` and a pooled spotlight lands straight on the floor. **The first write-up
also said "with both wall faces edge-on", and that generalised from ONE corridor**: the rig rests at
yaw 180, so a run's walls are edge-on one way and broadside the other — measured across this
compound, **120 of 243 corridor wall faces (49.4%) face the resting camera.**

**Corridors are scanned, not listed, because a corridor has no rect.** It is an L, a T and a ring as
often as it is a straight length, so the object a run-finder would deal in does not exist. The pass
is row-major greedy against a spacing test — take the first cell far enough from everything already
placed — which covers any of those shapes and reads only the saved grid, so it is deterministic with
no seed and no `Math.random`. Measured: **18 fixtures, minimum pair spacing exactly 6.00 cells,
18/18 standing on lino.**

**`Surf.LINO` IS ALSO EVERY DOOR CELL, and that is the trap.** An exterior doorway finalises to plain
corridor lino, so a scan on the surface alone hangs a fitting in the front door. Two predicates that
already exist settle it: `isInterior` throws out the exterior doors (one of their four neighbours is
the lot — the same test the indoor mask needed) and `isDoor` throws out the interior ones, a doorway
being circulation, which is the call `FacilityGeom` already makes when it paints a reveal in the
corridor's own texture whichever way the door faces.

**A fixture goes over the middle of the PASSAGE, not over the cell the scan reached first** — on a
two-wide corridor that is the same side of it every time. The two runs of corridor floor through the
cell are its width and its length; the SHORTER is the cross-section and the fixture takes its
midpoint, while the longer is what the spacing test already deals with. `col`/`row` stay the accepted
cell: that pair is what `LampLights` sorts the pool on and what `IndoorMask.indoorAt` reads to keep
the lamp out of the outdoor fake-shadow list. Verified in the live scene — a corridor light sits on a
cell BOUNDARY (world/CELL lands on an integer) where a room light sits on a cell centre (.5).

**Rooms had the same bug one size up: one bulb per room whatever its area.** The two big labs (9x10
and 10x8) and the hangar (11x8) ran on a single fitting each — a fixture per building, not per room.
Now `ceil(w / ROOM_SPACING) x ceil(h / ROOM_SPACING)` on a centred lattice, the `(i + 0.5) / n` form
the park line already uses. `ROOM_SPACING` 6 is a CEILING on the gap, not the gap: **12 rooms yield
30 fittings** and a small room is unchanged at one. `lit` is asked per lattice point and not only at
the room centre, because away from the centre a point can land on a divider the rect does not know
about.

**`CORR_MUL` is derived and not a second fitted number.** `CEIL_MUL` 3.3 is `1 / INDOOR.direct`
rather than a taste value, so the corridor is written as `CEIL_MUL * CORR_DIM` (0.7) and follows any
future move of `INDOOR.direct` instead of going stale against the old one. Measured on the live
spotlights: rooms **148.5**, corridors **103.95**, i.e. 3.3 and 2.31 on the shared base 45.

**Verdict: landed, and it is FREE.** 48 candidate bulbs became **84** (29 masts + 30 room + 18
corridor + 7 door) and `lit` is still **12**: `LAMP_LIGHT.pool` has been built at full size — and so
has been in every lit material's program key and per-fragment light loop — since facility Phase 0
with no bulbs handed to it, so more candidates only change which 12 win. The walked pose measured
**86 calls / 80 programs** against a pre-change **88 / 82**; neither went up, and per-frame cost is
still one `LampLights.update`. No geometry, no new art, nothing persisted — the corridor pass reads
the saved cell grid and needs no `generatorInfo`, so it works on every existing save.

Killed an invariant in `docs/debug-surface.md` on the way: **`ceilings` no longer equals `rooms`**,
and `__facility()` gains `corridors`.

## The facility gets the contact shadows the tunnels have had all along

> SUPERSEDED by "A contact shadow is a FIELD, not a set of quads" — the strips shipped visibly
> broken and the whole instanced-quad approach was replaced. Kept because the failure is the entry.

Phase 1 of dressing the interiors. Standing inside, `ROOF_FADE` 0.0 drops the deck to nothing, so an
interior reads as the roof rim, the floor, and the rim again — the floor is the whole canvas at the
gameplay pitch, and it met its own walls at a bare value step (lino mean **77.29** against the rim's
bitumen **45.65**) with nothing grounding it. The corridor read as a ribbon laid on top of the
building rather than inside it. `render.sewer.SewerDetail` has had the fix since the sewers landed,
and it is itself `render.world.roofs.RoofShadows` with the outline derivation deleted; the facility
has a cell grid too, so the sewer's shape is the one to copy.

New `render.facility.FacilityDetail`, called from `FacilityArea.build` after the benches. One
`InstancedMesh` of **681 strips** over a shared `PlaneGeometry(1,1)`, black `MeshBasicMaterial` with
`Textures.makeShadowGradient()` as its `alphaMap` — a runtime canvas, so **zero art and nothing added
to `textures.json`**. `SHADOW_W` 1.1 / `SHADOW_ALPHA` 0.55 / `SHADOW_Y` 0.02, the tunnels' own three.

**A FACILITY WALL IS A SLAB WITH THICKNESS, and that is the whole port.** `FacilityGeom.slab` insets
by `(CELL - thick)/2` on every side the wall line does not carry into, so the masonry face is up to a
unit inside the cell boundary and a strip laid on the boundary floats in mid-floor. Emission
therefore mirrors `FacilityGeom.structure`'s own loop: iterate WALL cells, take `slab()`, and emit
wherever that loop emits a `face()` — which also means a doorway takes no strip from its flanking
piers, `carries` counting a door cell.

**The notch faces take the OPPOSITE edge**, and getting this backwards puts the strip inside the
masonry. A notch is the corner square the slab BOX holds that the masonry does not; it is FLOOR
belonging to the diagonal cell, so its face plane is the edge of the floor, not of the wall. The two
calls are written to mirror `structure()`'s own pair of `butt()` calls argument for argument.

**Three things from the sewer deliberately did not come across.** The `capY`/`CAP_CHAMFER` taper
(a sewer wall top sags per lattice point; the facility's is a flat `WALL_H`, so it collapses to a
constant). `SewerModel.isFloor`. And the `dr < 0` skip — that drops the one face a sewer's FIXED
camera backface-culls in every pose, while the facility rig rests at yaw 180 but carries a walkway
side-angle and a hold-RMB orbit, so **copying it would have silently deleted half the corner strips.**

**GRID-CELL SAMPLING CANNOT VERIFY THIS PASS, and two attempts died on it before a third worked.**
A wall cell's own footprint CONTAINS floor — the leftover `floorStrips` hands to the neighbour — so
sampling the cell a strip's centre falls in reports the WALL cell, and an exterior wall is
`indoorAt == false` by construction (298 false positives). Probing outward from the strip does not
escape either: a window slab is `GLASS_T` 1.0 in a 4.0 cell, so a probe 1.3 units off the face is
still inside the window cell and reads back tile ids 36-41 (341 false positives). The test that
actually works is containment: **681 of 681 strips fall inside a structure's grown bbox, 0 outdoors.**

**Verdict: landed. +1 draw call** — measured interleaved A/B/A/B on one pinned pose, 77/77 hidden
against 78/78 shown — and **+1 program** (80 → 81) for the material. Zero art, nothing persisted.
The sewer's RADIAL set and its vertical corner strips are deliberately NOT built: the notch pass
already reaches the facility's version of that diagonal nook, and a vertical strip lands on wall
faces, of which only ~half face the camera at any moment. Both can be added to this same batch later.

## A contact shadow is a FIELD, not a set of quads

Reported from the game one build after the entry above: "wall corner shadow is just missing producing
a visible line", and the same beside doors. Both true, and both symptoms of something worse. Measured
by counting how many strips covered each sample point along ONE STRAIGHT RUN of wall:

```
111...1111211132     <- gaps AND 1/2/3 stacks, in a single straight run
```

**The band was discontinuous everywhere, not just at corners and doors.** `FacilityGeom.slab` insets
by `(CELL - thick)/2` on every side the wall line does not carry into, so per-cell strips GAP at every
inset and DOUBLE or TRIPLE at every notch. A quad's alpha is uniform along its run, so every one of
those count changes is a hard edge. Corners and doorways were only where it showed first.

**The slab fact was already written down and half-applied.** The superseded entry names it as "the
whole port" and uses it to PLACE each strip correctly — and misses that the same insets destroy the
strips' CONTINUITY. `SewerDetail` and `RoofShadows` get away with per-face quads because a sewer wall
face IS the cell boundary and a parapet span is derived as a run; neither has a slab.

**So it is a blurred field instead** — `render.world.ContactMask`, the third member of a family this
repo already had two of. A canvas of the masonry footprint, gaussian-blurred, sampled by world XZ and
multiplied into `irradiance` and `reflectedLight.direct*`. A field has no tiles to fail to meet, so
corners, doorways, slab insets, notches, T-junctions and the hangar all fall out of one blur with
nothing written for any of them. `FacilityDetail` drops from an emitter to 50 lines that return
rectangles: **401 slab boxes as solid, notches punched back out as holes** (a wall cell is the union
of its runs, never its box), and door cells skipped — no masonry at floor level, so the band fades
into an opening over the blur width with no code for it.

**IT SHIPPED ONCE MORE BROKEN, AND THE SECOND FAILURE IS WORTH MORE THAN THE FIRST.** The first
version scaled `irradiance` at `<lights_fragment_end>`, reasoning only about `IndoorMask`. Reported
from the game as **holes in the LOS shadow** — and the cause is that `VisionMask` does not DARKEN a
hidden surface, it **mixes it toward the fog colour** (`VisionMask.hx:642-644`, and its own header
says why: so the hidden region "adds no new silhouette to the frame"). Any term applied upstream of
that mix therefore survives into the veil at the floor weight — `MASK.hidden` **0.14** — so the wall
footprint printed through as blotches at roughly 6% modulation, putting structure into the one region
whose whole job is to have none. It was also shading floor the player cannot see.

**So the rule is: anything that must not be seen through the mask is applied AT OR AFTER
`<fog_fragment>`, keyed on the mask.** `ContactMask` now multiplies `gl_FragColor.rgb` there.

**The key is `visMaskRaw`, NOT `visAmt`.** `visAmt` is floored at `visMaskFloor` and bottoms out at
0.14, so gating on it would have left 14% of the same artefact. `VisionMask` now publishes the raw
pre-floor blend as a fragment global — declared unconditionally so it is a contract a downstream
patcher can rely on rather than something it must detect. Measured live: **`visMaskRaw` is exactly
1.0 on a visible cell and exactly 0 on a hidden one.**

**Ordering is bought by the NESTING, not by the anchor.** Both hooks replace `<fog_fragment>` with
itself plus their code, so whoever patches FIRST lands LAST in `main()` — `addFloor` is therefore
`VisionMask.patch(ContactMask.patch(mat))`, and swapping it makes the shader read an unassigned
global. Note `VisionMask.patch` itself calls `IndoorMask.patch` on the way out, so one line there
reaches every world surface.

Profile measured across a wall afterwards, in cell coordinates (masonry spans 30.25-30.75): peak
mask 215 mid-slab, **~40% darkening at the masonry edge**, ramp dying to 0 by 31.15 — about **1.6
world units** of visible falloff, against the quad version's `SHADOW_W` 1.1. Peak is 215 and not 255
because a 2-unit wall is only 12 texels against a 4.2-texel blur, so a thin wall occludes less than a
thick one, which is the right way round.

Only the three interior FLOORS take the patch, through a new `FacilityGeom.addFloor` rather than a
sixth argument to `add`: a WALL cannot take it at all, the mask being top-down, so every fragment of
a 6-unit face would sample the same xz and the column would darken by one flat amount.

**Verdict: landed, and it GIVES BACK the draw call.** 77 calls against the strip version's 78 and the
pre-phase 77 — the quad mesh is gone and nothing replaces it. 81 programs, unchanged from the strips
(one key either way, `contact` instead of a new material). Warmed in `FacilityWarm` beside the indoor
mask, or the floors would compile on the frame the player walks in. Zero art both ways. `px` 24 and
not `IndoorMask`'s 8: that mask only has to land a step in the right place, this one is a ramp the eye
reads directly as shading, and at 8 it quantises into bands.

## The vision mask reveals a CELL, and a facility wall is half a cell (2026-09-03)

Reported from the game as **wide strips of undarkened floor outside the room before the LOS shadow
starts**, and it is not the contact pass at all — it predates the whole phase and would have been
there since `VisionMask` reached the facility.

`VisionMask.polygon` reveals the blocker cell a ray stopped on as a WHOLE SQUARE, and its LOS segments
sit on cell boundaries. That held for as long as the only blockers were the tunnels' — `SewerGeom`
fills a solid cell corner to corner, so the cell IS the masonry. **A facility wall is the first blocker
in the game thinner than the cell the mask grids it on**: `FacilityGeom.slab` centres `WALL_T = CELL/2`
and insets each side the wall line does not carry into, so **a quarter of every wall cell is open
floor, on each open side** — and the far one is floor behind the wall.

Measured on a corridor scanline (cell coords, masonry face at 27.25), before: mask **50% at 27.001,
10% at 26.835** — a full world unit of near-white floor past the face, dying only 1.66 units out. The
contact field is no help there, reading 9% at 1 unit and 2% at 1.5, so it is lit floor with no shading
on it sitting between the wall and the shadow.

Fix is `VisionMaskOpts.blockerInset`, in cells, **derived and not tuned**: `(CELL - WALL_T)/2 / CELL` =
0.25, i.e. `slab`'s own inset. Tunnels and wilderness stay 0 and `inset()` early-outs on that, so
neither compiles a behaviour change. `IndoorMask` hit the identical cell-vs-slab mismatch from the
other side and bought its way out with `IndoorMaskOpts.grow`; this is that correction for the reveal.

**TWO predicates, and each half was found the hard way.**

**It is keyed on `carries` (wall‖door), NOT on the mask's own `solid`.** They differ at exactly the
cells that matter: a door and a window are see-through so neither is ever a blocker, but the wall line
RUNS ON through both and `slab` does not inset toward them. Asking `solid` pulls the reveal off masonry
that is really there and cuts a dark notch into a lit wall at every doorway and window jamb — the same
artefact, moved a cell along. So `attach` takes an optional second predicate; only the facility passes
one.

**And never the face the sweep CAME IN THROUGH — the first half shipped alone and broke the near side.**
A wall cell has open floor on BOTH sides and only the far one is hidden; the near one is the floor the
player is standing on, and the polygon covers it only as far as the CELL boundary. Insetting that side
too left the strip between masonry face and cell edge painted by neither: measured **91 of 255** where
the two should have met at 255 — a dark band a unit wide at the foot of every wall, i.e. the reported
bug inverted. The entry face is recovered from the ray's own hit against the cell bounds (`FACE_EPS`,
segments are axis-aligned on integers) and accumulated over every ray into `sideAt`, not taken from the
first — a corner pier is looked at from two sides at once.

**Verdict: landed, +0 draw calls and +0 programs** — the mask adds no geometry, no material and no
program permutation, so this cannot move either by construction. Three faces measured after, in cell
coords: **50% crossing at 27.251, 34.749 and 30.749 against masonry faces at 27.25, 34.75 and 30.75.**
Full-lit overhang **1.0 world unit → 0**; total skirt **1.66 → 0.66 units**, which is `blur` 0.5 and
nothing else. Along the wall through both jambs of a real door the profile is flat at **240** with no
notch. `fadeCell`'s ramps stay measured over the whole cell — a side that FADES fades into a blocker,
so the wall line carries on through it and its inset is 0 — which is what keeps a run's ramp meeting
its neighbour's across the shared edge.

The green (blocker) channel is deliberately left whole-cell. It gates the wobble, and the boundary it
now wobbles is the per-cell reveal edge sitting on the masonry face, which is exactly the edge that
wanted breaking up.

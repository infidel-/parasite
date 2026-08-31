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

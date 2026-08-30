# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-08c.md` and its predecessors.

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

# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-11.md` and its predecessors.

## Cult base: the other ten organs as Meshy 6 cuts (`ObjModel.turns` for the spine turret)

**Changed:** the remaining organs (flesh block, rat nest, crusher, garbage heap, body storage, cauldron,
rib wall, rib gate, spine turret, blood trap) went through the Cor's route. Each source was keyed off
its grey backdrop, re-laid on black and lifted to subject p50 72 (`ref_black.py`), then sent to
`meshy_image_to_3d` with poly_count 100k. That cost $8 for 10 runs, all fired in parallel and all
done in ~10 min. Each run is labelled `cult/base-<name>` in `art/models.json`: the 2x2 organs are cut
to 20,000 tris and the 1x1 ones to 8,000 (a quarter of the screen area), all at tex 1024, error 0.05,
roughness 0.3 and baseColor 0.7 (the rib gate at 0.55).
`ObjModels.cultOrgan()` builds each row: FRONTAL, the Cor's sheen-only `anim`, and for 2x2 organs the
Cor's swell + twist + billow plus `off` [2,2]. The 1x1 bone pieces and the puddle hold still. Their
`_part` keys join the Cor's skip row.

Numbers:
- Meshy returned 790k–1.98M tris per model, each 1 mesh (it ignores poly_count, as with the Cor).
  Albedo luminance was 76–86, against the Cor's 79. Outliers: the rib gate at 103 (bone-heavy, hence
  baseColor 0.55) and the blood trap at 62.
- Heights come from the Cor's ratio of model width to atlas width (8.4 world per 120 px), capped at
  the Cor's 6.2: flesh block 4.3, rat nest 5.8, crusher 5.9, garbage heap 4.8, body storage 6.2
  (capped from 7.9), cauldron 5.1, rib wall 2.6, rib gate 3.2, turret 2.4, trap 1.6.
- Built glbs are 2.8–3.7 MB each.

Traps:
- The body storage's pale hanging bodies sit within 30 of the grey backdrop, so the default key
  (30/50) half-erased them to dark grey. That source keys at 12/18 instead.
- Meshy baked green specks (5.7% of the crusher sheet, mostly in the maw) that the drawing never had.
  `texSrc` is that sheet with hue 60..200 recoloured to dark flesh red at the same luminance.
- The spine turret faces one of four ways. `getModelKey` appends the direction, and one row carries
  `turns` [π, π/2, 0, -π/2], indexed like its keys and added to the yaw in `build()`: one batch for
  all four facings. The Meshy barrel faces +Z (south, toward the camera). Live check: north shows its
  back, east and west point sideways.
- Organs built mid-area appear at once: `buildSelected` → handover rebuild, no reload needed.

**Verdict:** landed. Every organ reads off its drawing. The scale-by-atlas-width rule held live with
no per-organ refit.

## Cult base Cor Nefandum: re-cut by Meshy off `cor-nefandum-3`

**Changed:** after the other ten organs landed, the Cor read different from them. Its drawing
(`cor-nefandum.png`) is plain smooth skin lobes, while the ten are drawn busy. The ref prep was not
the cause: the first Cor ref and the garbage heap ref both measured subject p50 72/71, on black at
1254². The sibling drawing `cor-nefandum-3.png` has the same silhouette, plus veins, cartilage webs
round the eye and maw, and paler skin. One Meshy run ($0.80) off it, keyed and lifted the same way
(p50 75 → 72), now feeds `cult/base-cor-nefandum`. The label keeps its 20k tris, tex 1024, roughness
0.3 and baseColor 0.7. The first cut stays in models-src as `cult-base-cor-nefandum-meshy.glb`.

Numbers:
- Meshy returned 1,103,334 tris in 1 mesh (asked 100k), cut to 20,000 at 52 texels/tri. The glb is
  3.5 MB, dims 8.62 x 7.71 x 6.2 (was 8.35 x 8.05).
- Eye emissive: `--box=-0.13,0.17,-0.14,0.21,0.2,0.9 --key warm --keylo 0.3 --modulate --tint ff0000`
  keeps 188 tris with bleed 0.
- Rebuilding with the map changed no positions or UVs (diffed against the build without it), so a
  mask cut on the first build holds.

Traps:
- This drawing's eye is painted dark red, not lit. The modulated marker came out at R p50 112, against
  192 on the first cut, which would dim the `PropLamps` glow. The lit texels are scaled by 1.71 after
  the bake (no gain flag in `emissive.py`).
- The halo quad's old y 0.63 / z 0.42 sat on the eye's lower rim. The new eye sits at 0.505 h up and
  0.236 h proud (area-weighted centroid of the keyed tris; the box mean said 0.515 / 0.24). The game
  camera pitches 65°, but its ray to an organ 3 rows north slopes ~52° (perspective), so a quad dz
  nearer must rise dz × 1.27. z 0.37 (the body front in reach is 0.316 h) → y 0.675. Fitted live by
  patching `ObjModels.MODELS` rows in memory: `drawCore` reads `core.y`/`z` every frame.

**Verdict:** landed. The Cor now matches the other ten organs' detail level, and the halo sits on the
eye at both the game camera and a close 53° view.

## Cult base organs: a faint heartbeat (`PropFlesh`), the rat nest sunk into the floor

**Changed:** variant A of the flesh-shader bake-off now ships as a new `flesh` column on `ObjModel`,
consumed by `PropGlow` (same hook chain, key suffix `F`, warmed through `patchRow`). Two keys of the
prop's own linear albedo, max'd: a crevice key (luminance 0.012..0.035 falling × redness R/(G+B)
1.3..2.2) and a vein key (darkness against the base map sampled at mip bias 3, 0.35..0.65, × redness
1.2..2.0). They glow 0xff1030 on a lub-dub beat whose phase is the distance from a core (0.8 cycles per
height), so it travels outward. The Cor's core is its eye (0.505 h, 0.236 h proud); the others sit
0.55 h up the axis. It runs on the Cor, flesh block, garbage heap and cauldron at glow 0.04, and on the
crusher and body storage at 0.02 (their whole red interior keys). There is none on the rib wall, rib
gate, spine turret or blood trap, and none on the rat nest. The existing sheen and breath are unchanged.
B, C and D are kept with their GLSL and knobs in `docs/flesh-shaders.md`.
The rat nest: Meshy stood its pit up as a funnel on a narrow stalk, 5.8 tall. At `sink` 0.38 the stalk
is under the floor (the skirt's widest ring is at 0.35–0.40 h). The bone ring, the skull and the mouth
stand around a dark hole at floor level.

Numbers:
- Glow 0.25 in the game flashed saturated red over every root (the R channel of a close shot swung
  up to 250 between frames). At 0.04 it is a faint red tide through the crevices on the beat.
- Rate 0.35 is ~2.7 s per beat (the harness's 0.63 was 1.5 s); base 0.004.
- Cost: frag ~40 ALU plus 1 extra tap of the base map. 132 programs after entry (133 before), and no
  compile at area entry.

Traps:
- PropGlow's fragment blocks are concatenated, and the lamp block opens with `#ifdef`. A block ending
  `}` with no newline puts the directive mid-line, the fragment shader fails to compile, and the Cor
  drew only its halo. The new block ends `}\n`.
- Tuned live without rebuilds: `renderer.properties.get(mat).uniforms.propFleshBeat` is the same
  `{ value }` object the hook registered, so writing `.value` retunes the drawn frame.

**Verdict:** landed. The harness's emissive levels do not transfer: cut them ~15x for these bodies.

## Cult rat nest: a real hole through the floor (`ObjModel.hole`, a discard on the sewer floor)

**Changed:** the sunk rat nest stood over solid floor, which painted over its funnel below the floor
line. A new optional row column `hole` [x, z, rx, rz] (fractions of `h` off the placement) is filled
by `ObjModels.build` into `ObjModels.floorHoles`, 4 world-xz ellipse slots shared by identity. The
sewer/habitat floor material (`SewerGeom.holed`, hooked before `VisionMask.patch`, key `floorHole`)
discards fragments inside any of them. The rat nest also lost its pulse and billow: a hole does not
breathe, and a swelling wall would cross the hole's edge. Only the sheen is left.

Numbers:
- The funnel's cross-section at the floor line (0.38 h), sliced off the built mesh, spans x -0.26..0.26
  and z -0.17..0.57 h, with a narrow front lobe. The ellipse is centred at z +0.092. Fitted just inside
  the walls (rx 0.176, rz 0.2), a grey crescent of floor still showed round the funnel; +30%, then
  +10% three times more (by eye, live) gives rx 0.305, rz 0.347 (world 1.77 x 2.01), past the walls.
- 131 programs after entry, and the warm went 122 → 123 (the patched floor through
  `SewerModel.demo()`). No compile at entry.

Traps:
- Inserting a function above `add` split `add` from its own header comment; it was moved back.
- The ellipse's axes stay world-aligned (ponytail): right for FRONTAL rows. A turned row would also
  need the axes rotated.

**Verdict:** landed. Through the bone ring you see the ribbed funnel down to a black bottom, with no
floor ring and no gap at the edge.

## Cult blood trap: twitching fingers; Cadaverum holds still

**Changed:** the blood trap (a 1x1 organ, held still until now) takes the existing `anim` sway
(`ObjModels.bloodTrap`): amp 0.05, bend 3.0, rate 0.45, strand 4.0, plus the sheen it already had,
FRONT-BACK only: a new optional `PropAnim.swayX` (uniform `propSwayX`, default 1) scales the sway's
local-X half, and the trap takes 0, so on a FRONTAL row it rocks toward and away from the camera. The
body storage (Cadaverum, `ObjModels.bodyStorage`) lost its pulse, its billow and its heartbeat glow
(was 0.02); only the sheen is left. Two row helpers beside `ratNest()`.

Numbers:
- The trap's height profile off the built glb: the puddle fills 0..0.2 h (75% of the verts), the hands
  rise 0.2..1.0 h and spread x ±1.0 h. Weight y^3 gives the puddle 0.008 and the wrists (~0.35) 0.04,
  so only the fingers (0.7..1 h) carry the motion. At h 1.6, a fingertip moves ~0.08 world units.
- Strand 4 cycles per height across x+z: neighbouring hands sit ~1 h apart (a full cycle each way)
  and adjacent fingers ~0.1 h apart (~0.4 cycle), so no two curl together.
- Rate 0.45 ≈ 2.1 s a sway, faster than the organs' breath (5.2 s).
- Live, two frames of the habitat camera: 289 px changed in the trap's crop with the full sway, 105
  with front-back only (depth foreshortens under the ~52° camera), all on the pale fingertips; the
  puddle diffed clean. The warm stayed at 123 programs, with 0 compiles at entry.

**Verdict:** landed. The sway's power-of-height weight is a finger gate for free on a prop whose only
tall parts are fingers.

## Forma footprint ghost

**Changed:** `Badges.drawFormaCursor` drew one reticle on the cursor cell. It now paints one flat
self-lit quad per footprint cell first (`FormaHud.anchorCells()` + `FormaHud.verdict()`, so the
colour comes from the same refusal functions as the chip). The quads are painted through the existing
`sprites.paint` flat path, with cached svg textures, at orders `ORD_MARK - 0.2/-0.1`:
- a valid footprint is a 3px bone outline (`#e9dfc8`);
- a refused one is an alert red outline with a hatch (`#f26a6a`);
- the organ you would tend is a pink outline (`#fd97ff`);
- a picked spine turret adds an arrow above the reticle (`ORD_MARK + 0.1`, quad 1.6 cells) in its
  direction.

Numbers (topbar `dc`, habitat cult base, slot 9, tactical camera): 1x1 tool 64, 2x2 tool 67, tend 64.
That is one call per quad (1-4 cells, plus the arrow and the reticle) and only while Forma is open.

Trap:
- A translucent fill on the self-lit quad reads far above its texture alpha: fill .16, then .08,
  both showed as ~40 % beige slabs over the dark floor. The ghost went outline-only (fill 0), and only
  the refused cells keep a pattern.

**Verdict:** landed. Footprint and refusal now read on the floor itself; translucent fills on the
self-lit mark quads don't work, so use outlines.

## Broken cult organs: a procedural ruin

**Changed:** a broken cult base organ was its intact prop with a red X badge. Now
`BaseOrganObject.getModelKey` appends `_broken` to a broken organ's anchor key, and
`ObjModels.withRuins` adds a twin row for every placing `cult_` row: the same glb, footprint, `off`,
`turns` and `hole`, with `squash` 0.55 (a new `PropPlace.squash`, a Y-only scale about the base in
`Models.instanced`) and `sink` = `sink × 0.55 + 0.04`. Every motion, glow, core and light column is
null. `ruin: true` makes the solid batch a `DEAD` clone (`ObjModels.solidVariant`, used by build and
the sewer, cave and facility warms), and `patchRuin` chains onto solid and ghost: albedo mixed 0.35
toward its luminance, ×0.5, emissive zeroed. `CultBase.refresh3D` rebuilds the props on break, repair,
upgrade and turn. `render.sewer.CultDetail` draws one ruin quad per broken organ from the
`cult/ruin-decals` PACK16 (cell = `RUIN_CELLS.indexOf(type)`), over the rims, fading in over 2 BASE_MS
from the break and dropped on repair.

Numbers (habitat base, all 10 non-heart organs broken):
- The topbar program count stayed at 135 through the break, so the warm covers it. The ruin mesh is
  +1 call (10 quads).
- The sheet came back at 0.0369 linear. At 1.25 footprints, hiding the ruin mesh changed only 8,025 px:
  the prop covers most of a decal sized near its footprint, and the dark art vanishes on the habitat
  floor. Lift 0.7 (0.0844, between the rim's 0.0506 and the splotches' 0.104) and 1.8 footprints (the
  rim's 1.85) make it read as grey patches out from under the heaps.
- Repair restores the tall red prop and drops its ruin decal. The turret prop follows its direction
  on a turn.

Traps:
- The broken ribwall, ribgate and blood trap are walkable, so the player's ghost fades their props.
  The ghost has to be ruined too, which is why the look is a patch on both batches rather than a
  variant on the solid alone.
- The SOLID batch shares the glb template's material, and every patch early-outs on its own mark. A
  ruin row patching SOLID directly would have inherited the intact row's heartbeat, or put its own
  look on the intact row. The DEAD clone carries no hooks.
- pack16.py's first pass pasted at 1.149 (an upscale). `--margin 34` brought it to 1.0.

**Verdict:** landed. One shader patch and one sheet give eleven ruins with no new models. A floor
decal under a prop has to be sized like the flesh rim, not like the prop.

## Cult organ destroy / repair / upgrade animations

`render.particles.OrganFx3D`, a `Particle3D` on the actor layer's list (no new frame hook), started by
`CultBase.fx3D` through `GameScene.organFx` → `View` → `Actors`. It POSES the organ's own prop
instance: every batch on its anchor cell (`ObjModels.placedAt`), solid, ghost and hull, rewritten each
frame from a captured base matrix and restored in `onDeath`; `Models.cull` repacks `matrices[i]` every
frame, so a write there is all it takes. Beats in BASE_MS (150 ms): destroy 8 (shudder 3 with a
0.03-cell jitter, slump 3 to `RUIN_SQUASH` spreading 8 %, settle 2, a 14-drop `BloodDrop3D.burst` and a
dark red `glowQuad` as it gives way); repair 7 (ease-out-back 0.55 → 1, 8 flesh-pink sinew streaks
spiralling in over 4, then a glow); mend = the sinews alone; upgrade 6 (one 15 % swell, crown glow, a
20-ember ring growing 1.5 cells past the footprint). `CultDetail` fades a mended organ's ruin out by
running its grow backwards: start at the end, negative duration, so `cultFade` goes 1 → 0 with no
shader change.

Traps:
- The matrices bake the glb's RECENTRE offset in, so `M · S` scales about the wrong point. Scale in
  world about the base: `T(b) · S · T(-b) · M`, b = placement centre x/z and `floor - sink * h`; S is
  axis-aligned and commutes with the yaw.
- A destroy must not rebuild at the break or the ruin (DEAD material) pops in before the slump. It
  holds the intact model and calls `updateObjects3D` from `onDeath`; a rebuild that lands early (a
  second break) skips `ruin` rows so it never squashes a ruin twice.
- A flat lit ring sprite at floor + 0.03 / 0.12 was swallowed by the raised flesh floor and the
  dark (fragments only); additive `Sparks.streak` dashes read at once. Use additive for floor FX here.
- `ANIM_SPEED` 0.1 to catch frames also slows the model cross-fade (handOver), so a repair's first
  frames look empty at that speed only.

Verdict: landed. Verified live at ANIM_SPEED 0.1-0.12 on the crusher (destroy, repair) and the heart
(upgrade); 64 quick runs green; no new programs (pooled sprite/spark quads).


## Metamorphosis II ritual stage animation

`render.particles.RitualFx3D`, a `Particle3D` on the actor layer's list, started by
`MetamorphosisPhaseII.channel` through `GameScene.ritualFx` → `View` → `Actors` at the player's cell.
Its `onDeath` opens the stage's vision, and with no 3D view running `GameScene` calls that callback at
once (headless tests). One stage is 14 BASE_MS (2.1 s): 16 + 8 × stage cult-pink sinew streaks spiral
in from 1.5 + 0.5 × stage cells and climb over 7. A 4-glow column rises from 0.6 of that and beats
(orange `0xff8a3a` on the third stage, cult pink before). A 36-ember additive ring spreads to 2.5 +
0.5 × stage cells over the last 6. The third stage also throws an 18-drop `BloodDrop3D.burst` as the
sinews meet. Each stage quakes the camera as the sinews meet, at 0.2 × stage of the full
`RenderConfig.QUAKE` (`CameraRig.quake(mul)`, new strength argument).

Traps:
- The first cut (8 + 4 × stage sinews, width 0.06 cell, reach 1 cell per stage) read as a few stray
  dashes at the screen edge. It needed denser, thicker sinews with a closer reach, and a fade-in so
  they don't pop at full radius.
- Sinews behind habitat walls are depth-occluded, so a spiral next to a wall looks lopsided. It is
  still readable, so this was left alone.
- To catch frames, set `RenderConfig.ANIM_SPEED` to 0.06 and take CDP screenshots about 6 s apart;
  reset it to 1 afterwards.

Verdict: landed. Verified live at ANIM_SPEED 0.06–0.15 in the base habitat (stages 2 and 3), and the
stage-1 vision opened after the animation at full speed. No new programs (pooled spark quads).

## Cor Nefandum birth animation

`OrganFxKind.BIRTH` in `render.particles.OrganFx3D`, played by `CultBase.birth` once the last
Metamorphosis II vision is endured. Over 9 BASE_MS the heart's prop is scaled up from nothing with an
ease-out-back on height (overshoots, then settles) while its width swells from 0.3. REPAIR's sinews
and glow come with it, and a full-strength camera quake starts it. `OrganFx3D` now takes an `onDone`
(`GameScene.organFx` calls it at once with no 3D view), and the base's message waits for it.

Traps:
- The heart was INVISIBLE after the ritual. This was not the biomineral growths: its object is made
  inside the `CultBase` constructor, before `cult.base` points at the base, so
  `BaseOrganObject.getModelKey` found no organ and returned `base_organ`. That has no prop, so
  `AreaGame.addObject` skipped the 3D rebuild. Re-entering the area would have fixed it, so it looked
  random. `birth` forces the rebuild.
- The rise must start after the vision closes: played behind the modal window, it is over before
  anyone sees it.

Verdict: landed. Verified live at ANIM_SPEED 0.12: the heart is absent behind vision 3, rises after
it with sinews and glow, and the message holds until it stands. No new programs.

## University library: a shell kind with seven hand-modelled furniture glbs

`render.library` (`LibraryStyle`, `LibraryArea`), the new `AREA_LIBRARY` reading floor (`gen.library`).
The lab's shape: `FacilityGeom` off a `ShellTex` naming library art, no deck, no parapet, no moon, its own
warm rig (the light pools match every kind's, so no program is compiled for the rig itself). New
`Surf` slots `LIB_HALL/LOBBY/STACKS/ARCHIVE` 32-35, `SURF_SLOTS` 32 → 36; the corridor reuses
`Surf.CARPET` with the library's carpet. Art: two PACK4 sunburst sheets (surfaces: parquet, wainscot,
flagstone, carpet; furniture faces: spines, oak, walnut top, card drawers). Furniture is seven Blender
glbs (`models-src/library/library_build.py`, 108-228 tris, `check` 0/0/1, `texel_off` 0), one instanced
batch each, placed off the furniture tiles; contact shadows through `FacilityDetail.ground`.

Measured live (3050, gameplay camera): 18-30 dc and 19-47k tris across lobby, hall, stacks and archive;
library warm 93 programs, 2.7 s.

Traps:
- **The stairs well is a FIT, not a missing floor.** With the well as `Surf.NONE` the corp stairs glb
  stood turned beside a black hole: `CorpArea.objYaw` finds the end wall through two `FIT_HOLE` cells, so
  the well must be `fitOf → FIT_HOLE` over the lobby's floor surf, and the kind needs the same yaw branch.
- **The packed art came back at 38-44 sRGB** (walnut, spines, wainscot) and every piece read black under
  pendants. `lift` gammas 0.67-0.86 put the wood and spines at ~72, the wall at 69, the carpet at 57; the
  model sheets are re-packed off the lifted labels.
- **A pickup on the lectern stood inside it.** `objLift` returns `LibraryStyle.BOOK_Y` on the lectern cell.
- The ambient fill had to go to 7.5 / hemi 2.4: the 5.0-tall stack ranks shade the 1-cell aisles from the
  ceiling pendants, and the vision mask darkens everything past a rank on top of that.

Verdict: landed. Walked the lobby, a hall, the stacks and the archive live; burn and book spawn checked.

## University library, first feedback pass: footprint shadows, aisle lamps, seamless floors, cushions

Reported in game on the first library: catalogue islands with no gap between their rows, a dark patch
in front of every wall bookcase, long unbroken bookcase runs, pendants hanging over the stack ranks,
a visible repeat on the parquet, chairs that merged with it, and halls that were all tables. Fixed:
- **The dark patch was the contact field, not a shadow.** A wall bookcase laid `FacilityDetail.ground`
  over its whole cell (3.6 square) while the case stands 1.2 deep in the wall's margin, so the floor field
  darkened 2.8 units of open floor in front of it. Now one `ground` per RUN over the cases' own footprint
  (`CASE_D` off the slab face, so the halo still finds its wall). Catalogues likewise take their own
  3.6 x 3.4 footprint, and an island's two rows stand at the FRONT of their cells: a 1.2 passage between.
- **Pendants in the aisles**: a lattice point on a `TILE_LIB_STACK` cell steps into the aisle beside it,
  and a pendant with a rank either side loses its across-the-aisle jitter (`LibraryArea.lamps`).
- **The packed floors did not tile** (the PACK4 wrap bullet in 3d-textures.md, ignored): parquet wrap
  7.6/5.9 and flagstone 6.2/5.1 against interior ~3. A herringbone has no exact period to crop to (the
  quadrant's autocorrelation found none across), so: roll the quadrant half a tile, so the old wrap lies
  across the middle and the new one runs through untouched interior, then a sunburst `mask` edit of a
  160 px cross through the middle. **Composite the band back and the joints ghost** (the edit moved
  flagstone joints just outside the band); the WHOLE edit is the tile: 4.0/3.8 and 3.1/3.1, no visible
  repeat at 2x2. Solo srcs now; lifts refitted to the old built means (67.1, 78.9).
- **The chair** wears the small sheet's new cells: shelf-side at `--gain 0.62` (`tools/modelsheet.py`)
  for the frame and the corridor carpet for a seat cushion sunk 0.02 into the seat (276 tris, check clean).

Verdict: landed. Checked live on a fresh 44x32 floor: the island's passage, no patch in front of the
cases, runs of three with holes, cushions reading red on the parquet, lamp pools down the stack aisles.

## University library, second feedback pass: shelf books, decor slots, wall art, lamps, the Necronomicon

Reported: catalogue lids with board gaps, a blurry counter top, an uneven stone floor, carpet running
into the rooms, close-packed bookcases, one book texture on every shelf, no elder sign glow, a 2D book
on the lectern, and no decoration. Changed:
- **Shell**: door cells are flagged doorways (`LibraryStyle.doorways`, a `DoorCell` with no leaves), so
  `floorStrips` splits the floor at the wall line and the opening takes a lintel. The stone is a solo
  4 x 4 regular flag drop cropped 1 px in (its edge joints came back 4 px against ~6): wrap 3.1, lift 1.13.
- **Furniture**: wall bookcases 3.4 wide in their 4.0 cell, so every case stands apart; the counter and
  table tile the shelves sheet's wood every 5.0 units (`buildlib.grid_cut` + `tile_uv`) instead of one
  crop of a 16-unit sheet (32 texels a unit); the catalogue lid wears the carcass wood; chairs get a
  floor pool and +/-10 degrees of hashed yaw.
- **Books** (`LibraryBooks`): one quad per opening between the boards, 6 per case face, off 16 bands of
  `library/shelf-books` (two sunburst drops of 8 bands between dark dividers, cut and stacked 1024 x 2048)
  at a hashed window and mirror. The glbs' fronts are bare wood now.
- **Decor** (`LibraryDecor`, `LibraryWall`): render-only slots off the cell hash, nothing saved. Table
  and counter tops claim lamps and book stacks first (`ClutterSlot`), then 4-7 cut-outs off two PACK16s;
  rare book stacks on case heads; baskets and book piles in the WALL MARGIN of bare cells (a bookcase
  hole, a lobby wall), walkable like a bookcase; pictures off a filled PACK16 and posters (4 x 2, legible
  slogans) on north/east/west walls with bare floor in front, and posters on free rank ends.
- **Glbs** (`decor_build.py`): banker's lamp 80 tris (shade glows off `emissiveSrc`), basket 124, book
  stack 36, all drawn a size up (lamp 1.8 against its built 1.14: at table scale they read as specks).
  The Necronomicon (36 tris, ObjModels `pickup_necronomicon`) is built lying on the lectern's board, ink
  relit green as its emissive, a 0.3 green PropLight; drawn at 1.2x it stands 0.047 lower.
- **Elder sign**: `Actors.elderSign`, a frontal `glowQuad` on the librarian's chest, breathing.

Measured: hall 23 -> 31-33 dc, 18.2k -> 23.9k tris; warm 93 -> 102 programs, in play 103 (the same
one-program gap as before). Nine sunburst gens, ~$0.50.

Traps:
- **Two drops came back half cut**: desk-books at alpha min 62 (cut at alpha > 225, opened 3x3) and
  wall-art with a glow band crossing a seam (alpha > 230, opened 5x5). `pack16.py --fill` flattens each
  cell over its median, which squares a round clock: `--alpha` keeps the cut, `--cellh` packs tall cells.
- **LibraryArea never patched its object props** (`ObjModels.patchRow`): the stairs drew unmasked.
  Patched in `tick` like the facility, and warmed in its three variants.
- The glow first sat on the face: the bust fills the sprite's lower half, so `SIGN_UP` is -0.37.

Verdict: landed. Checked live in a hall, the lobby and the archive, the book placed on the lectern by hand.

## University library, third feedback pass: one book in six covers, catalogue tops, paper posters, Lovecraft, sign burn

Reported: the book stacks were three boxes sunk into each other with cloth page edges; the lamp too big;
the baskets a bright orange; no decor on the catalogues; propaganda on black grounds; too many rank-end
posters; walkable chairs. Changed:
- **Books**: `decor_build.py book()` builds ONE closed hardback, 0.95 x 1.3 x 0.17, 80 tris: a C-section
  cover (two boards over a half-round spine, 6 segments) extruded along the spine, and a page block set
  0.035 in at head, tail and fore-edge, a hair into both boards and the spine's hollow (check: coplanar 0).
  Built six times, one cover each, off `books-sheet-src.png` (sunburst PACK4: TL page edges, six 256 x 512
  covers with blind borders and gilt bands). The spine wears the cover's left strip by `flat_uv` (height
  round, length along) so the gilt bands wrap it. `LibraryDecor.stack` lays 1-3 books (2-3 on the floor),
  each its own cover glb, turn (+/-0.25) and scale (0.9-1.05), on the one below's thickness + 0.002, so no
  two cut into each other. Six batches, one per cover.
- **Catalogue tops**: a stack on 45%, a lamp on 12%, 0-2 papers, claimed on the turned 3.6 x 3.4 top.
- **Posters** re-rolled on PALE CREAM PAPER, the menace kept in the content. Cut as each cell's bounding
  rectangle off the lane grey: a colour key and an outside flood both holed the charcoal inks touching the
  paper's edge. Built 143.6, lift 1.6 -> 114.9 (the wall art sits at 67.6). Rank-end posters 55% -> 20%.
- **Lovecraft**: wall-art cell 14 (the brass plaque) edited to his portrait and pasted WHOLE into the
  sheet; `tools/patch.py merge` kept the plaque's engraved bands through his face (the diff fell under its
  threshold there). Never dealt from the role lists: 4% of hall/stacks/archive picture slots, once a floor.
- Lamp `LAMP_H` 1.8 -> 1.44; basket `sat` 0.5 + `lift` 1.2 (sampled 130/72/19 chroma 111 -> 97/65/52, 44).
- **Sign burn** (`View.playSignBurn`): `BreakShake` takes a config, `RenderConfig.SIGN_BURN` is a 1 x BASE_MS
  jolt at 0.06 CELL with a 0.8 pale-gold flash; the chest glow (`Actors.elderSign`) swells x1.6 and
  brightens x2, falling back over one BASE_MS.

Measured: lobby 42 dc, 24-27k tris (hall 39 dc); warm still 102 programs (103 in play).

Verdict: landed. Checked live in the hall and the lobby; the burn fired by hand on the host.

## University library, fourth feedback pass: lifted prop light, pulsing Necronomicon, muted paper, shaded lectern

Reported: the Necronomicon glowed on the lowest part of its stand, its glow should pulse, the posters and
the books' paper read too bright, and the lectern was one even wood. Changed:
- **The prop light ignored the second floor.** `PropLights` hung every prop light at `floorY + h * y` and
  never added the area kind's `lift`, which `ObjModels.build` already applied to the mesh: the book stands
  1.975 up on the lectern, so its light sat at 0.35, at the base plate. `ObjModels.lift` keeps the kind's
  lift (null where none was passed) and `PropLights` adds it; light measured at y 2.33 after. The shader
  side of `skipSelf` was already right (it reads the instance matrix, lift included), so the book was
  also being lit by a light it thought was elsewhere.
- **Pulse**: `PropLight.pulse`/`pulseRate` and `ObjModels.lightBeat` (squared sine on `PropGlow.uTime`):
  `PropLights` scales the light by it and `ObjModels.cull` the batch material's `emissiveIntensity`
  (the glb's own strength kept in `userData.ei0`), so the ink and its light throb together. The `lamps`
  column was not used: its beat carries a per-instance shader phase the CPU-side light cannot match.
  Book: pulse 0.75, rate 0.4 rad/BASE_MS (~2.4 s), mul 0.3 -> 0.45 for the lower mean.
- **Posters**: `cells` grid 1 cap 0.12 (a whole-sheet LINEAR scale, which holds the print's contrast where
  a steeper gamma crushes it) + `sat` 0.6: p50 152 -> 99, chroma 61 -> 23.
- **Book paper**: `gradeRect` on the page cell alone (1024 map, rect 0..512 x 0..512), scale 0.3 sat 0.6;
  the source page cell is luma 194 against covers 33-67, covers untouched.
- **Lectern**: COLOR_0 ramp from `LECT_FOOT` 0.45 at the floor to full at 2.0 (`library_build.py`, the
  military shelving's carton shading), exported with `bl.export(colors=True)`.

Verdict: landed. Checked live at the lectern: light over the book, ink bright and dim in two frames.

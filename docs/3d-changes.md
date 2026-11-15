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

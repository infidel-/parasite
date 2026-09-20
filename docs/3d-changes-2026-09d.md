# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-09c.md` and its predecessors.

## The park railing was green, and a `sat` was the whole fix (2026-09-16)

"fence swatch is green, measured RGB 41/51/46" — and the measurement reproduced exactly on the
shipped glb: `facility/fence-park-hand` atlas **41/52/47**, sampled **38/51/46**, chroma **10.8 /
12.4**, green over red by 11. The railing wears one near-uniform 16-texel swatch off the kerbside
pack4's painted steel, and painted steel in that sheet is a PAINT colour, not a zinc one.

THE LEVEL WAS ALREADY RIGHT, which is the same shape as the litter bin's pass 3 one landing earlier:
luma sat inside the 46-52 outdoor family, so nothing wanted darkening and `baseColor` was never a
candidate. A Rec.709 `sat` 0.2 in linear light took chroma to **2.0 / 2.7** at atlas 48/50/49 — still
in the family, because that mix holds luma by construction.

NO NEW ART, AND THE PLANNED SWATCH WAS DROPPED ON PURPOSE. The plan's route was a fresh
`facility/fence-steel` gen with the `sat` as a fallback "worth trying first". Trying it first settled
it: what a zinc gen would add over a neutralised paint is mottling, and the balusters are 0.06 across
— under a texel at any camera this game has, which is why the railing's art was one flat swatch to
begin with. The rhythm is the object; the art does nothing.

THE SHEET IS SHARED WITH THE CABLE REEL AND THE GRADE IS NOT: `sat` bakes into the label's own copy
of the map, so `facility/lot-reel-hand` re-measured at an unchanged 41/52/47 and stays painted steel
in its parking lot.

NOT VERIFIED IN FRAME, and that is the scene's limit rather than an omission. This game is
permanently night and the park is its darkest corner: three pinned free-cam frames on lamp-lit rim
cells came back at mean luma **10**, with the railing either behind a shrub or under a texel of light.
The albedo is the only instrument that reads there — and it is the one the report was written in.

**Verdict: landed. When a prop's luma is already in its family and its hue is not, the knob is `sat`,
and a swatch that does nothing is not worth regenerating.**

## The park's planting goes hand-modelled: 2.37M triangles in a frame become 0.96M (2026-09-16)

> Its SHEET and two of its dimensions were revised the same day — see "The plants' seam was the UV wrap, and the sheet had to be generated to close it". The triangle and draw-call numbers below stand.

The park borrowed the wilderness's own glbs — `wild/tree-conifer` (4,880 tris) and `wild/bush-low`
(4,955, `casts: false` because 163 shrubs were 45% of the park's triangles) — and the report on both
was "more curves". Four hand-modelled replacements behind `FacilityStyle.PLANT_BLENDER`:
**conifer 824** tris, **dome 192**, **upright 372**, **sprawl 372**, all `holes 0 / coplanar 0`.

MEASURED IN ONE PINNED FREE-CAM PARK POSE, flag off then on, same `lookFrom`: **calls 126 → 127**
(+1) and **tris 2,374,665 → 962,695**, i.e. **−1.41M, −59% of the whole frame**. The +1 is the shrub
becoming three batches instead of one, minus a shadow group (`shdw 1/5 → 1/4`). Live counts: 58
conifers, and 169 shrubs dealt **54 / 51 / 64** across the three silhouettes by a hash of the cell —
so one tile id draws three species, the generator writes nothing new and no save migrates.

THE SILHOUETTE IS THE ONE THING ONLY A RENDER CAN JUDGE, and it took three cuts of the conifer,
rendered in Blender against a grey plane because the game is night and the park is black. Cut one:
three long tiers read as A STACK OF FUNNELS, the top ring at 0.10 of its radius gave the tree a FLAT
TOP, and six 0.055-radius swept limbs under the bottom skirt read as SPIDER LEGS. Cut two: five
shorter skirts overlapping by a third, a deeper scallop (0.68 against 0.80), a tip running to 0.02,
no limbs. The shrubs took the same medicine — three crowns at 0.38..0.46 of the half-width rendered
as MUSHROOMS ON STICKS and went to 0.58..0.66, and the sprawler's runners were pulled back inside its
own crown edge for the reason the limbs died.

TWO FAULTS `measure` CAUGHT AND NO EYE WOULD HAVE: the conifer's limbs dropped to **z −0.91**, tips
under the lawn and the piece 8.41 tall against the 7.5 the batch scales to — which walks the whole
footprint, since `Models.instanced` scales by HEIGHT alone. And the scallop on its own phase put a
lobe on +x and a valley on +y, a **0.87 plan aspect** on a tree whose predecessor is round: turning
the section half a step makes both axes reach the same 0.966 of the radius, and the piece now measures
2.5575 × 2.5575 × 7.5, aspect **0.341** on the nose. `sweep`'s root ring is the third: it builds each
ring square to the direction of travel, so a ring centred on the ground plane hangs half of itself
under it (z_min −0.026).

`reps` IS THE WRONG INSTRUMENT ON A SHAPED LATHE and this is the finding worth carrying. `lathe_uv`
picks a face's copy as `floor(min(u) * reps + 0.5)` and clamps what falls outside, which is exact
only when `reps` EQUALS the turn count — at half of it every second face's minimum sits on a copy
boundary, rounds up, and the face's whole u collapses to one line: **32 smeared triangles** on the
sprawler, all with u pinned at 0.502 and v running 0.37..0.50. A scalloped section makes it worse,
because the phase offset moves the boundaries off the face edges. The fix states the same thing with
no arithmetic to get wrong: cut the cell to a BAND whose aspect is the piece's own
(`height / circumference`) and map one copy round. 0 smears on all four.

THREE ROWS AND NOT ONE, EACH WITH ITS OWN `h`. The sprawler's mesh is 0.858 tall and 1.85 across, so
drawing it at the dome's 1.1 would blow it up to 2.37 and push it past the cell boundary the row's
0.28 of jitter already reaches for — the overhang fault this family recorded once before, which was
arithmetic and not art both times.

NO ART WAS GENERATED, which was the gate's answer and turned out to be the right one on its merits.
`models-src/wild/plant-sheet.png` is cut from the OLD REFERENCES: the needle mottle from inside the
conifer reference's cone (rows 560..720, clear of the silhouette edge and its grey backdrop), the
same mottle at two lower levels, and the broadleaf reference's trunk with its one-sided painted
lighting divided out by a 24-px blur (column spread **7.8 → 2.1**, grain std 5.2 kept). The broadleaf
CANOPY was tried first and rejected by measurement: its densest 160-px window is only **42% leaf**, so
a swatch cut from it is mostly backdrop. Each cell is levelled by a flat multiply in linear light to
what the glb it replaces shipped, fitted against the PROP and not the cell — the first pass put the
cells on target and the props came back 17% under (conifer sampled 43 against 52), because a prop
wears three cells and propstat reads their area-weighted average. Second pass: conifer **51/55/50**
against the old **52/56/49**, shrubs 45/48/44 against 42/51/43. No `baseColor`, no `lift`, no `sat`.

**Verdict: landed. The park's own planting was 2.3M triangles a frame and is now 0.96M for +1 draw
call — and every silhouette fault in it was found by RENDERING the mesh, which is the one thing the
game's night cannot show you.**

## The plants' seam was the UV wrap, and the sheet had to be generated to close it (2026-09-16)

"all the trees and bushes have texture seams. just create new textures for them" — and the cause is
`lathe_uv`, not the art. Every part of every plant here is a lathe and u runs **0..1 once around**,
so a cell's LEFT edge column abuts its RIGHT edge column all the way up the seam. The sheet those
four glbs shipped with was crops of the retired TRELLIS references, which tile nowhere: one hard
vertical line down every tree and every shrub, exactly as reported.

**ONE 1k 2x2 GEN, AND THE TILING IS IMPOSED RATHER THAN REQUESTED.** Four tiling quadrants in one
image is something the model cannot check, so `models-src/wild/sheet_build.py` closes each cell
itself: blend the band with a copy of itself rolled half a turn, weight 1 at the wrap, smoothstepped
to 0 by 40 px. The rolled copy is continuous exactly where the original is not, and the weight is
back to zero a few dozen pixels in, so the middle of the cell keeps its own contrast instead of being
averaged with the far side of itself. **THE BAND IS THE INSET ONE** — `buildlib.cell` insets every
cell by 2 px, so the columns that actually meet are 2 and 509 and tiling the full quadrant would
leave a 4-px step in the only place it matters.

Measured, mean |left−right| against the mean step between neighbouring columns: needle **9.99 →
9.73** against a grain of 9.65, foliage **12.46 → 6.96** against 6.52, bark **11.80 → 7.00** against
7.85, dark foliage **7.18 → 4.48** against 4.62. The wrap is no longer a worse discontinuity than the
art's own grain, and two Blender renders against a grey plane — elevation and 47° of pitch, where the
compound camera lives — show no seam on any of the four.

**LEVELS DID NOT MOVE AND THAT IS WHY THE GREEN GEN SHIPS NEARLY NEUTRAL.** Each cell is multiplied
per channel in linear light onto the mean the crop sheet measured (needle 59.8/63.5/57.4, foliage
49.9/53.0/47.7, bark 48.4/47.4/46.7, dark 43.2/45.9/41.2) — the park's fitted palette, taken from
what the glbs these replace shipped. Built sampled albedo: conifer **53/56/51** against the retired
`tree-conifer`'s 52/56/49, dome 45/48/43, sprawl 47/49/44. 0 UV smears on all four. Per channel and
not a scalar because the target is a measured triple; the multiply is flat, so nothing clips.

Two geometry faults went with it, both reported. **The conifer was too narrow**: it matched the
retired glb's 0.341 plan aspect on purpose and now runs **0.44** (2.5575 → **3.30** across at the
same 7.5 tall). 0.44 is the cell's ceiling, not a taste — `green` jitters a plant by 0.20 of a 4-unit
cell and scales it by up to 1.10, and `lean` zeroes the offset toward anything that is not grass, so
the tree must fit its own cell at max scale (0.44 × 1.10 × 7.5 / 2 = **1.815** against a 2.0
half-cell) and the only thing it can overlap is a neighbouring LAWN cell. At 0.48 it overhangs with
no jitter at all. **The sprawler was a pancake**: 1.85 × 0.81 in plan and 0.86 tall is 2.29:1 in plan
against the dome's 1.05 and 2.15:1 in elevation against its 1.73. Squash 0.58 → **0.80** and crown
0.78 → **0.88** of H give 1.8496 × 1.1108 × **0.968**, i.e. 1.67:1 and 1.91:1 — still the lowest and
widest of the three, which is what the squash is for. Its `GREEN` row follows the mesh to `h` 0.97.

Batches unchanged at **58 / 54 / 51 / 64**, so no placement moved.

## Four cells could not hold five tones, and the broadleaf joins on the conifer's construction (2026-09-16)

"conifer texture lower half is taken from the wrong sub-texture" — and it was, exactly. The tree's
bottom two skirts take a DARKER tone so the tiers do not read as one flat cone, and on a 2x2 sheet
the only dark cell was the dark BROADLEAF. One tree, needle mottle above and leaves below.

**A 2x2 IS FOUR CELLS AND THE PARK NEEDS FIVE**: light, a darker tone of THE SAME FOLIAGE, and bark
— and the conifer's foliage is needles where the shrubs' and the broadleaf's is leaves. So needle,
needle-dark, leaf, leaf-dark, bark. `sheet_build.py` now cuts **two sheets out of the one gen**, and
that is free rather than cheap: `tools/models.mjs` writes every label its own resized copy, so these
glbs already carried a 512 each and sharing one source bought nothing. `conifer-sheet.png` is
needle / needle / bark / needle-dark, `plant-sheet.png` leaf / leaf / bark / leaf-dark. Needle-dark's
seam measures **9.99 → 7.54** against a grain of 7.48, i.e. the same close as the other four.
Built albedo: conifer **53/56/51** against the retired glb's 52/56/49.

**Trunk doubled**, 0.115/0.075 → **0.23/0.15**. Those radii were fitted to a tree 2.5575 across and
the tree is now 3.30; at the old figure the bole read as a wire under the skirts. 0.23 is 14% of the
bottom skirt's radius, which is what the broadleaf reference measures for its own bare trunk.

**THE BROADLEAF GOES HAND-MODELLED ON THE CONIFER'S CONSTRUCTION AND COSTS 800 TRIS AGAINST 4,866.**
Nothing new was invented: the same scalloped unit section (`LOBES` 8, half-step `PHASE`, `RAD_K`
dividing the 0.966 back out), the same `fit` cutting each piece a cell band of its own aspect, the
same tapered eight-sided bole. A conifer is five shallow skirts up a cone; a broadleaf is **one deep
lobed spheroid with two smaller ones SUNK into it**, not stacked on it — their job is the shoulder
they put in the outline, because a single lathe reads as a turned object from every angle, which is
the fault that cost the first shrub dome its shape. 6.8799 x 6.745 x 9.5, z_min 0, holes 0,
coplanar 0, 0 UV smears, sampled **46/48/44** against the old 48/52/48.

Every dimension is a figure the repo had already measured, and each is a clearance or a placement
number rather than taste: `h` 9.5 with `Models.instanced` scaling by height alone; bbox
widest/height **0.71** kept on the nose (0.724 as built, the offset lumps); **the crown flares at
0.35 of the height and that is the only reason `h` is 9.5** — 3.33 units of clearance under the
lowest leaves against a 3-unit player sprite, where the retired `-lowcrown` skirted to 0.22 and the
player walked head-first into it; and the bole at 14% of the crown's half-width, where `-parasol`
is what a 7% stick under a wide crown produces. **Its width is far over the cell ceiling the conifer
is held to** (0.71 × 1.10 × 9.5 / 2 = 3.71 against a 2.0 half-cell) and that is pre-existing and
kept: this tree has always overhung, `lean` only ever offsets it toward another lawn cell, and
narrowing it would move the park's spacing for no reported fault.

**IT DROPS `sink`, AND THAT IS WHY THE PATH AND THE SINK ARE RESOLVED TOGETHER.** `BROADLEAF_SINK`
0.09 exists because the generated canopy ran to the ground and ended in a ragged fringe of holes and
spikes that stood proud of the lawn. This one ends in a closed cap 3.33 up: there is nothing to bury,
and burying it would eat a third of the clearance the height exists to buy. `FacilityGround` now
resolves `BROADLEAF_PATH` and `BROADLEAF_SINK` off the same flag, beside `CONIFER_PATH`.

Live: **58 conifers / 45 broadleaves / 54 + 51 + 64 shrubs**, warm unchanged at 91 programs and the
batch count unchanged — `GREEN` swapped a path rather than gaining a row, so `FacilityWarm` and
`FacilityArea.EXTRA` both needed no edit. 45 × 4,866 → 45 × 800 is **−183k triangles** in a park.

## One density per model, and a mirrored wrap is what makes a sub-rect possible (2026-09-16)

Three reports, one cause. "broadleaf secondary additions have a different u,v scale from the main
part"; "tops look dumb — texture smear", with the numbers off the debug readout (a side face at
u 0.725..0.775 and the face straight above it running u 0.557..0.69); and the conifer "still has a
very rough split in two halves".

**`fit` WAS ISOTROPIC BUT NOT CONSISTENT.** Each plant script handed a lathe the full cell width for
one turn and a v-band matched to its own aspect, so the density it landed on was `cellW / circ` — a
different one for every piece. And a cap was worse again: `disc_uv` over a whole cell puts a
0.17-unit circle on 256 texels, sixteen times the band beside it. Measured as surface **area** at
the wrong density:

| model | area >2× median | area <0.5× | p95 tx/unit (median) |
|---|---|---|---|
| conifer | 10.9% | 13.7% | 891 (54) |
| broadleaf | 7.2% | **55.5%** | 308 (28) |
| bush-dome | 6.7% | 8.0% | 672 (81) |
| bush-upright | **34.1%** | 0% | 1083 (70) |
| bush-sprawl | 6.4% | **42.2%** | 1679 (129) |

`buildlib.uvfit(rect, scale, circ, height, mirror)` replaces all three copies of `fit`. Each model
names a **`SCALE`** once and every piece — every skirt, crown, lump, bole and cap — asks for the
centred slice that lands on `cellW / SCALE`; a cap asks with `circ = height = 2r`, so its inscribed
circle comes out at the same density. After: **0.5–1.8% of area over 2×, nothing under half**, p95
70–250 against medians 25–95, anisotropy median 1.22–1.59. What is left is the lathe **apex**, which
every converging lathe has.

**A SUB-RECT NEEDS A MIRRORED WRAP, AND THAT IS THE OTHER HALF.** A plain wrap abuts a rect's left
edge column against its right, so it closes only on art that tiles across exactly that rect — true
for at most one rect per cell, which is precisely why the first pass had to hand every piece the
whole cell and take whatever density followed. `lathe_uv(mirror=True)` runs u **0 → 1 → 0**: left
meets left, right meets right, so **any** sub-rect closes on **any** art with no tiling requirement.
`SCALE` is HALF the largest circumference because a mirrored turn crosses its slice twice — which
also **doubles the density for free**: conifer 27 → 54 texels/unit, broadleaf 13 → 25, shrubs 43 →
87. At the lower figure the broadleaf's leaf art read as blotches.

**THE FOLD HAS TO LAND ON A VERTEX** — measured, 40 zero-area UV triangles on each 16-point model
at a flat `SEAM` 0.75. A multiple of 1/segments is not enough when `section` turns the whole ring by
`PHASE`, half a step: the vertices then sit at (i − 0.5)/16 of a turn and 0.75 falls exactly between
two. `SEAM = 0.75 + PHASE / 2π` puts both folds back on one. The shrubs never showed it — ten
points, no phase offset, seam 0.7. **0 smears on all five.**

**The conifer's tiers are a ladder of three, not a pair.** Light over dark is a 28% step with two
skirts on each side of it, which is the "rough split in two halves". `conifer-sheet.png` now carries
the same needle mottle at **0.95 / 0.875 / 0.80** of the crop sheet's level and the skirts take
dark, mid, mid, light, light. The ladder sits a rung BELOW light rather than starting on it: with
four of five skirts off the top two rungs the tree came back at luma **57.6**, out of the 46-52
family. It samples **52/55/50** against the retired glb's 52/56/49.

**The domes are half-ellipses.** Seven rings closing to 0.06 rather than five closing to 0.18 — a
0.18 top ring is a flat disc a fifth of the shrub across, and four straight steps under it are not a
curve. The broadleaf's crown closes to 0.05 from 0.12 for the same reason. Costs 80 tris a crown:
dome 192 → **272**, upright and sprawl 372 → **492**, conifer and broadleaf unchanged at 824 and 800.
Batches unchanged at 58 / 45 / 54 / 51 / 64.

## `lathe_uv` cannot map an apex, and a float at the seam put a skirt in the bark (2026-09-17)

Two reports, both with the face dumps to prove them, and they are different bugs.

**THE APEX.** "still smear on top", with a broadleaf face at `uv 0.874,0.118 / 0.812,0.118 /
0.812,0.092` and a bush-dome face at `0.998,0.177 / 0.899,0.177 / 0.899,0.158`. Both are the last
band before the cap. `lathe_uv` takes u from `atan2`, so a face's u span is the SAME on every ring
while its world width is `2πr / n` — as a lathe closes to a point the texels across it go to
infinity. Measured: the dome's last band ran **408 texels/unit across against 33 up it**, anisotropy
12; the broadleaf's 18. Nothing about the band's height touches it, because density across is `C / r`
and only r is in it. This is not a tuning problem and no `SCALE` fixes it.

**`buildlib.taper_uv`** is the answer: u by arc length round the section **scaled by each ring's
radius** about the slice centre, v by **slant length** up the profile rather than by z. That is the
unwrap a surface of revolution actually wants — the art pinches toward the apex exactly as the
geometry does, and a steep band gets the v it covers instead of the height it spans. `seam` is an
INDEX into the section, which also retires `lathe_uv`'s phase trap: with an alternating-radius
section every edge is the same length, so vertex k sits at exactly k/n round and the mirrored wrap's
folds (0 and 0.5) are vertices by construction. `SCALE` now takes the section's REAL perimeter
(`buildlib.perim`) — a 16-point scallop inset to 0.68 measures 7.26 unit lengths round where a
circle measures 6.28.

| | density p95 vs median | area >2× / <0.5× | anisotropy median / p99 |
|---|---|---|---|
| before, per-piece `fit` | 308–1679 vs 28–129 | 6.4–34.1% / 0–55.5% | 1.2–1.6 / 25–45 |
| `uvfit`, still `lathe_uv` | 70–250 vs 25–95 | 0.5–1.8% / 0% | 1.2–1.6 / 25–45 |
| **`taper_uv`** | **23–92 vs 22–86** | **0% / 0%** | **1.17–1.23 / 1.7–3.0** |

**THE BARK.** "conifer leaves use trunk tex", face at `uv 0.502,0.811 / 0.44,0.811 / 0.44,0.75` —
and 0.44 is outside its own cell, in the bark's. **A FLOAT AT THE SEAM VERTEX.** `t` there comes out
as 0.99999997 rather than 0, so `lathe_uv`'s straddle test (`max − min > 0.5`) fires on the face
AFTER the seam instead of the one before it and pushes a 0.0625 to **1.0625**; the mirror's
`1 − |2t − 1|` then maps that to **−0.125**, a sixth of a cell outside the rect's left edge, which is
the next cell along. Measured as 8 faces at u 0.483..0.537 straddling the 0.5 gutter — one quad per
band of tier 1, wearing bark. The fold is now periodic, `1 − |(2t mod 2) − 1|`, which maps 1.0625
back to 0.125 where it belongs. **0 cell-crossing faces on all four.**

**THE SPRAWLER IS GONE.** "that sprawl bush looks dumb, remove it" — and the honest reading is that
the squash on one axis was the only thing separating it from the dome IN PLAN, which is the axis
this camera mostly sees: at 0.58 it read as a pancake and at 0.80 it read as the dome again. Cut
rather than retuned a third time. `TILE_BUSH` now deals TWO variants, the 169 shrub cells split
**85 / 84**, and the park draws **one batch fewer**.

Live: 58 conifers / 45 broadleaves / 85 + 84 shrubs. Conifer samples 53/56/51, broadleaf 45/48/43,
dome 47/50/45, upright 47/49/44 — all inside the 46-52 outdoor family. 0 UV smears on all four.

## The car park is one tile now, and 68% of the bays were being painted on yards (2026-09-17)

The compound is blanked to `TEMP_ALLEY` before anything is cut, so the car park, the yard block and
every 2-cell gap between plots finalised to one id and `FacilityModel.surfOf` read all of them back
as `Surf.LOT`. `FacilityPaint.bays` and `FacilityCars.spots` both struck on that surface, so any
asphalt that happened to touch a pavement got bay dividers and could get cars — a car park with no
gate on it and nothing to have driven in through.

MEASURED BEFORE FIXING, over 20 live layouts: **1,850 kerbside lot cells** (open lot four-adjacent to
walkway), **600 in the car park and 1,250 outside it — 68%**. That is the size of the bug, and it is
not visible in every compound: the seed looked at first has its yard columns against the grid edge
and a phase that strikes no divider there, so `marks` came back **201 either way**. A regression this
shape hides behind whichever seed you happen to load.

THE FIX IS ONE TILE. `TEMP_PARKING 29` → `Const.TILE_PARKING` (`OFFSET_CHEM_LAB + 10`, 122), written
over the parking plot by `FacilityGen.fill`'s `PARKING` arm — a plot that was already open lot, so
the mark changes no geometry and only NAMES it. `surfOf` maps it to `Surf.LOT` exactly like the
alley, so debris, lamps, the gate and every other lot-gated pass are untouched; a `parking` grid on
the model carries the raw mark and `FacilityModel.isParking` is what the two passes that mean THE CAR
PARK ask instead.

NO NEW ATLAS CELL, and that is the half worth remembering: `tiles.Default.getIcon` aliases
`TILE_PARKING` to `TILE_ALLEY`'s cell. The asphalt IS the alley's asphalt and the bay lines are
emitted geometry, so the mark needed a walkability row (row 7 slot 10 was already `1`/`1`) and
nothing else. Editing the tileset PNG for a tile that must look identical would have been the whole
cost of the change.

TWO ID TESTS HAD TO WIDEN, both of them the checkpoint's: `AreaGame.isLot` and `GenCheck.gate`'s
flank test read `TILE_ALLEY` literally, and the two rows inside the gate's mouth are now car park —
left alone, the compound draws no booth at all. The MOUTH itself stays `TEMP_ALLEY` on purpose:
`gate()` re-derives the checkpoint from open-lot cells inside the pavement band, and narrowing that
scan to the mouth alone is a tightening it gets for free.

3,000 seeds clean with the new `GenCheck.parkingSane` (one solid rect, and the gate opens into it);
after: **cars 5, gate booth and barrier unchanged, `marks` 201**.

**Verdict: landed. When one tile id means two different places, the renderer cannot tell them apart —
and "open lot is what the grid was blanked to" is exactly how that happens by accident.**

## Five prop faults, and three of them were one square cell (2026-09-17)

Reported together: every mug and every drum wearing a vertical black seam down its back, the drums'
hazard signs stretched, the bookcase's upper three boards not lining up with their own art, the cable
reel flat and green, and the traffic cone too convex.

THE SEAM WAS THE CELL'S OWN EDGES. `lathe_uv` abuts a cell's left column against its right, and a gen
draws its object on a plate — measured, drum-sheet.png cell 3's outer columns are rgb 1/1/1 against
an interior of 56/67/78, desk-sheet.png cell 0's are 102 and 44 against 196. Wrapped at SEAM 0.75,
which puts u = 0 at +y, that is a dark column meeting a darker one down the BACK of the prop, exactly
as reported. **models-src/facility/wrapfix.py** rebuilds the wrap cells: fade the cell's last 44
columns over its first 44, drop them, resample to full width. The output's first and last columns now
differ by 2.6 of 255, grain level, and the resample it costs is 1.09x. NOT the plants' half-roll
`tileable`, which is right for a mottle and would have ghosted a drum's sign through its own seam.
Cells are named, not swept: a lid (disc_uv) and a leaf (flat_uv) have no seam to close.

THE SIGN'S ASPECT IS THE CELL'S ASPECT. A cell is square and an unrolled drum is 2 pi R / H = 2.09:1,
so one wrap spent 136 texels per world unit across the barrel against 284 up it. `WRAPS 2` lands 291
against 282 — isotropic to 3% — and puts a round sign on each side, which is where a real drum
carries one. It only became free once the cell closed. `lathe_uv`'s `reps` had to be fixed first: its
copy index was a ROUNDED minimum, exact only at reps == turn count, and at reps 2 over 20 sides face
5 (spanning 0.5..0.6 of its copy) came out at u 0.0..0.2. `floor` is the copy.

THE BOOKCASE WAS THE CHAMFER, NOT THE NUMBERS. `unwrap` lays a face's FINAL bounding box over its
whole rect and `chamfer` insets that box by EDGE 0.018 on every side — 0.5% of the 3.36-tall carcass
and 45% of a head rail 0.077 tall. So the three thin boards wore a band up to 1.8x taller than the
stripe they stand on and the 0.329-tall plinth looked right, which is "the upper three are
unaligned". Cutting each board's rect by the same inset puts all four fronts at 194.9 texels/unit
against the carcass's 197.8. The BOARDS fractions were re-read off the image at the same time (a
board is the flat band, sd < 6, between two bands of spines at sd 13-19) and were up to 8 px out.

THE REEL WAS TWO FAULTS. Flat because every flat annulus on the lathe — the whole of what this camera
sees — wore a 16 x 16 crop stretched over 2.66 units, and the turned bands wore R_FULL, the whole
sheet including its rail highlight. Both take the sheet's clean field now. Green because
fence-sheet.png is PAINTED steel at 41/52/47; `sat` 0.2, the railing's own knob, lands it at 48/50/49
with chroma 10.8 -> 2.0 and luma held.

THE CONE'S first five rings now sit exactly on r = 0.300 - 0.1807 * (z - CONE_SLAB) and only the last
three leave it, slope 0.21 -> 0.40 -> 0.70 into a 0.014 apex. 392 tris against 360.

All five: 0 uv smears, holes 0, coplanar 0, dimensions unmoved.

**Verdict: landed. A square cell wrapped once round a cylinder states TWO things that are usually
both wrong — that the art tiles across the cell, and that the barrel is as tall as it is round.**

## A wall decal stood on the cell boundary, and a compound's wall is not there (2026-09-17)

Reported as blood on the inner facility walls hanging in the air, and the same on the washroom
dividers. It was arithmetic and it was in the decal layer, not the facility.

A splat or a bullet hole is placed from the cell the drop or the shot DIED in, and a cell turns solid
at its BOUNDARY. `Blood.draw` and `WallHole.draw` both took the stored sub-cell offset on BOTH axes
and nudged 0.12 along the face normal — correct in the city, where a wall cell is masonry to its
edges, and **1.12 units wrong in a compound**, where `FacilityGeom` centres a slab of WALL_T 2.0 in a
4.0 cell. On a washroom divider it is worse: PART_T is 0.6, so the splat stood **1.82** clear of it.

THE FIX IS THE `standOff` PATTERN AGAIN — the hook that already exists because a facility fitting is
pushed off the wall face and its fake shadow was landing in the middle of the tile. New sibling
`WorldCtx.wallFace(col, row, dir)`: how far from a wall cell's centre the area kind actually draws
that face, -1 where the cell is not its wall, null in every area whose masonry fills its cell (the
city and the tunnels, which is why nothing out there moved). `WorldCtx.faceOff` adds the proud nudge,
now `RenderConfig.DECAL.wallProud` rather than a 0.12 written inline twice. Only the NORMAL axis is
taken from it; the tangential coord keeps the dx/dy the drop landed with.

`FacilityGeom.wallFace` answers `thick(col, row) / 2` for masonry — the same function `wallMounts`
uses, so a vent grille and a splat cannot disagree — and for a divider it asks
`FacilityDeco.rectOf`, which is the box the emitter itself draws: a partition spans its cell along
its own run and is PART_T across, so the answer depends on `dir` and a constant would have been
wrong on two of its four faces.

VERIFIED BY A/B IN FRAME rather than by arithmetic alone: splats placed on a washroom's two side
walls sit flat on the masonry, and clearing `WorldCtx.wallFace` live puts the same splats a unit out
over the floor. The partition test needed finding first — a divider cell reads see-through in the
static tileset table and opaque in the live grid, which is why blood reaches one at all.

BULLET HOLES DO NOT REACH A COMPOUND AT ALL, asked in the same report. `Shot.spawnBulletHole` returns
early unless a `WorldCtx.buildings` entry owns the struck cell, and `FacilityArea` sets that list
empty — so no WALLHOLE decoration is ever written indoors or out. The decal pass itself is fine and
now places correctly if one ever is.

**Verdict: landed. A decal placed from "where the thing stopped" is placed from the CELL, and only
the area kind knows where inside that cell it actually drew the surface.**

## A cell that wraps and a cell that fits are two different questions (2026-09-17)

Four more faults off one report, all of them on cells of a packed sheet and none of them on a mesh.

**The mug's icon was stretched, and it is the cell's ASPECT** where the drums' signs were the same
thing on a barrel. `desk-sheet.png` cell 0 is a square glaze with a cup mark in the middle; the
surface it wraps is a height-weighted mean radius of 0.1325 (circumference **0.833**) over a height
of **0.340**, so one turn laid 615 texels per world unit across against 1506 up — measured on the
built glb as **anisotropy 2.45** over its 268 side triangles. `MUG_WRAPS 2` halves the u span:
**1.25** measured, and the mark appears on both sides of the cup, which is what a printed mug does.
`reps` MUST DIVIDE the turn count and 16's divisors step 1, 2, 4 — three copies would land at 0.82,
so 2 is the only count between the two errors, and 22% is as close as this cup gets.

**The gas bottles carried the drums' black seam** for the drums' reason exactly: `gas-sheet.png`
cell 0's right column measures rgb **5/3/1** against its left column's **168/88/21**, cell 1's left
**2/1/0** against **43/46/48**, and `lathe_uv` abuts one against the other at SEAM 0.75 — the +y
back. Both cells go through `wrapfix.py` into `gas-wrap.png`; the two edge columns now differ by
**1.1 of 255**. Cells 2 (frame iron) and 3 are not lathed and pass through untouched — the sheet
lists the cells a lathe actually turns rather than sweeping them all, because blending a `disc_uv`
lid's edges only smears it.

Both glbs re-measured: mug 424 tris, gas rack 1772, holes 0, coplanar 0, dimensions unmoved, and
**0 zero-area UV triangles** on either.

**Verdict: landed. The seam question is "does this cell close on itself"; the aspect question is
"does this cell have the proportions of the surface it is about to wear". One cell can fail both.**

## The checkpoint goes hand-modelled, and the quads lose on DRAW CALLS (2026-09-17)

The third route for the same two objects, and the first one that is cheaper than what it replaces.
Generated they were 3,098 and 7,431 triangles with the hazard bands baked orange-on-tan; emitted they
were 22 and 34, and that entry's rule — a box is not a prop — is about GENERATED props. This is the
fourth route: `models-src/facility/entry_build.py`, every number copied from `FacilityStyle`, behind
`FacilityStyle.ENTRY_BLENDER` with the quads still shipping.

**Measured in one pinned frame at the gate, same pose, same seed, flag flipped and rebuilt between:**
emitted **101 dc / 177.8k tri / 1250 geom / 406 tex**, hand-modelled **97 dc / 180.5k tri / 1246 /
402**. **−4 draw calls for +2.7k triangles**: the quads were five merged meshes (cabinet, arm, walls,
roof, glazing) and the meshes are two instanced batches plus the same glazing, which is also why the
texture count fell — four fitted textures became one packed sheet baked into two glbs.

**THE BOOM'S LENGTH IS THE TRAP AND IT ONLY JUST SURVIVES.** `Models.instanced` scales by HEIGHT
alone, which is why the prop era's barrier spanned 14.7 units whatever the generator cut. It works
here only because the mouth is `RoadBlock.ENTRY_W` 4 cells on every seed: the mesh is built to
`4 * CELL − BARRIER_INSET − BARRIER_TIP` and the batch passes `BARRIER_CAB_H` so the scale is 1.
**The band pitch is the honest regression** — the art's cell holds six bands and two arm pieces each
wearing it whole gives 12 bands at **1.155 units** against the emitted arm's 1.0, because `reps` here
is geometry and geometry comes in whole pieces. Three pieces would land at 0.77, further off.

**THE GEN LANDED 7.7x OVER THE COMPOUND'S OWN CLADDING** and the fit is to the four textures this
replaces, not to the 46-52 prop family — those four were each fitted live at the game camera and
carry their numbers in `textures.json`. `entrytone.py` moves each cell onto its predecessor's
`built_linear`: bands ×0.7626 to 0.2331 (`barrier-arm` 0.3108 × `BARRIER_TINT` 0.75, baked in because
one instanced glb has no material `color` of its own, and a SCALE not a gamma — a gamma blows the
6.8x band ratio), cladding gamma 2.55 to **0.0327**, decking gamma 1.24 to **0.0849**, and the
cabinet steel **left alone** at 0.0411 against `barrier-post`'s 0.0439.

708 and 672 tris, holes 0, coplanar 0 — three z-fighting pairs caught by `check` first, all of them a
piece whose face landed on a neighbour's plane. The glazing stays quads: one glb carries ONE
material, and the lit band wants its own emissive intensity.

**Verdict: landed behind `ENTRY_BLENDER = true`. "A box is not a prop" is about the GENERATOR, and a
hand-modelled box that replaces five merged meshes with two batches pays for itself in calls.**

## The boom's own row is unwalkable now (2026-09-17)

A bar across a drive that the player walks through is decoration, so the generator stamps it. The
ENTRYWAY arm writes `TEMP_BARRIER` -> `Const.TILE_ALLEY_UNWALKABLE` across the mouth row nearest the
lot — four cells, the line `FacilityEntry` lies the boom and its cabinet on. No new tile id and no
new atlas cell: `game.CorpAreaGenerator` already writes that id and `tiles.Default` already has 0 in
`TILE_WALKABLE` for it.

`FacilityModel.surfOf` returns `Surf.LOT` for it like the other two asphalt ids, so `isEntry`, the
ground pass, the lamps and the cars are all untouched. What had to widen is the MOUTH SCAN: both
`AreaGame.gate` and `GenCheck` bound their box over alley cells lying within the pavement band, so
with one row repainted the mouth read 4x1 and failed its own depth assertion. `isMouth` in both files
takes the two ids, `GenCheck.gate` additionally asserts the boom's row is unwalkable across its whole
width, and 3,000 seeds pass.

Verified live: the four cells at (52..55, 5) read `isWalkable` **false**, the lot row behind them
true, and the pavement either side is walkable — a compound is not sealed by this, a car park is.

**Verdict: landed. The checkpoint was retroactive because it touched no tiles; one row of tile is
what it costs to make the barrier mean something, and an old save simply keeps a boom you can walk
under.**

## Five reports on the checkpoint, two faults, and one repainted cell (2026-09-17)

> PARTLY SUPERSEDED by *A flat colour is not a UV, and a span has to fall* — the chamfer's flat
> centre colour and the cable's sideways bow were both wrong and are both replaced. Everything
> else in this entry stands.

The five: the booth's top and its top SIDES "have angles"; its mast should be round and carry a
cable; "all edges are weirdly green (that's ALL edges)"; and on the barrier, smeared faces, faces
whose "u,v resolution is too small", and "all sides are stretched". They are two faults and a bad
cell.

**STRETCHED IS THE UNWRAP'S OWN CONTRACT.** `buildlib.unwrap` lays a rect over a face's own bounding
box, which is isotropic only where the two aspects already agree. The cabinet's 1.2 x 1.92 flanks
wore a SQUARE cell — 1.6x denser up the box than across it, reported as a squashed louvre bank — and
the roof slab's 4.36 x 0.30 flanks wore the same square cell at **14x**, with `R_FASCIA` cut for
exactly those faces and never applied. `tag` takes an ASPECT FIT now (add 3 to the axis code and the
rect is cropped about its centre until the two texel densities meet), and the slab's flanks take the
fascia band. Measured on the built glbs with a per-triangle UV jacobian: booth **aniso median 1.00,
max 1.00** over its 36 mapped triangles; barrier median 1.17, and its only outliers are the BOOM's
own faces at 23.7 — deliberate, and what tiles the hazard bands, so that piece keeps `axes 2`.

**SMEARED, GREEN AND UNDER-RESOLVED ARE ALL THE CHAMFER STRIPS.** A strip is 0.014 wide against a 40
px plain swatch, so a bbox map spends the swatch's whole width on 0.014 units and its whole height on
a face metres long. `chamfer` takes `flat` and puts the strip on the swatch's CENTRE COLOUR (`tag`'s
axes 6) — one flat colour, unsmearable at any rect size. And every strip, lid, soffit and reveal on
both meshes took the CABINET's swatch, which is olive: a blue-grey kiosk under a blue-grey roof was
outlined in green on every arris it has. Three swatches now, one per painted metal, each the flattest
40 px patch of its own cell — cell 1 sd 1.73 at 61/67/56, cell 2 sd 3.13 at 50/67/75, cell 3 sd 1.62
at 72/85/95.

**THE ANGLES WERE IN THE ART.** The pack4 gen drew the roof decking in PERSPECTIVE, its standing
seams fanning to a vanishing point, so on a flat square slab they read as diagonals. One solo
orthographic gen replaces that cell through `entrytone.py`'s new `PATCH` table and goes through the
same tone fit as if it had come in the pack: it landed at 0.0717 linear against `booth-roof`'s fitted
0.0849, a gamma of 0.93.

**The aerial is round and now carries a cable.** The square crossbar read as a cable termination with
nothing attached, so the mast is an 8-sided lathe and the crossbar a 12-sided bulged collar (672 ->
768 tris). `FacilityEntry.cable` runs a service drop to it from the gate's own mast
(`FacilityLamps.gateMast`, extracted from that file's own placement loop so the two cannot disagree)
and BORROWS FacilityCable's ribbon the way the desk leads do, so it costs no draw call. The ribbon
lies in the most nearly horizontal plane through both ends and the bow is sideways rather than a sag:
a ribbon is widened along the vector it is bowed along, so a sagging run would be `CABLE_W` of ribbon
seen edge-on from a camera pitched 51 degrees down. Verified live — the nearest vertex of the
`facility/cable` mesh to the computed collar is **0.063 units** away, which is half `CABLE_W`.

**Verdict: landed, both meshes rebuilt (708 / 768 tris, holes 0, coplanar 0). The two fixes are
`buildlib`'s and not this model's — an aspect fit and a flat strip are what every hand-modelled prop
in this repo wants, and the rest of them still take the old default.**

## The car park's cars are impassable, and cost two tile ids (2026-09-17)

The boom's row went unwalkable last landing; the cars standing ten units from it were still walked
through. `FacilityCars` dealt the bays, ranked them by distance from the mouth and rolled one in
three empty, all render-side with nothing persisted — so the deal MOVED to `gen.facility.FacilityBays`
and the renderer reads the marks back.

**TWO IDS AND NOT ONE.** `TILE_PARKING_CAR` covers the bay and `TILE_PARKING_CAR_ORIGIN` its low
corner against the kerb. Two bays side by side along one kerb are a single 2x4 block of marks with no
seam in it, so one id alone cannot say where a car BEGINS — the renderer would have to walk the run
and agree with the generator's bay phase to find out. The origin says it outright and the yaw comes
off whichever neighbour is pavement, which deleted `spots`/`spot`/`fill` (90 lines) for a 25-line
`pose`. No new art either: both alias to the alley's asphalt in `tiles.Default.getIcon`, like
`TILE_PARKING`, and row 7 of `TILE_WALKABLE` had the two free slots.

**The bay rhythm is copied, not shared** — `FacilityBays.runStart` is `FacilityPaint.runStart` against
the TEMP alphabet, because the paint is render-side and the generator cannot reach it. A divergence
is now only cosmetic (a car across a painted divider rather than a car that vanishes), and
`GenCheck.parkingSane` asserts what can be checked without a renderer: cars <= the cap, marked cells
== cars x SPACING x DEPTH, and every origin has a kerb. That total is what caught the real bug —
**18 marked cells where five whole bays are 20**, two bays overlapping because a cell claims the
FIRST kerb it finds and a two-deep lot with pavement on both sides deals the same rect twice. Asking
`whole` a second time at stamp time makes the first bay dealt keep the ground.

3,000 seeds pass. Verified live: 5 origins, 20 marks, **0 of them walkable**, and the batch still
reports `car.glb = 5`.

**Verdict: landed. `FacilityStyle.BAY_SPACING`/`BAY_CELLS` now READ the generator's constants, which
is the dependency running the right way for the first time here: where a car may stand is a fact
about the save.**

## The parked car's lamps are out, on the baked atlas (2026-09-17)

Reported as the front white and rear red lights wanting to be dark and switched off. `facility/car`
is a TRELLIS bake, so a new reference costs a fresh `image_to_3d`, a fresh unwrap and a re-fit of
`baseColor`/`ao`/`tex` for four patches of paint — the call `tools/livery.py` already made on the
drums. `models-src/facility/carlights.py` is a per-pixel pass over the dumped 2048 atlas, wired
through `models.json`'s existing `texSrc`.

**THE KEYS ARE MEASURED AND THE BODY CANNOT REACH EITHER.** The lamps are the top two per cent of the
value range — v 240-255 is 0.58% of texels at rgb 251/112/113 sat 0.56, v 192-207 is 1.01% at
195/191/191 sat 0.03 — while the body tops out at 120 and stays between 0.12 and 0.20 saturation. So
"over 200 and saturation over 0.30" is a red lens and "over 185 and saturation under 0.12" is a white
one, and neither can touch the paint.

**NEITHER TARGET IS BLACK.** An unlit tail lens is dark red glass and an unlit headlamp a grey
reflector, both still lighter than the paint; a hard black reads as a HOLE in the car at this camera,
which is the failure `textures.json`'s `lift` exists for. Measured: red **18,635 texels 245/23/23 ->
54/28/28** with 45% of its chroma kept (mixed in linear light), white **58,837 texels 204/206/206 ->
88/88/88**.

**Verdict: landed. A per-pixel key beats a re-roll whenever the thing to change is a colour and the
atlas is a fragmented chart layout — second entry on that rule after the drum liveries.**

## The sewer hatch gets its own hi-res cell (2026-09-17)

The lid is the flattest object in the game — `AreaObject.isGroundDecal` is true, so the 3D street
lays its sprite FLAT on the cell — and there is no silhouette to buy, which is the triage rule saying
TEXTURE outright. It drew from a 64 px `entities64` cell at near-black with a checker on it.

**ONE IMAGE, ONE CELL, NO PACK.** A third arm in `Sprites.atlasFor` beside the bench and clue packs,
except that this one needs no index table and no coordinate arithmetic: the image IS the cell. A
hatch spans `Sprites.SIZE` 3.0 world units, so 64 px is **21 texels per world unit** against
`city/ground-asphalt`'s own 57 — the same number `facility/floor-grate`'s note records as blurry. At
256 it is 85.

**The drop needed cutting before it was adopted.** gpt returned the cover out to the frame edges with
a soft brown haze in the corners (alpha mean 192 over the whole square), so the source is masked to a
hard disc and inset to 94% of the cell — a lid lying on asphalt rather than one clipped by its tile.

**LIFT 0.75 WAS FITTED LIVE AND IS THE ENTRY.** A ground decal's crop is darkened by
`RenderConfig.DECAL.actorMul` 0.7 before it is drawn, which is 0.45 in LIGHT, so the mid-dark lid the
gen returned rendered at luma **8 against the pavement's 30** — 0.27x, the hole-in-the-ground
failure. The gamma takes `built_linear` 0.0505 -> **0.0975** and the drawn lid to luma 19 against 58.
Still 0.33x rather than the 0.65x the texture numbers predict, and the gap is the decal path's own:
read the RENDERED ratio when fitting one of these, never the built one alone.

**Verdict: landed. `tools/atlaspaste.py` rewrites the 64 px frame from the same source, so the 2D view
and the 3D sprite stay one object.**

## A flat colour is not a UV, and a span has to fall (2026-09-17)

> PARTLY SUPERSEDED by *An arris wears the piece it breaks, and a drop ends on the pole* — the
> plain swatch was still the wrong RECT for a strip. The sag stands.

Two reports on the last landing. Both of its shortcuts were read off the screen as the shortcut they
were.

**"WHY ARE THESE SO LARGE WHILE BEING MAPPED INTO A TINY TEXTURE SPOT?"** — six faces quoted, every
one with `uv a`, `uv b` and `uv c` identical, which is `buildlib.tag`'s axes 6: the rect's centre
colour and nothing else. It cannot smear, which is why it went in; what it does instead is paint a
4.34-unit corner arris of the booth in ONE texel, and a metres-long face in one texel is a drawn line
rather than a lit edge. `chamfer(flat)` and `entry_build`'s `PLAIN` both mean the ASPECT FIT now
(`tag` axes 5, `PLAIN = FIT`), so a strip gets the art at its neighbours' own density on both axes.
Axes 6 stays in `buildlib` as an escape hatch with its own warning; nothing uses it.

**THE LAST MEASUREMENT WAS A FALSE PASS AND THAT IS THE TRAP.** This entry's predecessor reported
"booth aniso median 1.00, max 1.00 over its 36 mapped triangles" — 36 of 768, because the per-triangle
jacobian SKIPS a triangle with zero UV area and a constant-UV strip is exactly that. Count the
degenerates or the ratio lies. Rebuilt: booth **768 tris, 0 degenerate, aniso median 1.08 p95 1.35
max 1.41**; barrier **708 tris, 0 degenerate, median 1.08 p95 1.13**, max still the boom's deliberate
23.67. The fit's price is scale, not shear: the roof-slab arris spends its 20 px swatch over 4.34
units (**4.3 px/unit**) and a corner nub wears the whole swatch at 3533 — isotropic at both ends.

**"MAKE THE CABLE MORE PHYSICAL — IT SHOULD BEND DOWN UNDER ITS WEIGHT."** The service drop bowed
SIDEWAYS, because `FacilityCable.strip` widened and bowed the ribbon along one vector and the
previous entry accepted that rather than reordering it. The two are separated now: `StripOpts.sag` is
a FRACTION of the chord, dropped along world down with the chord's component taken out, so both ends
stay bolted and a vertical run has no sag to take. The width axis is untouched, so the band still
lies level and faces a camera pitched 51 degrees down. The parabola is shared with the bow — a
catenary and `4t(1-t)` differ by less than a texel over this span. `ENTRY_CABLE_BOW` 0.9 -> **0.0**,
`SAG` **0.06**, `WAVE` 0.3 -> 0.25 so two compounds do not draw one curve. Measured live off the
`facility/cable` mesh: span **17.29 units**, worst drop below the chord **1.037** at t **0.5006**,
which is 0.060 of the span, both ends within a ribbon half-width of the pole and the collar.

**Verdict: landed, both meshes rebuilt unchanged in triangles (708 / 768, holes 0, coplanar 0). A
sag is one more axis and a plain swatch never needed the flat colour — the two shortcuts cost one
report each.**

## An arris wears the piece it breaks, and a drop ends on the pole (2026-09-17)

> PARTLY SUPERSEDED by *The roof was the problem all along* — the fit's DENSEST orientation was the
> wrong rule and is now the art's. The rest of the entry stands.

Both halves of the previous landing came back. "You didn't fix much on the edges, make the polys take
the full tex length like the nearby ones" and "cable is a little away from the lamp post itself,
there's a gap".

**THE STRIP WAS ISOTROPIC AND STILL WRONG, BECAUSE THE RECT WAS 20 PX.** An aspect fit can only
shrink, so a 4.34-unit arris wearing a plain 20 px swatch got 4.3 px per world unit against the
slab's own 58 — flat by arithmetic. A chamfer strip takes THE PIECE'S OWN RECT now (`part`'s
`edge_idx` defaults to `idx`), so its density is the density of the face it breaks; the reveals, the
drip edge and the aerial's mast came off their swatches for the same reason. What stays on a 20 px
patch is every solid under 0.6 units on its longest axis — the cabinet lid, the hinge collar, the
skirt hangers, the tip housing, the aerial's collar.

**AND THE FIT HAD TO LEARN TO TURN THE RECT.** Half the arrises were still at 13 px/unit after that,
because whichever of the face's axes lands on the rect's SHORT side sets the density for both: the
upper spandrel's 3.36 x 0.014 arris took `R_CLAD_UP`'s 46 px HEIGHT over 3.36 units. `buildlib.unwrap`
now measures both orientations in the fit and takes the denser, which on a strip is free and on a
large face does not trigger — a face whose art has a direction wears a rect cut to its own aspect, so
the swap loses there. Measured on the built booth, split by shape: **312 chamfer strips median 67.1
px/unit against 48 real surfaces at median 59.6** (before: 4.3 and 58). Aniso unchanged at median
1.08 p95 1.35, 0 degenerate, 768 / 708 tris, holes 0, coplanar 0.

**THE CABLE'S GAP IS `Models.instanced` CENTRING A GLB IT DID NOT MODEL.** `normalize()` recentres a
prop on its bounding box in plan, and the lamp's head overhangs toward what it lights, so the point
the batch is handed is out in the air BETWEEN pole and housing. Measured off `lamp-post.glb` over the
bottom 90% of a model normalised to height 1.002: the mast's verts centre on z **-0.0634** and span
0.102 across, i.e. the pole stands **0.37 units behind the placed point** and is 0.30 wide — so the
drop ended a third of a unit clear of a post it was supposed to be bolted to. `FacilityLamps.Mast`
carries `ax`/`az` now, the pole's own axis, and `FacilityStyle.LAMP_POLE_Z` is that measurement.
Verified live: the drop's post end lands at **-55.626, -180** and the bulb at -56.354, -180 — 0.728
apart, which is pole offset plus head reach exactly.

**Verdict: landed. Two rules worth keeping — an edge break belongs to the piece it breaks, not to a
swatch table; and a prop's PLACED point is its bounding box's centre, so anything that has to meet
its geometry needs the geometry measured.**

## The roof was the problem all along (2026-09-17)

Three reports, and the third one names the cause: "make the roof much thinner, we have problems
mostly because of that".

**THE SLAB WAS 0.3 AND IS NOW 0.12.** `BOOTH_FASCIA` is one dimension and nearly every face reported
on this mesh since the UV pass was a face of it — the fascia flanks, their arrises, the drip lip
under them. At 0.3 with a 0.45 eave the roof read as a parapet on a 3.4-wide kiosk; at 0.12 it is a
roofline. The mesh is 5.52 tall now instead of 5.7 and nothing else moved: the batch passes
`BOOTH_H + BOOTH_FASCIA + BOOTH_MAST`, and the cable's collar is the same expression, so the drop
followed it down — verified live at **0.063 horizontal** from the computed collar, which is half
`CABLE_W`.

**ORIENTATION IS THE ART'S, NOT THE DENSITY'S.** The previous entry's fit picked whichever of the two
rect orientations was denser, and on a 1.66-unit corner arris that turned the cladding a quarter turn
— reported as "not HORIZONTAL, VERTICAL", with a `uv` triple spanning the cell's full WIDTH across a
vertical strip. The rule is geometric now: UP takes v wherever the face has any height, and a face
with no height at all puts its longer axis on u. Measured on the rebuilt booth: the vertical arris
takes the cladding cell's 127 px of height over 1.66 units, **70.7 px per world unit** against the
wall's own 75.6, upright; the fascia flank 59.6 against the slab's 55.1; **312 strips median 46.4
against 40 surfaces at median 48.7**.

**AND A POLE IS NOT STRIPED.** Moving the aerial and the drip lip onto the roof CELL to buy density
put the decking's standing seams on them ("should not be striped"). That is the line between the two
rect families and it is not density: a piece whose read is a COLOUR takes a plain patch (the mast,
the lip, both reveals, the cabinet lid, the hinge collar, the skirt hangers, the tip housing, the
aerial's collar), and only the ARRISES OF A FACE take that face's own cell. The mast is back on a
20 px patch at 17.8 px/unit, which resolves nothing and is meant to.

**THE SLAB'S OWN FLANKS WENT THE SAME WAY, ONE REPORT LATER** ("make this face gray without stripes,
you can't have them there"). `R_FASCIA` — a 14:1 band cut from the decking cell for exactly those
faces, and the fix for the stretch two entries ago — is DELETED: any slice of a standing-seam cell
laid along a 4.26 x 0.08 edge is a row of stripes, whatever its aspect. The flanks and their arrises
take the roof's patch now, uniform at 4.7 px/unit, and the LID keeps the decking cell it should have.
The rect table is nine entries instead of ten.

**Verdict: landed, 768 / 708 tris, holes 0, coplanar 0, aniso median 1.08 p95 1.35, 0 degenerate.
Four reports on one model and the last one was the cheapest fix in the set — a constant.**

## A roof is a serviced perimeter, not a field of condensers (2026-09-17)

Phase 5b/5d of the compound plan: the lab roofs were a STRIDED SCATTER — every fifth interior cell a
candidate, the list thinned to `ROOF_PROP_MAX + 2`, the hatch nearest the middle and the dish on a
hash. Evenly spread props say nothing about the building, and the plan asked for zones plus a bare
middle.

**THE DECK IS CUT AND DEALT, RENDER-SIDE, BY THE GENERATOR'S OWN ARITHMETIC.** `gen.Subdivide.split`
+ `gen.Quota.deal` over the structure's footprint rect, seeded off `FacilityModel.mix` of the
structure's own CORNER — `si` is 0 and 1 in every compound ever generated and would lay the same two
roofs everywhere. **First render pass to reach into `gen/`**, and it is safe in the one direction
that matters: both are pure arithmetic over an injected rng, no `GenCtx`, no grid, no side effects,
and nothing goes the other way. The alternative was a second copy of the splitter every city block
in the game is already laid with. Profile `minSide 3, gap 1, depth 2`; demands `service` (min 1),
`dish` (min 0 max 1, `minW/minH` 4 so a small building simply has none) and `plant` (max
`ROOF_PLANT_BAYS 3`); filler `bare`. Measured on a live compound: **24 bays, 21 holding band cells,
6 plant, 5 with `band 0`** — the middle.

**THE RING BAND'S FIRST TEST WAS MEASURING THE WRONG WALL.** `ROOF_RING_INSET 3` keeps everything
2..3 cells in from the parapet, and `depth` counts steps to the first cell the structure does not
own. With the old indoor-floor predicate that meant the first PARTITION: a lab's rooms are 4-6 cells
across, so every cell came out 1 or 2 from a wall and the band was the whole roof. **49 candidate
cells with the band lifted against 47 inside it — the test excluded two.** On the footprint
predicate (floor, partitions and wall ring alike, which is the one continuous slab the deck
actually is) it is **57 band cells, 5 bays of bare middle**, and every placed prop measures 1-3 from
the footprint edge, i.e. inside the parapet and never on it.

**AND THE SERVICE RUN IS A TREE, NOT A FAN.** `FacilityCable.strip` in the deck plane from the hatch
outward, one ribbon per condenser, each from the NEAREST thing already fed. Fanned from the hatch
it struck **17 cells** across the empty middle on the 21x30 roof — seven hairlines over the deck the
band exists to empty. It rides a second per-structure `addDeck` mesh so it FADES with the deck: a
ribbon left behind would hang over the room the player just walked into. One pinned free-cam roof
pose: **calls 164 -> 165, tris 362,194 -> 362,334** (+140 = 7 runs x `CABLE_STEPS` 10 x 2).

**Verdict: landed. 7+8 condensers, 2 dishes, 2 hatches, 15 runs on a two-building compound, +1 draw
call per roof in view. The bare middle is deliberate and against the measurement — the camera runs
51-86 degrees and the parapet hides ~1.1 units, so `ROOF_RING_INSET` is the one knob if it reads as
a donut.**

## Naming the deck is what makes the alpha opaque (2026-09-17)

Phase 5c: `facility/roof-clutter`, the lab decks' pack64, consumed by `FacilityRoof.clut`/`flat` —
`FacilityHangar`'s arithmetic against a third sheet, the fourth copy of those six lines.

**IT IS THE ONE FAMILY THAT IGNORES THE RING BAND.** The band keeps OBJECTS out of the middle; every
cell of this sheet is flat by construction — tar patches, ponded water, chalk, anchor plates, drain
grates, felt seams — so it dresses the whole deck at `ROOF_CLUTTER_PCT 12`, which is also the answer
if the bare centre reads as a donut. Live: **122 decals over two roofs**, excluded only from the
cells the hatch and the condensers stand on and from the wall ring (a 2.8 decal centred on a ring
cell runs out over the coping).

**THE FIRST ROLL CAME BACK WITH A PAINTED HAZE BEHIND THE OBJECTS** — `facility/hangar-clutter`'s own
trap, re-run and re-paid. That prompt said the litter lay "of a FLAT BITUMEN ROOF DECK", and naming
the surface got one: lane alpha mean **56.7 with 11.1% of the lane over `DECO_CUT` 128**, i.e. a grey
sheet between the cells. The shipped roll names no surface at all and adds "THERE IS NOTHING BEHIND
THE OBJECTS": lane mean **0.8, 0.22% over the cut**. Parked at
`textures-src/facility/Unused/roof-clutter-haze.png`.

**AND THE GRID WAS 19 px COMPRESSED VERTICALLY**, caught by the same per-cell centroid test the
hangar sheet's `regrid` was written for: row 0 sat 19 px low and row 7 19 px high. `regrid
{grid 8, cut 200}` moved **58 of 64**, and the built sheet measures **lane occupancy 0.0000, every
cell centred within 14 px, no cell over the cap**. `cap 0.1` because the deck is `facility/roof` at
0.0275 linear and the chalk, bird splashes and efflorescence came back **0.15..0.36 — 5 to 13x the
surface they lie on**; 19 of 64 cells were scaled down. `sat 0.5` for the leaves, the rust and the
drink can: loudest cell chroma after it is **30.7** against the gas rack's 74.5 and the desaturated
drum's 45.3.

**IT POPS RATHER THAN FADING, DELIBERATELY.** The mesh rides `Shell.roof` so it goes with the deck,
and three tests `alphaTest` against `map.a * opacity` — the trap `FacilityArea.ease` records against
the window panes — so it leaves whole at about half the ease. That is exactly where `FacilityRoof
.mask` already drops the condensers, so everything standing on a roof goes together. It is the one
material of the three the roof emits that nothing else warmed (unpatched AND transparent, both
program keys): `FacilityWarm` now runs `FacilityRoof.build` over the demo model, **87 -> 88 programs
cached at boot**.

**Verdict: landed. calls 164 -> 167 with two decks in frame (service runs +1 per roof, clutter +1
per roof), tris +448. One gen re-rolled for the alpha, $0.11 for the pair.**

## The dish and the condenser, authored: 11,419 triangles become 1,608 (2026-09-17)

Phase 5a's two REPLACEMENTS, behind `FacilityStyle.ROOF_BLENDER`. Both were TRELLIS bakes and both
are now `models-src/facility/roofac_build.py` / `roofdish_build.py`.

**THIS IS NOT THE TRADE THE CHECKPOINT MADE.** There the hand-modelled pair cost 1,380 triangles to
buy silhouette against merged quads. Here both objects were already props and the authored versions
are simply cheaper, because every number in them is stated where a bake approximates all of them:
**660 against 5,619** (condenser) and **948 against 5,800** (dish). One pinned free-cam roof pose,
flag off then on, everything else identical: **calls 167 → 167, tris 362,642 → 293,430 — −69,212,
i.e. −19% of the frame.** Both `check` clean, 0 holes / 0 coplanar, `z_min` 0.

**THE DISH IS THE TEXTBOOK CASE and its bake's own note says why.** That reference came back **20
components at 74.4%** — every strut an island, every gap real air — and the fix was to repaint it as
ONE SOLID LUMP, i.e. to ask for less of what makes a dish a dish. Authored: `z = r^2/(4f)` with
**f/D = 0.40** (the middle of the real prime-focus band), so at D 2.66 the focus is 1.064, the depth
follows as 0.4156 and the feed horn stands AT the focus. `MAST_H` is solved against the tilted rim so
the mesh measures 3.6 exactly — a glb under its stated height is scaled UP by the batch and its plan
grows with it. The shell is ONE lathe and one closed solid (up the back from a 0.06 vertex annulus,
across the rim, down the concave front), which is `tube`'s vessel rule: ascending legs take outward
normals, descending ones inward. **Both faces are mapped RADIALLY** — their art IS a disc, so
`disc_uv` puts the art's circle on the mesh's circle and a lathe wrap would have run the panel joints
round the rim. **STEPS PAYS FOR SIDES**: 5 rings up a smooth-shaded parabola read the same as 6 while
16 sides read as a polygon at this aperture, so 5 x 20 costs the same 220 bands as 6 x 16.

**A RAISED COWL IS HOW YOU RECESS SOMETHING WITHOUT A BOOLEAN.** The condenser's fan well is a ring
wall standing ON the lid with the guard set 0.06 down inside it; cutting a hole in a box lid leaves
`check` a hole at every cut edge, and the guard is a PLATE and not a disc because a single flat
polygon is a boundary edge all the way round. First build put the cowl 0.72 deep — half the casing —
and it read as a duct on a box; 0.34 is a lip. The louvre is ART and the frame is GEOMETRY: two proud
rails for 24 quads, where a bank of real slats is 6 quads each on the one face that already has a
fitted texture. **AND THE LOUVRE CELL TAKES A WINDOW OF ITSELF** — 114 slats measured across the 512
cell, so laid whole over a 1.2-unit flank it is 95 slats per world unit, a slat every 5 mm; a 0.12
v-window is 13 slats, i.e. every 9 cm.

**THE VALUE FIT GOES ON THE DOMINANT FACE, NOT THE SHEET MEAN.** `rooftone.py` first put all eight
cells on a 0.030 linear mean and `propstat --audit` read the built glbs at **54.7 / 55.1** against
the bakes' 45.3 / 47.6 — because the cell carrying the most surface was the brightest of the four,
and a prop reads as its biggest face. Re-fitted with casing 0.029 and dish face 0.031: **50.2 /
50.5**, inside the 46-52 outdoor band. The dish's painted face came off the gen at **0.3225 linear,
11.7x the deck it stands on**. Both take `ao 0.5 / aoRes 128` — the fan well and the dish's
concavity are exactly what baked AO is for, at +0 draw calls.

**Verdict: landed, `ROOF_BLENDER = true`. Two fresh 1k sheets ($0.11), two meshes, −69.2k triangles
in one frame for no draw call. Warm asks `FacilityRoof.acPath()`/`dishPath()` so the flag cannot warm
one mesh and draw the other.**

## One texel density per prop: `unwrap`'s `scale`, and the 170x spread it replaces (2026-09-18)

Both authored roof props came back from the game with UV faults on named faces — the condenser's
louvred flank at the "wrong u,v scale", the dish's rim "different on each segment", a foot whose art
was not "aligned to center". One audit answered all of them. Per-triangle texels per world unit:

| prop | p10 | median | p90 | max | zero-area tris |
|---|---|---|---|---|---|
| roof-ac-hand before | 0 | 161 | 1,380 | 3,134 | 80 of 660 |
| roof-dish-hand before | 34 | 95 | 2,058 | 4,841 | 38 of 948 |
| both after | 80 | 95 | 97 | 181 | **0** |

Three causes, all in `buildlib`:

- **The aspect fit is isotropic but not consistent.** `tag`'s `+3` crops a rect until a face's two
  densities meet, and the window is all the art there is — so the density it lands on is
  `rectW / faceW` and every face gets its own. `unwrap` now takes `scale`: the caller names the
  model's largest extent once and every face asks for the slice that lands on `rect / scale`. It is
  `uvfit`'s contract, which the lathes already had, done for a flat face.
- **`reps` picked the wrong copy.** `floor(min(a) + 1e-9)` with `reps` equal to the turn count: each
  face spans exactly 1.0, its minimum is an integer, and `atan2` of an exact multiple comes back a
  few 1e-9 short — which `reps` multiplies to 1e-7. The floor went a copy low and every u clamped to
  1.0. All 20 facets of the fan cowl were a line. The midpoint of `[k, k+1]` is `k + 0.5`, which no
  float error reaches.
- **The fit's axis choice read extents, not the normal.** "UP goes on v wherever the face has any
  height" was implemented as `ext[2] > ext[oth]`. The two agree on every axis-aligned face and part
  company the moment a piece is yawed: a 0.30 x 0.05 side of a foot at 120° measures (0.15, 0.26,
  0.05), so 0.05 lost to 0.15 and a vertical face mapped over (x, y) — in plan a line, 16 zero-area
  triangles. `|n.z| < 0.5` is the question that was being asked.

Two script-side finds on top. The condenser's louvre took a hand-cut window fitted to a **mismeasured
sheet**: the note claimed 114 slats across the 512 cell, and the cell's row profile has a dominant
period of 34 px, i.e. **15**. The window put 47 px of art on 2.6 units (18 texels/unit); the cell
whole at `SCALE` shows 9.8 slats over 1.70 units, an 87 mm pitch. And `mirror` folds at t 0 and
t 0.5, so a seam that is not a multiple of `1 / n` puts both folds mid-face and those two facets get
the same u at both ends — `ring` snaps the seam to a vertex boundary.

Geometry, same round: the dish's yoke plates **came up through the reflector and out of its painted
face** (reported as the centre strut going into the dish). The plates were 0.34 deep and reached 0.10
above the axle, and the shell's back sat ON the axle. `HUB` stands the assembly 0.26 off it along the
boresight, `YOKE_T` drops to 0.18, and a hub boss bridges the gap — the plate corner that reaches
furthest forward now clears the back by 0.058. `MAST_H` is re-solved for the standoff and the old
`+0.0321` fudge is gone: it was exactly `SHELL * sin(ELEV)`, the rim's forward edge being at `DEPTH`
and not `DEPTH + SHELL`.

Cost: dish 948 → 888 tris (the feet's 6 mm arrises, deleted) + 36 for the boss; condenser 660
unchanged. Values re-audited at **49.6 / 50.2 srgb**, inside the 46-52 outdoor band, no retone.

**Verdict: landed. `unwrap(scale=)` and the two `lathe_uv`/fit fixes are in `buildlib`, so every
future hand-modelled prop gets one density for free. Zero smears on both props, spread 2.4x.**

## A roof cable is trunking, not a flex: 90° runs to an isolator box (2026-09-18)

Reported from the game: the roof wanted serious cables, at 90 degrees, in straight lines, running
from each unit to a small box shared by a few nearby ones — and not all the way around. Every word
of that was a fault.

`FacilityCable.strip` is the compound's one cable emitter and it is a **bowed, wandering, sagging**
ribbon, which is what a flex leaving a fitting looks like. On a deck it reads as something the wind
dropped there. And the tree that fed it chained each condenser to the nearest already-fed unit
starting at the hatch, so on the 21 x 30 building it walked the ring band end to end.

Replaced with `FacilityRoof.leg` / `run` / `jbox`:

- one flat quad per straight leg, the cable art's u across it exactly as `strip` lays it, and an L of
  two legs per run. A ribbon that never bends needs no steps, so a run is 2 quads a way against
  `strip`'s 10.
- `ROOF_CABLE_WAYS = 3` at `CABLE_W * 1.5` pitch. A single 6 cm ribbon at this camera is a hairline;
  three with half a cable of deck showing between them read as trunking, in the same buffer.
- condensers grouped greedily by manhattan distance **from the seed and not from the growing group**,
  so a group cannot creep across the deck one member at a time. One isolator box per group at its
  centroid, in the hatch's own buffer — a box costs no draw call.
- `ROOF_JBOX_REACH` is paced off `ROOF_PROP_STEP 5`, not off a bay: candidates are taken on a 5-cell
  phase, so two units in one bay measure 3 to 5 apart and never less. Measured on this compound's 15
  condensers — reach 3 gave **11 boxes**, i.e. a box each; reach 5 gives **7 at 2.1 units apiece**.
  `__facility().roof` now reports `boxes` beside `cables` precisely so that ratio is visible.

The access hatch went in the same pass, and it was two mistakes: 2.4 x 2.0 is 1.2 x 1.0 m, a real
roof hatch, so 1.2 units of height was 60 cm — four times a curb and half a doorway; and precast
`COPING` at `ROOF_TILE 9.0` put a ninth of one coping stone on each face, of art whose whole read is
the line it makes along a parapet. Now a 0.3 curb with a 0.1 lid on a 9 cm lip, in `BOOTH_ROOF`'s
painted steel decking — the one art in the compound that already **is** a lid. Zero new art.

Measured at the pinned roof pose, before/after: **calls 167 → 167, tris 293,430 → 293,298.**
15 runs, 7 boxes, 2 hatches.

**Verdict: landed. The whole family is two buffers it already had, so the shape got better for −132
triangles and no draw call. `cables / boxes` is the knob's own gauge.**

## A face's own frame, not a pair of world axes — and a strut that reaches its horn (2026-09-18)

Two reports off the dish, one in `buildlib` and one in the model.

**THE FRAME.** The game reported the dish's three feet again: two of the three were not "aligned to
center" like the one that looked right. `unwrap`'s aspect fit picks a pair of WORLD axes and maps the
rect over the face's bounding box in them, which is exactly right while a piece stands square to the
grid and is nonsense the moment one is yawed. A 0.30 x 0.13 foot turned 120° measures **(0.26, 0.32)**
in x and y, so the fit put u on y and v on x and the art ran DIAGONALLY across the piece; the foot at
0° got u on x and looked correct. Measured after: all three feet now take the identical rect,
**du 0.05595 / dv 0.02425** — the one the axis-aligned foot had.

The fix is `buildlib.frame(f)`: the face's own two in-plane directions, `v` = world up projected into
the plane wherever the face has any (so a vertical strip still wears the cladding the way the wall
beside it does), and on a flat face the face's own LONGEST EDGE on u — which for a rectangle is the
long axis the extent test was reaching for. Signs are pinned on the flat branch so two tops of one
piece cannot come out 180° apart. `unwrap` now projects onto vectors rather than indexing `p[ia]`,
so the axis pairs and the frame are one line of arithmetic. Per-triangle texels per world unit,
before → after: dish **2.4x → 1.7x** spread (76.3 / 95.4 / 96.0 / 128.6 at min/med/p90/max),
condenser 1.9x, zero degenerate triangles on both.

**AXES 7, the frame WHOLE**, fell out of the same work and is what `roofhatch_build.py` needed: a
pre-cut band mapped as it is, no density crop, because the caller has already sized the rect to the
face. The axis PAIRS cannot do that job — axes 1 is (x, y) and a vertical face has no extent in one
of them, so every loop lands on one v and the face comes out a line.

**THE STRUT.** Reported as a hole between the strut and the horn "for all four lines". It was
exactly that: the far end stopped at 0.12 of R off the axis — 0.1373 out, where the horn's cone
measures **0.064** — so the strut's own surface ended **0.045 short** of the piece it carries, four
times over. The comment above it claimed both ends were buried. The near end was no better: 0.02
into a 0.05 shell leaves **0.0005** once the end cap's own tilt is counted (a 53° cap on a 0.028 ring
spans 0.045 in z, and the mesh's front surface is a CHORD between two rings and so sits above the
paraboloid it came from). Now `STRUT_IN 0.03` at `FOCUS + HORN_L * 0.25`, inside a cone measuring
0.0843, and `STRUT_THRU 0.04` through the back where a real strut foot bolts. `run()` returns both
clearances — **horn 0.0262, thru 0.0182** — so neither can drift back.

**Verdict: landed. 888 tris, holes 0, coplanar 0, 49.6 / 50.2 srgb unchanged. The frame change is in
`buildlib`, so every future hand-modelled prop gets it; it is a strict improvement and only moves
faces that are not axis-aligned.**

## The roof clutter's cap was set against the drop, not against the deck (2026-09-18)

Reported as the roof clutter having albedo/brightness issues "again", with a puddle photographed
reading almost right from one angle and dark from another, and the question: what are we reflecting?

**Nothing. There is no reflection anywhere near it** — `FacilityRoof.pack` is a `MeshLambertMaterial`
with no envMap, and `PropEnv`'s injected environment is indoor-only. It is albedo, and the number was
already in the manifest: `facility/roof-clutter` carries `cells: {grid: 8, cap: 0.1}`, a per-cell
LINEAR cap that can only darken (`tools/textures.py` `cell_cap`), and **0.1 is 3.6x the deck these
lie on** (`facility/roof`, 0.0275 linear). The cap was fitted against the raw drop — chalk, bird
splash and efflorescence came back 0.15..0.36 — and not against the surface.

Measured on the built sheet before: **19 cells sitting at 0.0976..0.0978**, all of them the cap's own
ceiling, against a tar patch at 0.0194. Sheet mean over opaque pixels **0.0567 = 2.43x the deck**,
cell-to-cell spread **7.6x**, brightest cell's p95 **0.133 = 5.7x**. The puddle the game
photographed is cell 3, whose art is a dark pool with a bright rim — p05 0.032, p95 0.133 — so the
rim read as a white ring at any distance where it survived the mip, and the fill read as a hole where
it did not. Both halves of "good from some angles, dark from others", from one cause.

`cap: 0.03`, the deck's own value: **52 of 64 cells capped**, sheet mean **0.0245 = 1.05x the deck**,
spread **2.0x**, brightest p95 **3.4x**. Rendered, the same patch is now a dark pool with a faint wet
edge. One number and no new art; the cap can only darken, so the tar and bitumen cells are untouched
by construction.

**Verdict: landed, one manifest field. The lesson is the cap's own: it is fitted against the SURFACE
the cells lie on and never against what came out of the generator.**

## Nothing drawn twice: a shared trunk, and a lay per way (2026-09-18)

> Extends **A roof cable is trunking, not a flex** — the shape was right and the emitter overlapped
> itself.

Reported as a z-fight on all three ways of the new trunking. It was, and it was not close: an L per
unit means two units in one group lay **the same quad** along `x = bx + o`, and each L also covered
its own corner square twice. Measured on the compound's roof cable quads by intersecting every
coplanar pair: **88 quads, 84 overlapping pairs over 1.67 square units**. Two flat quads at one y
that overlap at all are not a near miss, they are the same plane.

Three changes, and the overlap is now exactly zero:

- `FacilityRoof.runs` builds the group's whole network as `Seg` records and emits at the end, because
  the fault is two quads covering one patch of deck and that cannot be seen one quad at a time.
- a **shared trunk** per way, spanning the box and every unit's row in one run, plus a spur per unit.
  The spur stops **half a cable short** of the trunk's centre line, so the joint closes on the
  trunk's own width instead of overlapping it.
- `seg()` merges a new segment with **everything** already on its line, not the first match: two
  units can share a row, and three can arrive as two disjoint runs and a bridge. Merged, the nearer
  unit taps the run passing it, which is what it would really be wired to.
- what no clipping can remove is a spur crossing ANOTHER way's trunk — the ways are parallel — so
  each way lies one `ROOF_CABLE_LAY = 0.02` higher than the last. A crossing is then a crossing,
  which is also what a real bundle does where two runs meet.

**64 quads, 0 overlapping pairs, 0 area** — fewer quads than before as well, since the trunk is one
run instead of one per unit.

**Verdict: landed. The same two buffers, 24 fewer quads, and the measurement is a one-line probe over
the live geometry rather than a screenshot.**

## Planted, not lit: the condenser does cast, and its own plan hides it (2026-09-18)

Reported as not all roof structures throwing shadows, the condenser in particular. It casts. The
measurement is what the entry is for:

- the deck's light is **66% moon** — turning the directional off took a pinned deck window from
  rgb 2.2/6.9/17.8 to 0.1/3.0/6.0 — so a shadow up here has plenty to remove;
- `Models.instanced` sets `castShadow = real`, which is true for `SOLID`, and the batch is inside the
  moon's 180-unit box at this pose;
- but the moon stands **48° up** and a condenser is **2.78 x 1.77 on the plan under 2.2 of height**,
  so the whole of its shadow falls under itself. Turning that batch's `castShadow` off changed
  **7,632 pixels of the frame by a mean of 1.1 of 255**. A 3.6-tall dish on a 1.5 pedestal clears
  itself and does throw one; nothing else on a roof has that aspect.

So the fix is the planted read and not the light: `FacilityRoof.pool` lays `FacilityDetail.pooled`'s
rounded-box field under every condenser, dish, hatch and isolator box, in a fourth per-deck mesh
pushed into `Shell.roof` so a shadow leaves with the deck it lies on. Simpler than the indoor one by
exactly its clamp — a pool on a shelf plate has to be cut where the plate ends, and a roof deck is
one continuous slab whose candidate cells are all two cells inside the parapet.

**THE WEIGHT IS IN THE RAMP AND NOT ON THE MATERIAL**, which is the one thing it cannot share with
that file: `FacilityArea.apply` SETS `material.opacity` from the deck's ease every frame, so a 0.5
left on the material is overwritten with 1.0 the first frame the player is outside.
`Textures.makeRectGlowGradient` took a fourth argument, `peak`, for it. `__facility().roof.pools`
must equal ac + dish + hatches + boxes exactly — live **26 = 15 + 2 + 2 + 7**.

**Verdict: landed at 1 draw call per deck. Outdoor props elsewhere have no contact shadow and do not
need one: they stand on lit asphalt and are taller than they are wide. A roof is the one surface this
camera looks down ONTO, and everything standing on it is squat.**

## A hatch is a box, and it went to Blender anyway (2026-09-18)

> SUPERSEDES the hatch half of **A roof cable is trunking, not a flex** — the curb and the lid are
> right, `BOOTH_ROOF` was not.

Reported twice on the same two objects: "make a new blender box with unique tex, not this shit" on
the access hatch, and "ffs, DON'T REUSE TEXTURES" on the isolator box. Both wore
`facility/booth-roof` at `ROOF_TILE 9.0`.

**THE BOX-VS-SILHOUETTE TEST CANNOT SETTLE THIS ONE, and that is the entry.** A hatch IS a box and
as ten quads it cost no draw call at all — the guard booth's own finding, 7,431 tris → 34. But a
merged mesh takes a **TILING texture on a world-aligned UV**, and that is what was wrong here: at
`ROOF_TILE 9.0` each face got a ninth of a kiosk roof's standing seam. A 1.2 x 1.0 m lid's whole read
is the tread plate ON it, seen by a camera pitching 51° to 86° down, and a plate pattern is a
**picture** of a lid: it has to map 0..1 onto that one face, which a glb's own unwrap does and a
tiling emitter cannot. So the route was never decided by the silhouette — it was decided by whether
the art can be world-aligned.

`roofhatch_build.py` **56 tris** (2.58 x 2.18 x 0.4) and `roofjbox_build.py` **88** (0.81 x 0.61 x
0.9), both `check` clean, both built AT the height their batch scales by so the plan the generator's
cells are measured against is the plan that draws. A fresh 1k sheet each, four cells for four
surfaces, toned by `rooftone.py` to **47.9 / 47.3 srgb** off drops that came back at 0.078..0.150
linear — 3x to 5x the outdoor band. Built glbs audit **49 / 49 srgb, 0 smears**. The hatch's curb and
the lid's drip band take PRE-CUT bands mapped whole (axes 7): a 0.3 face over a 2.58 `SCALE` is 11.6%
of the cell and a centred crop lands on plain field, where this art's fixing row is at row 465 of
512, and cell 2's rib slots are on an 82 px pitch so a 20 px centred crop lands inside one rib.

Cost, measured at the pinned pose against the same build with the new families hidden: **172 → 177
calls**. The two batches are 4 of that (two colour draws and two moon-shadow draws) and the contact
shadows 1. The merged `kit` mesh they vacate is deleted — they were the only two things in it — but
it was being frustum-culled at that pose, so nothing came back there. tris 293,298 → 293,964.

**Verdict: landed, and NOT behind `ROOF_BLENDER`: that flag switches between two glbs of one object,
and these replace merged geometry the game asked to be rid of, so there is nothing to switch to.
Two fresh 1k sheets, $0.11.**

## A duct segment is one cell long, so a run is placements and not a mesh (2026-09-18)

Phase 5a's three remaining roof families — an extract vent, a lagged duct run and an expansion tank —
`models-src/facility/roofsvc_build.py`, **172 / 220 / 236 tris**, all `check` clean at 0 holes and 0
coplanar pairs.

**THE DUCT IS THE ENTRY.** A run of ductwork is the first thing on this roof that is longer than the
thing it stands on, and the obvious build is a swept mesh in the deck's own buffer. It is a prop
instead, and it works because `render.Models.instanced` **scales a glb by HEIGHT alone**: a segment
built at exactly its stated height draws its stated length, so a segment built **4.0 long — one
`CityConfig.CELL`** — dropped on neighbouring cell centres abuts the next one with no seam, no
per-instance scale and no swept geometry. A run is then N placements in one batch, and `walk` picks
the direction out of the service bay with the most ring band in it, capped at `ROOF_DUCT_MAX 3` so a
duct cannot follow the band the whole way round the building — the fault the cable trunking was
reported for. The trap: `ROOF_DUCT_H` has to be solved against the **flange rings** and not the
jacket, because they are the widest thing on the segment; built against the jacket the measured
height came back 1.06 against a stated 1.0, which would have scaled every segment to 3.77 long and
opened a 0.23 gap at every joint.

**ONE SHEET FOR THREE PROPS**, which is new here — the dish, the condenser, the hatch and the jbox
each took their own. They are one material family and each of the four cells is the DOMINANT face of
a different one of them (cowl / lagging / structure / tank shell), so a single 1k gen at $0.055
carried all three where three solo sheets would have been $0.16. `rooftone.py` gammas 1.45 / 1.71 /
1.61 / 1.13 onto 0.028 / 0.030 / 0.025 / 0.029 linear off a drop at 0.084 / 0.123 / 0.100 / 0.043 —
sheet **0.0280 linear / 49.5 srgb**, built glbs audit **48.5 / 50.4 srgb, 0 UV smears**.

The cowl is mapped **radially and not wrapped**: cell 0's art IS a disc, so every sloping band of the
cap goes through `disc_uv` and only the rim — the one band at constant radius, where a radial
projection collapses to a line — is lathe-wrapped.

Placement reuses what was already there rather than adding a zone kind: the vents take the SERVICE
bay's other cells (a vent caps a shaft and a shaft comes up where the stair core does), and the tank
is `ROOF_TANK_PCT 22` of the PLANT bay's own cells — a plant bay with one vessel among its condensers
is a plant bay, a bay of vessels is a tank farm. The tank stays in `plant`, so the trunking runs back
to the same isolator box. Measured on this compound: **6 vents, 6 duct segments, 2 tanks, 13
condensers**, pools 38 = the sum of everything standing on a deck.

Cost at the pinned pose against the same build with the three families hidden: **177 → 183 calls**
(three colour draws and three moon-shadow draws), tris 292,652 → 295,476.

**Verdict: landed. One shared sheet, $0.055.**

## Phase 5d's two roof decals were dropped, not built (2026-09-18)

The plan carried two more flat labels for the deck — a drip/rust stain and a duct shadow scuff —
through `FacilityGrime`'s merged-mesh path. Put to the user with what already covers that ground, and
dropped: the `facility/roof-clutter` pack64 ships **64 cells of weathering** (tar patches, ponded
water, stains, chalk, anchor plates) laid over the whole deck at `ROOF_CLUTTER_PCT 12`, and every
family that stands on a deck already gets a `pool` contact shadow — which is exactly what a "duct
shadow scuff" would have drawn, at 2 triangles in a mesh that already exists.

**Verdict: dropped. A third flat family on one deck is overdraw, and the second of the two was
already built as a shadow.**

## A store room's furniture: three glbs, one pack64, and a frame row that was not free (2026-09-18)

Phase 6's render half. Three new fittings — `deco-pallet-rack` **356 tris** (3.9 x 1.8 x 4.2),
`deco-pallet-stack` **116** (1.8 square x 1.5) and `deco-drum-pallet` **376** (1.8 square x 1.4) —
`models-src/facility/storerack_build.py`, all `check` clean, plus `facility/store-clutter`, a fourth
pack64 consumed by the new `render/facility/FacilityStore.hx`.

**THE FRAME ROW IS THE ENTRY.** A fitting's identity is an `entities64` frame, and the free-looking
tail of row 49 is not free: `FacilityModel.findDeco` asks `Const.isTableDeco(row)` FIRST and sends the
whole row to the bench branch, and row 49 is in `CHEM_LABS_DECO_TABLE` (`amount: 4`, so 49/4-11 look
unused). A frame dealt there never reaches `fittingOf` — the three batches were built, the generator
placed them, and all three drew **0 instances**. They sit on row 18 now, one of the two stale 2D-era
document rows the clue pack retired, which nothing in the tree references and which is not a table row.

**The drum pallet does NOT reuse the shipped `drum-*-hand` glbs**, which the plan assumed:
`Models.instanced` keeps the FIRST mesh of a glb and drops the rest silently, so a pallet carrying
separate drum meshes is a pallet carrying one drum. The four drums are lathed into the same mesh.

**Values are fitted to the INDOOR band and not the outdoor one** — `storetone.py`, which is
`rooftone.py`'s bisection against a different number: `propstat --audit` reads the shipped fittings at
68.5 / 75.6 / 83.4 / 83.6 srgb, so ~78 is the target, and the drum sheet came off the gen at **0.0156
linear — 5x too DARK**, so its gammas are below 1 where every roof gamma is above it. Built glbs audit
**69.3 / 69.3 / 75.8 srgb, 0 UV smears**. The first pass aimed the dominant cell at 0.075 and shipped
65.1 / 64.7: the audit reads the whole atlas, so a sheet whose other three cells fall away under the
headline ships darker than it — the rack and the stack are fitted 15% over.

Two geometry traps, both caught by `buildlib.check` and `measure` rather than by eye: a foot plate
centred on its upright put the rack's measured width at **4.06 against a stated 3.9** (a 4% scale
error in every instance, since the batch sizes by height), and flush with the post it was 8 coplanar
pairs; and a 45° brace built standing on z 0 swings into y 0..-1.66 under `place`, so the prop
measured **2.59 deep against 1.8** until the translation put it back over the frame.

Cost, measured in a store room with the three batches hidden: **126 → 128 calls** (the rack and the
stacks; the drum pallet had no instance in that frame), tris 90,284 → 91,584. The clutter is one
merged mesh for the compound.

**Verdict: landed. Three fresh 1k sheets + one pack64, $0.22.**

## An arris wears its own piece, a picture is not a material, and a plank has a direction (2026-09-18)

Three faults reported off ONE prop — the store's pallet rack — with the game's own face dumps. Each
is general and each is now a rule somewhere that fires before the next build.

**1. An arris took the galvanised cell while the post it broke is painted orange.** Reported as "you
have that weird idea of making edges a different texture from the body, not the first time i see
that". `buildlib.chamfer`'s docstring already said the strip takes the piece's own rect; the caller
passed `strip=i_galv` anyway and every upright shipped outlined in grey. `part` no longer accepts a
strip index at all, and `docs/3d-models.md`'s chamfer bullet said "tag them with a plain swatch" —
which is what invited it — and now says the opposite in capitals. Other scripts still carry the
pattern (`roofsvc`, `roofhatch`, `roofjbox`, `roofac`, `roofdish`, `entry`, the four `I_PLAIN`
users); not rebuilt here, flagged.

**2. A 7 cm member can carry a COLOUR and nothing else.** Cell 0 of the rack sheet is a portrait of
an upright — a punched keyhole column between two flanges — and `unwrap`'s aspect fit crops about the
rect's CENTRE, which on a 0.14 x 4.2 post is a 1/30 slice straight through the keyholes. Reported as
"why do the struts all go through same part with holes, and u,v scale is weird". **Framing the whole
cell onto the face (`tag` axes 7) was tried, rendered and rejected**: 512 px across 0.14 units
against 512 up 4.2 is 30:1 and the holes come out as one black slit. THE ARITHMETIC SETTLES IT — at
`tex: 512` a cell is 256 px, so the post's face is **8 texels** wide. Both narrow members (post,
beam) now take the flattest 48-px band of their cell, measured by luma std (2.6 against the cell's
9.6 for the post; 2.04 for the beam, whose fold line was smearing along it). The punched art stays
in the sheet unused: the brief asked for detail the density cannot hold.

**3. A cell drawn with its planks running UP the image puts the grain ACROSS every board.**
`buildlib.frame` puts u on a flat face's longest edge, so a 3.6-long deck board wore its timber
sideways — reported as "looks like shelf texture should be rotate 90 degrees" and, on the pallet, as
the same fault on its sides. Turning the ART is one line in the tone pass (`rooftone.build` now takes
a fourth per-job field, the cells to `np.rot90`); turning the MAP would have been a fifth axes code
in `buildlib` and a per-face decision at every call site. All three store sheets' timber cells turn.

Two more off the same review: the rack decked only its bottom beam pair ("why no second shelf") and
now decks all three, and its foot plates were INSET 0.02 to hold the stated 3.9 width ("you sure this
should not be centered around the strut instead") — the post centre is now solved back from the
plate, so the plate is what measures RACK_W and sits centred under its own post.

Cost: rack **356 → 428 tris**, dims exact, `check` 0 holes / 0 coplanar, 0 UV smears. Albedo moved
with the re-tone: 69.3 / 69.3 / 75.8 → **77.4 / 75.9 / 77.4 srgb** against the shipped indoor
neighbours' 68.5 (drum) / 75.6 (sofa) / 83.4 (cabinet) / 83.6 (shelving).

**Verdict: landed. No new art, no new gen — one tone pass and one build script.**

## A store room's middle, and the pocket repair that could only open a one-cell pocket (2026-09-18)

"The storage room generator itself is incorrect, there should be much more 3d stuff." It was: a zone
is a WALL RUN (`RoomBlock.node` cuts the room's perimeter into bays), so every store was racking
round its four walls and a bare floor in the middle — and stores average 5x6, which makes that middle
**half the room**. Measured in game: **5 pallet racks in a whole compound**.

`FacilityRooms.storeIslands` lays rows across the room's SHORT axis, stepped along its long one —
a warehouse's own layout, bays across the width and the gangway down the length. Taken the other way
round it places nothing at all in every store 4 cells deep, which is 30% of them. Lines 2, 4, 6 …
off the edge: never line 1 (the perimeter line already carries the wall runs, so a row there stands
in front of its own racking) and never past n-2 (the far perimeter line keeps an aisle). Every row
leaves the door's own line bare as a gangway, **clamped off the row's two end cells** — on seed 2235
a store's door sat in its corner column, the gangway it named was the column a shelf run had already
filled, and a 3x2 pocket sealed behind it. A store too small for any row gets one pallet instead.

**AND THE POCKET REPAIR HAD A BUG THAT NEEDED THIS DENSITY TO SHOW.** `openPockets` took the pocket
in scan order and called `freeOne` on that one cell, which works only when the pocket IS one cell:
a 3x2 pocket's top-left corner has two bare-floor neighbours and no fitting on any hand, so the
repair gave up and returned. It now walks the pocket cells until one has a fitting beside it. Same
pass also learned the case where a fitting stands in the DOORWAY's own lane: the flood then has
nowhere to start, every cell reads as a pocket, and the old code returned instead of opening the door.

Render side, `FacilityDeco.rectOf`'s "no masonry on any hand" fallback was a flat `dir = 0`, which is
right for one thing standing alone and wrong for a row: laid along z, four 3.9-wide bays came out
facing ACROSS the run with a 2.2 gap between them. `runDir` asks a neighbouring cell of the same kind
which way the run goes, and the rect turns with it. And `FacilityClutter.slots` now dresses the
racking's three decks and the pallet stack's lid, the shelving unit's own multi-plate case — every
item a CRATE at `DECO_CRATE_BIG_*` (a pallet load, not the shelf's 27 cm carton) and no flat decals,
because the sheets this pass deals from are lab glassware and office paperwork.

Measured, one compound, two stores: pallet racks **5 → 17**, stacks 2 → 8, drum pallets 0 → 3,
`spawns/decoration` 171.1 → 179.0 per area over 600 seeds, `make gen seeds=3000` clean with
`storageSane`. **Draw calls unchanged at 3 for the three families** (151 → 154 with them hidden and
shown, one frame apart) — the islands are extra INSTANCES in batches that already existed and the
crates ride the cardboard mesh the lab's shelving already merged into.

**Verdict: landed. Two gen passes, one render fallback, one pre-existing repair bug fixed.**

## The fit's window: its size is the density, its position is the art (2026-09-18)

> SUPERSEDES the "flattest 48-px band" half of *An arris wears its own piece, a picture is not a
> material, and a plank has a direction* — the bands are right, `buildlib.sub` was the wrong way to
> reach them.

Reported off the rebuilt rack: "you have this nasty tendency to u,v map to a tiny spot or a tiny
sliver of a big texture. why do you do that and how can you stop doing that?" With the face dump —
a beam wearing **u 0.537..0.963 by v 0.086..0.088**, i.e. 440 px wide and **2 px tall**.

**Why.** `unwrap`'s one-density rule crops a rect to `faceExtent / scale` on each axis. That is
correct and is the whole reason every face of a model matches: a 3.6 x 0.16 beam against `scale` 4.2
asks for 86% of the cell's width by 3.8% of its height — 440 x 19 px. Nineteen is fine; the beam IS
19 texels tall. **The crop is taken about the rect's CENTRE, and the centre is where the cell's
feature is drawn** — the upright's punched column, the beam's fold line. The previous entry's fix was
to hand those two faces a PRE-CUT rect (`sub`, a flat 56 px band). The fit then cropped the BAND:
56 x 3.8% = **2 px**. One fault fixed with another of the same family.

**How to stop.** The window's SIZE is not a choice. Its POSITION is. `buildlib.at(rect, u, v)`
returns the same rect with the fit's anchor moved, `unwrap` clamps the window inside, and a plain
4-tuple still means "about the centre" — so nothing already built moves (checked: for `t = 0.5` the
new `window()` is the old arithmetic exactly). The rack's post takes `at(cell(0), u=314/512)` and its
beam `at(cell(1), v=88/512)`, the flattest 48-px bands by luma std, at **17 px and 19 px** — the
density's own numbers, only aimed somewhere useful.

**Same rule on a lathe, reported in the same message.** The drum's three profile bands each asked
`uvfit` for a slice as tall as themselves, which centres — so both 6-10 cm rolling hoops wore a
sliver of the hazard diamond the 1.0-tall body between them was already wearing whole. "These should
not map to tex center because of the symbol, better map to top and bottom." The profile's z now runs
straight onto the cell's v through `lathe_uv`'s own `v0`/`v1`, so a drum wears the picture of a drum
once, base to lid.

Rebuilt: rack 428 tris, drum pallet 376, dims exact, `check` 0/0, **0 UV smears**, audit
**76.8 / 75.9 / 76.4 srgb**.

**Verdict: landed. One helper in `buildlib`, no behaviour change for any prop that does not ask.**

## Racking is an ARRAY, so its zone is a block and not a wall run (2026-09-18)

"I thought about evenly spaced rows of racks. shelf-run sub-block should be a large block of shelf
racks." The previous landing bolted the rows on as a pass in `FacilityRooms` beside the zone tree;
this puts them IN it. `RoomBlock.glaze` pushes one extra node for a store — its whole floor, tagged
`TAG_FLOOR` — and `RoomZones.shelfBlock()` pins `SHELF_RUN` to it with a `must`. Every other zone in
that file is a BAY, one cell deep against masonry, because a worktop and a bank of machines are
things that stand against a wall; racking is not one of those. The block is pushed FIRST so the
breadth-first walk fills it before the wall bays it overlaps (the vent caps are pushed LAST for the
mirror image of the same reason), and `aisle()` / `optional()` gained a `!TAG_FLOOR` guard so nothing
else can claim it. `Quota`'s own filler then dresses the leftover wall bays with the store's list.
`FacilityRooms.storeIslands` is deleted; net -30 lines.

`rows()` lays every other line of the block, **1, 3, 5 … and never the room's own perimeter line**.
That last clause is not cosmetic: `FacilityConnect.connectRooms` repairs a room nothing can walk into
by CUTTING A DOOR, and a cut needs a walkable cell on the room side as well as the far one — racked
to the wall, a store whose doorway happens to open onto a dead end can never be repaired. Measured:
**20 unreachable stores in 3000 seeds with line 0 in, 0 with it out.** It costs nothing to look at
either, because the perimeter line is exactly what the wall bays are.

Measured, one compound: pallet racks **17 → 32** (5 before any of this), `nodes/shelf-run` 6.34 → 1.96
(one block, not six runs), `spawns/decoration` 179.0 → 181.8 per area over 600 seeds,
`make gen seeds=3000` clean.

**Verdict: landed. The rows are a zone now, not a pass beside one.**

## The alien-ship set piece: object props in a compound, and a map that carries three beats

The crash-landing scenario's ship, its console, its three install slots and its three "orange case"
ship parts all drew as 2D atlas sprites in a 3D compound — the ship as **six billboards of a drawn
saucer standing upright inside each other**, the console and the slots as the generic `?`
scenario-object sign. Three things had to be true before any of that could be art.

**The set piece was in the wrong room, and the reason is one tile id.**
`GoalsAlienCrashLanding.addSpaceshipStudyObject` found "the hangar" by scanning row-major for the
first `TILE_FLOOR_CONCRETE` cell. That was sound while hangar floor was the only concrete in a
compound; `FacilityRooms.roomStorage` now paints the same id, so the ship landed in a store room.
Measured live on area 4503: ship decoration at (45,3)-(47,4) inside room 102 role `storage`, **slot3
at (46,2) standing inside a `TILE_BUILDING` wall**, slots 1 and 2 on racking — while the shed at
(7,4)-(21,15), carrying a 5x5 study pad with a podium on it, stood empty. `AreaGame.getRect`
compounded it: a same-tile run-length over a hangar floor that is no longer uniform returned a ~3x1
stub, which turned the part-spawn arithmetic into `Std.random(-2)`.

Replaced with a derivation off `FacilityModel.fromArea` — `structures[].hangar` and `pads[]` — which
is the call `console.GoBlock` already makes for the same reason (the block tree is in-memory only, so
the saved grid is all there is). **The rewrite writes no tiles at all**, and that is what retires the
podium-destruction trap rather than fixing it: the pad is already unwalkable concrete, so the ship
needs no footprint, and `moveSpaceship` has nothing to repaint over the square `findPads` recovers
the podium from.

**The console and the slots go on the apron ring's CORNERS, and the cells are tested rather than
computed.** `HangarBlock` stands its machine banks on the four compass spokes and `FacilityHangar`
runs a cable from each to the dais rim, so a console on a spoke stands in a cable lane. And an
`EventObject` does not override `canActivateNear`, so one on an unwalkable cell is *unusable*, not
merely ugly — the ring is walked in a fixed order and the first four cells passing
`isWalkable && !hasObjectAt` are taken.

**`ObjModels` reached only the sewer.** The object-backed glb layer — solid/ghost/hull batches, the
yaw rule, the idle-motion and glow patches — was built by `SewerArea` alone; `FacilityArea` and
`WildArea` had empty `refreshObjects` and no props. Wiring it into both found three things worth
recording:

- **`build` bucketed placements by model PATH.** Harmless for as long as no two rows named one path;
  the moment two did, each instanced a batch over the other's cells as well and every one of those
  props drew twice (seen immediately, two canary rows sharing `deco-analyser`). Buckets are per ROW
  now — the row is what carries `h`, `sink` and the whole motion column anyway.
- **`build` placed at y = 0 with no ground sample.** Flat is right for the sewer and the compound and
  wrong for the wilderness, which is a height field; one `WorldCtx.floorYAt` call is a no-op in the
  two flat kinds and the difference between a ship on the ground and a ship buried to its rim.
- **`Actors`' `iconOff` is area-kind-blind.** It drops an object's sprite as soon as `modelFor`
  answers, and a model key belongs to the OBJECT, not to where it is standing. Every prop-backed
  object used to be immovable; a ship PART can be carried and dropped in a city, which never builds
  these batches — no sprite and no prop, i.e. invisible. `ObjModels.active` gates the three callers.

The four patch sites (two area kinds and their two warm scenes) went through one shared
`ObjModels.patchRow`: the chain extends the material's `customProgramCacheKey`, so a warm that orders
it differently warms a program the game never asks for. **Measured: facility program count rises once
at the first entry and is stable across a second full area build (113 → 113).**

**Three independently pulsing lamp families off ONE emissive map.** The ask was yellow, blue and
white, the entrance included. `PropShine` cannot express it and the reasons are measurable: it masks
a channel RATIO, and a ratio is ~1.0 for white and ~1.0 for a pale hull, so the white family is not
expressible as a key at any threshold — and a row carries one ratio and one colour, where this needs
three. `propstat` reads the ship's atlas at **chroma 5.3 against the >25 a colour-keyable prop
wants**, so the keys were never going to separate it anyway.

`PropGlow` gains a `lamps` column instead. The map is a **marker, not a light**: three
`tools/emissive.py` passes paint each family in a flat tint of its own, and the shader matches those
tints back by normalised hue, giving each its own colour, rate and phase. It costs no draw call, no
pass and no extra texture tap — `<emissivemap_fragment>` has already sampled the map and the block
reads the value it left in scope. `PropGlow`'s own header argues a painted map is the wrong answer
for these props and is right about the case it was written for (hand-painting into a shattered
TRELLIS atlas, and a map dying when the mesh is regenerated); neither binds to a supplied master that
is never regenerated and a selection that is geometric.

`--key` is new on `tools/emissive.py` and exists for this prop: **a box cannot separate interleaved
lamps.** The ship's yellow panels and pale discs share one equatorial band, so every box holding
either holds both. Keyed `warm`, that band resolves to 128 of 1787 boxed triangles and lands on the
**ramp doorway** — the entrance, found rather than guessed. Keyed `pale`, 276 triangles spread right
round the azimuth. Both report bleed 0.

**Two traps in that column, both silent, both cost a probe to find.**

- **Whether `emissiveColor` arrives decoded is not visible from the Haxe side.** Markers authored in
  linear sat 0.25 (amber) and 0.42 (cyan) from the sampled hue, so every family missed at any sane
  tolerance — and the failure mode is that the prop keeps its flat baked glow and simply never
  pulses. It took widening the tolerance to 3.0 (whole ship blows out: the block runs) and then to
  0.05 (nothing lights: the distances are large) to place it. The marker is carried in **both**
  spaces now and the nearer wins; the two spellings of one hue are 0.54 from the nearest other
  family against a 0.25 tolerance, so the min cannot cross-match, and a three upgrade that starts
  decoding cannot silently kill it.
- **`--modulate` moves the hue this column identifies a family by.** It multiplies the marker by the
  prop's own base map, which is not grey — measured, it left only ~a third of the dome's texels
  inside tolerance. Authored flat, all three families match 100% of the lit texels between them.

And the dome then shipped the white card `3d-render.md` already has a verdict on: boxed y 0.24..0.45
it was 7.5% of the ship's surface and 63.8% of the map's lit texels, which at a lamp's level is not a
lamp, it is the roof switched on. 0.31..0.45 is **94 triangles and 2.2%** — the cap alone, small
enough that flat is right for it.

**The art.** The ship is the supplied 584,186-tri master decimated to 5,999 (1 component, source
split 1.05x) at `tex: 1024` — the texels-per-TRIANGLE floor asks for 512 and is the wrong question
for a prop this size: measured at `h` 5.5 the saucer is 12.8 world units across and carries **338.8
u² of skin, which 1024 covers at 46.1 texels per world unit** against the ground's own 57. It carries
no `baseColor`: propstat's 0.52 suggestion is keyed on the 46-52 OUTDOOR family and this prop lives
on a hangar floor, where the repainted interior wants ~78 — which the raw bake (75/72/79) already is.

The case, the console and the slot are hand-modelled (`models-src/scenario-a/scenario_build.py`,
372/432/432 tris, `buildlib.check` 0 holes and 0 near-coplanar on each). The console and the slot wear
the **analyser's own** painted panel and port band — the same material at the same scale, which is
the only case the reuse rule allows — so neither carries a `baseColor` or a `lift`. Their SHAPES are
new, and that is the half that matters: `deco-analyser` is dealt into this very hangar's machine
banks two to four cells away, so a re-skin would stand one silhouette twice in one shed. A lectern, a
receptacle with its socket plate facing UP at the camera, and a cabinet: three reads.

**The case's colour took three passes and only one of them was the right knob.** The first drop baked
a burnt red-orange (rgb 189/64/13, g:r 0.34) and reading it as "too bright" led to a `lift` — a
GAMMA, so per-channel, which took it to 158/27/2 (g:r 0.17) and shipped a **red** case. `baseColor`
is linear and cannot shift hue, but at 0.50 it measured the rendered lid at rgb 71/4/6 in the shed:
an orange only stays orange while its green channel is clear of the quantisation floor, and a dim
interior is already spending most of the range. Neither knob could fix it **because the art was the
fault** — one `edit_image` pass moved the cells to 232/122/6, g:r 0.53, with headroom under them.
Then the level correction works.

**Verdict: landed.** The set piece is in the hangar, the ship stands on the podium the generator
carves for it, one case always lands in a store room when the compound has one, and the whole rig is
geometry.


## The alien ship: 100k triangles, a deck to stand on, and lamps that are actually lit

Six reports on the set piece that landed in the previous entry, five of them numbers rather than
opinions. Taken in the order they cost.

**"I see no glow on the ship, something broken."** Nothing was broken. The `lamps` column compiled,
the uniforms carried sane values and the clock ticked — probed from CDP, `propLamp*` all present in
the drawing program. The whole table was simply tuned under the one number that makes a lamp read:
`base` ran 0.25-0.35 against glows of 0.55-2.2, so **every family's PEAK was below `BLOOM_THRESHOLD`
0.9** and what was left was the marker map's own 0.35 floor. `base` is 0.90 on all three now:
amber peaks at 1.98, the discs cross 0.9 in both directions (0.77 → 1.71), the crown at 1.44. The
lesson is the preservator's, one level up — a pulse that never crosses the threshold is a shade, and
a peak that never crosses it is nothing at all.

**The crown was a white card twice.** A box over the whole cap is 2.2% of the ship's surface and
looks right on `--preview`, and it still shipped a flat lit dome, because the cap's albedo is
**bimodal**: 88% of it is dark navy shell at luma 66-89 and the rest is the white glass set into its
top at 185-250. The fix is a **luminance GATE** on the mask (`models-src/scenario-a/spaceship_emissive
.py`, threshold 140) keeping 2,171 of 17,494 texels — the lens alone. A threshold and never
`emissive.py --modulate`: modulation multiplies the marker by a base map that is not grey and moves
the hue the shader identifies a family by. Same trap, same page as last time.

**The ship floated in the wilderness and over the podium, and it was ONE bug.** `sink` is a property
of the ROW, so the negative sink that lifted the ship onto the dais lifted the wilderness one 3.07
units into the air as well — and it was the wrong number anyway: `PODIUM_H` 3.07 is the eight emitter
POSTS, while the deck a thing stands on is the lathe's upper step at **1.15** (`podium_build.py` H1,
6.2 of radius). So the row's `sink` is 0 and `ObjModels.build` takes an optional `lift(col,row)` the
area kind supplies — the compound answers `PODIUM_DECK_H` for the 3x3 core of a pad, since a cell
centre one out on the diagonal is 5.66 from the middle and so still on a 6.2 deck. Measured after:
instance y 1.15 in the shed, and exactly `floorYAt` on a hillside (0.182 against terrain 0.182).

**100k triangles and the 2048 atlas kept**, both asked for by name: 584,186 → 99,998, the compound
98k → 276k triangles, 60fps held. At that size the saucer's ribs and legs are geometry rather than a
normal map's suggestion.

**The console's screen, and why a rectangle over it is wrong.** `PropGlow`'s lamp term is FLAT over
every texel it matches — the match is on hue alone, so a marker painted dark still lights fully — and
a marker over the whole bezel therefore paints the readout out and ships a magenta card (it did,
first try). The map is thresholded on the art's own value instead: glyph strokes and scan lines run
over 96 against a field in the fifties. The same map carries the port cell's socket bores, which is
what lets a slot glow at all.

**The rig's leads** (`render/facility/FacilityRig.hx`) are `FacilityCable.strip` at the machine fan's
own height in violet, from the console and each slot to the dais rim. Brightness is a MATERIAL
property, so "brighter once the part is in" is two meshes and a rebuild rather than per-vertex data:
the scenario rewrites a filled slot's `infoID` (which also stops the action table offering a second
install), calls `updateObjects3D`, and the run moves into the lit half. The slot prop follows the
same id onto a second `ObjModels` row — two rows on one model, which the per-row bucketing from the
last entry is what made legal.

**One silent trap, and it cost a frame to see.** `render.Chunks.build` REPARENTS what it finds into
per-chunk groups, so a mesh built before that pass is no longer the scene's child and `scene.remove`
is a no-op — the first build's cables stayed in the frame beside the rebuilt ones. Rig meshes are
pushed onto `pre` (chunks skip them, which is right anyway: their geometry is world-coordinate on a
mesh standing at the origin, so bucketing by position says nothing) and `dispose` unparents off
`o.parent`.

**Verdict: landed.** Ship on the deck, three families lit and out of phase, a lens on top, violet
leads that brighten as the rig fills, and an orange case with a moulded X you can pick out across a
shed.

## The emissive selection is PAINTED IN THE GAME, and what it exports is triangles (`render/PolyPaint.hx`)

> SUPERSEDED by *The emissive brush paints TEXELS, and the game writes the png*

Reported as "random glowing blue patches I have zero clue where you got from", and that is exactly
what they were. The alien ship's map is not art — measured, it is 97.05% pure black plus three flat
tints — so all it encodes is which triangles belong to which `PropGlow` lamp family. It was picked
offline by a bounding box on the triangle centroid narrowed by the triangles' own baked albedo
(`emissive.py --box --key`), because a supplied master's atlas is a shattered mosaic and cannot be
hand-painted. **A luminance threshold has no idea what a lamp disc is**: the `pale` pass kept 4,983
of 31,824 boxed triangles on a number fitted by eye on a 3-view preview.

There was also no way to fix it. Paint a PNG → `make models` → launch → see the fault in 3D → work
backwards through a mosaic atlas to the texels that caused it, which has no answer.

**So the selection is made on the prop with the mouse, and only the RASTERISATION stays offline.**
Debug key `T` inside street-debug mode: hover a prop, its `lamps` families become the palette, LMB
paints, RMB erases, wheel resizes, `C` cycles the family, `Z`/`R` undo. The emissive `Texture` is
ONE shared object (`Models.cache` is keyed on path, SOLID uses the template material directly and
GHOST is a `clone()` that copies maps by reference), so `tex.image = canvas; needsUpdate` reaches
the solid batch, the ghost batch, the warm scene and every area from one write.

**THE UNIT IS A TRIANGLE AND NOT A TEXEL, which is the whole design.** `emissive.py` already defines
a map as a triangle set rasterised conservatively into UV space with its gutter dilation masked
against every unselected triangle — the `bleed 0` gate. An index list feeds that bake exactly where
an exported PNG would bypass its one check. It is also resolution-independent, ~15 KB, and makes
erase, undo and re-seed free, because the canvas is a pure function of the triangle → family map.
At ~10 texels per triangle here, a triangle already IS a fine brush.

**Index parity was proven, not assumed** — the one load-bearing assumption. Re-baking the OLD box+key
selection as explicit indices through the new `--tris` reproduces the shipped map **texel for texel**
(amber 13,937 identical, cyan 14,768 identical), and every triangle the in-game readback classified
is a member of the python selection (646 ⊂ 1,228, 2,559 ⊂ 4,983, **zero strays**). So three's
`faceIndex` and `emissive.py`'s `i → indices[3i..3i+2]` are one numbering.

**Reading a shipped map back recovers only half of it, and that is the map's fault.** Seeding a
session by classifying each triangle against the PNG got 52%: the bake's `kept = lit & ~grow(other,1)`
leaves ~3 lit texels on a 10-texel triangle, so half of them light nothing. Four probe points got
44%; a strict per-texel inside test got **fewer** (503/1,903), because the bake dilates 2 texels
OUTWARD and half of what a triangle lit sits outside it. Growing the triangle 1.5 texels first got
646/2,559, which is the ceiling. When the exact prior selection matters, generate it offline and
write it into `localStorage['emispaint']`.

**Two families, not three.** The near-white crown lens is deleted: white is the hardest marker on
this prop (bimodal cap albedo, navy shell 66-89 against glass 185-250, so every selection of it
needed a luminance gate on top) and two lamps plus a white one read as a light show. `lamps.list`
3 → 2 is the one thing that recompiles — `PropGlow`'s cache key carries `'L' + count`.

**THE BLEED GUARD WAS EATING THE MAP, and that is the second half of this entry.** The first bake
off a painted selection rendered as an unlit ship. Not the selection and not the shader — measured
live: uniforms correct, map embedded and correct, a texel-level diff of the baked map against the
tool's own canvas agreeing on 38,390 of ~48,000 texels. The cause is `kept = lit & ~grow(other, 1)`:
it protects EVERY unselected triangle equally, which is right for a mosaic atlas where a dilation
can land on an unrelated part of the model, and much too strict for a 100k-triangle mesh at a 1024
map. At ~8 texels per triangle almost every texel of a selected triangle is within one of the hull
triangle it shares an edge with, so **it ate more than it kept: 1.098% against 1.637% lost**.

Doubling the map to 2048 was tried FIRST and is the negative result worth keeping — 1.098% → 1.213%
kept, and on screen it moved nothing. The fix is `emissive.py --near`: exempt the unselected
triangles that SHARE A VERTEX with the selection, keep the zero gate for foreign ones. One texel of
glow on the hull a lamp is set into is invisible; a speck on the far side of the model is not.
Measured: amber **1.333% → 2.601%**, cyan **1.098% → 2.067%**, foreign bleed still 0, 764 and 1,293
touching triangles now allowed to catch a texel. After it, a clean-reload A/B of the baked map
against the tool's canvas at one pose renders the same, which is the property that makes the preview
worth painting against.

**The canvas is still a PREVIEW** — whole triangles plus a hairline stroke, no conservative raster —
so judge WHICH triangles there, and the bake for how much.

**Knock-on: the `#help` block follows the focused tool.** It was one hardcoded string listing every
key of every mode; each tool now registers its legend on `Tools.legend(mode, text)` and `Debug`
swaps it on `setMode`, appending the lighting keys that fire in every mode.

**Verdict: landed.** Bind 97-222ms on a 100k-tri prop (centroids + normals + the seed pass), 10-18ms
per mousemove (dominated by three's own raycast into 100k triangles), 1 extra draw call for the
selection overlay, debug mode only. The wheel and the family key re-cast at the cursor rather than
waiting for the next move — a brush whose ring and selection only caught up on the next mousemove
made sizing it a guess.

**Open, and recorded because it was chased and not found:** mid-session, frames were captured in
which this selection lit the whole rim in bright cyan, far past anything the baked map or the canvas
produces after a clean reload. It did not reproduce — same pose, same map, same uniforms — through
mipmaps off, tolerance widened to 3.0, a colour-space check, the texel diff above and a 3D overlay
of every painted triangle. The `--near` numbers stand on their own; that observation does not, and
the ship as it now ships reads as two small amber vents and a few rim specks.


## The emissive brush paints TEXELS, and the game writes the png (`render/PolyPaint.hx`)

The triangle brush shipped and read wrong — faceted blobs, every lamp bleeding over the panel it
sits in. Three numbers say why, and all three are properties of the UNIT:

- `propstat`: **41 texels/tri at 2048**, so at the emissive map's 1024 a triangle was about **3
  texels across**. A triangle-sized brush IS that chunkiness.
- `emissive.py`'s bleed guard `kept = lit & ~grow(other,1)` ate **1.637%** of this 100k mesh to keep
  **1.098%**, which is what forced `--near`, which then lit every triangle merely TOUCHING the
  selection.
- The shipped map carried **893 texels of `e0c8e0`** — `ImageChops.lighter` compositing amber over
  cyan where their dilations met. Normalised-hue distance **0.73** from amber and **0.62** from cyan
  against `tol 0.25`: it matched *no* family and glowed as nothing but faint baked emissive.

**The brush is now a world-space CAPSULE resolved through the geometry.** For every triangle the
sweep reaches, its UV triangle is rasterised and each covered texel is back-projected by barycentric
interpolation and tested against the capsule. Not a disc around `intersection.uv`: a TRELLIS atlas
is a shattered mosaic, so a UV disc spills into unrelated charts — the original bug in a new hat.
A capsule and not a sphere because one mousemove can jump further than the brush is wide, and the
alternative (re-raycasting the gap) is a 100k-triangle intersect per step.

**Hard-edged, and that is a shader fact.** `PropGlow.hx:559` adds `propLampCol[i] * lw * base * beat`
with no `lmx` and no `emissiveColor` factor, and `lhue = emissiveColor/lmx` is invariant under a
scale toward black — a half-opacity texel lights at FULL until it drops under `lmx > 0.004`, one
8-bit step. Feathering buys nothing; blending BETWEEN families lands in the dead band where both
`tol` shoulders miss, and both families accumulate, so nothing picks a winner. Exact hue or exact
black, written with `putImageData` (which does not composite) and never `fillRect`.

**The bleed guard is deleted, not tuned.** SAVE grows each family 2 texels into the GUTTER ONLY —
texels no triangle covers, from a one-off conservative cover of all 99,998 — so foreign bleed is
zero *by construction*, and unlike `kept = lit & ~oth` nothing painted is ever removed. Map went
1024 → **2048** to match the albedo. The seed is the old triangle selection rasterised at ss=1 with
no outline and no dilation (amber 1.831%, cyan 1.479%, **zero stray hues**); `emissive.py --tris`
would have produced it too but spends ~25 min per family rasterising 96k unselected triangles at 4x
supersample for a subtraction `--dilate 0` reduces to a one-texel trim.

**WYSIWYG at last.** `models.mjs` embeds `emissiveSrc` verbatim, so the game now writes the shipped
png itself through `host.debug.writeImage` — the channel `map/Image.hx` already used, so no IPC was
added — and puts the dilated result on the prop, meaning the frame after a save *is* the ship. The
seed classification that recovered only 646 of 1,228 and 2,559 of 4,983 is gone: the state is one
`ImageData` copied texel for texel off the shipped map.

**The cursor lagged, and it was `intersectObjects`.** Measured **9.41ms per raycast** against this
99,998-triangle prop — three has no BVH, so a hover was a whole frame, and an unthrottled mousemove
fires more than once per frame. Two fixes: the bound mesh is now intersected by hand (reject on the
per-triangle bounding sphere already built for the brush, Möller-Trumbore on the survivors, nearest
positive t) and every mousemove is coalesced into one `requestAnimationFrame` update. The
whole-scene search that finds a prop to bind is left on `intersectObjects` and throttled to 10Hz,
because it happens once. After: median frame time **16.6ms idle / 16.7ms hovering / 16.7ms
painting** — vsync-locked, the tool costs nothing measurable. The 2048 upload per painted frame is
not a problem either, which is why the dirty-rect `putImageData` was worth having.

The hover overlay was dropped on the owner's call: with edits landing on the texture instantly the
paint IS the feedback, and a chunky triangle highlight over the texels being judged was in the way.

Verdict: **KEEP.**


## A violet lamp needs twice a cyan one's `glow` to halo (`render/world/ObjModels.hx`)

"I asked for purple glow on the consoles, I wanted bloom and animated — pulsating; I don't see
either." Both halves were true, and neither was a broken path: the whole lamp table was simply
tuned under the one number that makes a lamp a lamp here, the same failure the ship's own first cut
had.

**Bloom thresholds on LUMINANCE, and violet is the worst colour for it.** The composer renders into
targets where three forces `NoToneMapping` (ACES runs once, in `OutputPass`), so `UnrealBloomPass`
sees raw linear values and highpasses `dot(c, 0.2126/0.7152/0.0722)`. The lamp colour `0xc07bff` is
linear `(0.521, 0.198, 1.0)` — luminance **0.3245**, against the ship's cyan `0x63d6ff` at
**0.5794**. Green carries 72% of the metric and this hue has almost none, so the same `glow` buys
this prop a little over half the halo. Peak = `0.082` (the marker's own `emissiveStrength 0.35`) +
`0.3245 * glow * base`:

| | glow before | peak lum | glow after | peak lum | trough lum |
|---|---|---|---|---|---|
| console screen | 1.2 | 0.43 | **4.2** | 1.31 | 0.57 |
| empty slot | 0.7 | 0.29 | **4.5** | 1.40 | 0.67 |
| filled slot | 1.5 | 0.52 | **6.0** | 1.83 | 1.22 |

`BLOOM_THRESHOLD` is 0.9. Every one of the three peaked between a third and a half of it, so nothing
crossed and nothing haloed — measured in the frame as a 163..207 sRGB core with no halo at all.
After: a violet halo an eighth of the prop wide, and the lit-pixel count over the console swings
**319 ↔ 545** across its breath. Console and empty slot cross the threshold BOTH WAYS, which is the
difference between a pulse and a shade; the filled slot floors at 1.22 and haloes steadily, which
is the whole of how "a socket carrying something" is said.

**A small feature needs more headroom than the arithmetic suggests.** The console's screen crossed
convincingly at peak 1.31; the slot's socket plate is a third the pixels and read as a bright dot
with no glow at the same level — `UnrealBloomPass` downsamples, and a 6x3-pixel source is averaged
out of its own mip chain. The slots were taken to 4.5/6.0 for that reason alone, not for the
metric. Same trap as `TacticalGrid.GLOW`'s 5.0.

**The rates were also below the reading threshold.** `pulseRate` is radians per `BASE_MS` unit, so a
period is `2*pi / (rate * 6.667)` seconds: the console's 0.13 was a **7.3s** breath and the empty
slot's 0.07 was **13.5s** — slower than a player looks at one thing. Now 0.29 (3.2s), 0.15 (6.3s)
and 0.55 (1.7s), which sit either side of the ship's amber (5.5s) and lamp discs (2.3s) and under
the leads that leave the console (`RIG_CABLE_RATE` is CYCLES per unit, not radians — 1.4s).

In the same pass the four props moved a tile inward onto the study pad's own unwalkable corners
(`scenario/GoalsAlienCrashLanding.hx`), so they read as the ship's rig rather than as furniture
parked near it. That costs them their own cell, which `objects.EventObject.canActivateNear` and an
eight-neighbour scan in `game.PlayerArea` pay for — `getObjectsInRadius` is euclidean, so its
radius 1 was the four compass cells and a diagonal (distance squared 2) fell outside it.

Verdict: **KEEP.**

## The fake cast shadow was rooted on the cell, and never saw the animation channel (`render/actors/LampShadows.hx`)

Two reports off one function, `LampShadows.actorShadow`.

**It was rooted on the CELL, and the sprite is not drawn there.** `Sprites.paint` leans every
upright quad back by `TILT` 0.6 rad **about the quad's own centre**, so the content bottom — the
part that reads as standing on the floor — swings toward the camera by its drop below that centre
times `sin(TILT)`. Measured live off the built scene by recovering each shadow's root from its
quad (`feet = position - localY * scale.y * SIZE * 0.5`): every root sat **exactly on its cell
centre** before, and sits **+0.847 in z** after, which is `SIZE * 0.5 * sin(TILT)` for a
silhouette whose content reaches the cell's bottom edge. That is 21% of a cell of visible gap.

The expression is not new — `FacilityDeco.poolOf` computes it for a bench decoration's contact
pool and `FacilityStyle.TABLE_POOL_DZ`'s note records the same fault being reported once already
("the pool was at the cell centre and the object was drawn ahead of it"). It is taken off the
silhouette's OWN alpha box and not off a constant: `Sprites.shadowContent` was building its
`GroundSprite` with `by: 0.0` and throwing the real content bottom away, so that had to be carried
through first. The blur pad is symmetric, so it moves the content against the CANVAS and not
against the atlas cell — `base.by` still holds. Measured: the player's host sprite is 0.156 (glue
0.582); the lab's wall fittings are 0 (glue 0.847), which is why every caster in one frame read
the same number.

**And `render.anim.Effect` was read in exactly one place.** `a.fx`'s world offset is laid over the
billboard in `Actors.drawActor` and nowhere else, so through a `Lunge`, a `MeleeLunge`, a `Shake`
or a `Leap` the sprite slid across the tile while its shadow stood still on the cell it started
from. `offx`/`offz` are added now. `offy` deliberately is not — a leaping actor's shadow belongs
on the ground it left — and `fx.scale` goes with it, because `CastShadows.project` has no scale
channel and a `Pop` lasts 200ms.

Costs nothing: same quad count, same material, two adds and a cached multiply per caster.

Verdict: **KEEP.**

## An L-shaped desk corner was a SQUARE, and `closes` was a boolean where an interval belonged (`render/facility/FacilityTables.hx`)

An office desk is a thinner bench: `FacilityTables` cuts `CELL - DESK_D` = **1.4** off the hand away
from the wall its run backs onto. At an L corner that rule refused to cut at all — `openHand`
returned -1 because the open side carries the other arm — so the corner cell stood as a full **4.0
square** while both arms came forward only 2.6. The excess is the far quadrant, **1.4 x 1.4**,
poking past the front of both runs, and it was reported from the game.

Cutting it on ONE hand is the fault the -1 was written against (a 1.4 slot of bare floor between the
two runs, `docs/3d-render.md` "the corner fills and the L is one piece"), so the answer is neither.
**It is cut on BOTH, and the piece that joins the arms goes back as a second rect.** A cell is a
LIST of rects now (`slabs`): one for a plain or a thinned cell, two at a corner — the leg pulled
back from the first hand, plus the stub filling the strip it gave up as far as the second hand's own
cut. Their union is the L and they do not overlap.

**The pair is taken only where a SECOND, PERPENDICULAR wall says this really is a corner.** One wall
with a bench on its open side is the 2x3 block the generator also deals, and cutting that opens the
same slot down its middle — so `openHands` returns two hands only when both walls are there and both
open sides carry a bench. Measured on one compound: **1 cell in the whole map** matches.

**And `closes` had to go, because it answers a boolean where the question is an interval.** It asked
the neighbour's `openHand` and skipped the whole face when the neighbour "reached" the boundary —
which over-emitted a buried panel wherever a neighbour thinned on the OTHER axis reached only
`DESK_D` of it, and could say nothing at all about a face half-covered by this cell's own other
rect. `exposed` subtracts what really meets a face — the neighbour cell's rects plus the sibling —
and emits the strips left over; a face fully met emits nothing, which is all `closes` ever said.
Downstream reads the same oracle unchanged (`FacilityClutter`'s roll depth and `FacilityWork.chairs`
both call `openHand`, which is now `openHands()[0]`), so at a corner the clutter and the seat move
onto the 2.6 rect with the geometry instead of staying on the 4.0 cell.

A/B on one pinned pose: **2,306 pixels changed by more than 25**, all of them the corner and its
chair; `tris` 251.9k → 251.8k, `calls` 245 either side, `progs` 125.

Verdict: **KEEP.**

## The bookcase's lid wrapped inside its own sheet cell (`tools/modelsheet.py`, `models-src/facility/bookcase_build.py`)

The bookcase is a glb (`DECO_BOOKCASE_GLB`), so the seam reported on its top was not a UV bug in the
emitter — it was **baked into the model's texture sheet**.

`tools/modelsheet.py` pre-tiles each built game texture into its sheet cell at the period the
emitter used to lay. The lid's was `BC_W / DECO_BOOKCASE_TILE` = `2.0213 / 1.4` = **1.4436**, so the
cell holds one and a half copies of the swatch and the tile **wraps once inside the cell**. Measured
on `models-src/facility/bookcase-sheet.png` cell 2: per-column mean `|diff|` peaks **5.83 at column
354** against a cell background of 2.35, and `512 / 1.4436 = 354.7`. The swatch is itself a crop off
`facility/deco-bookcase-pack.png`, and a packed quadrant's wrap error is roughly double a solo
roll's (`wrapH 6.07` against an interior column gradient of 2.64), so that line ran the full depth of
the lid — which at this camera's 51 degrees is half of what a bookcase shows.

Repacked at **1 x BC_D / BC_W = 1 x 0.6234**: one repeat both ways, so no wrap is ever drawn. The
server rack's lid already records this answer (`facility/deco-rack-top`, `u 0..0.75, v 0..1`). After:
the lid cell's peak column is **2.81 against a median of 1.98**, i.e. texture and not a seam. It
costs density — one period is 2.02 world units instead of 1.4, a **1.44x coarser grain** — which is
the rack's own trade.

**The glb did not need re-exporting, and that is worth recording.** Its embedded base colour was
verified **byte-identical** to the packed sheet, and the lid maps its cell 0..1 whatever the cell
holds, so the UVs are untouched: `art/models.json` grew `texSrc: facility/bookcase-sheet.png` and
`tools/models.mjs` swapped the map at bake time (540 -> 540 tris). That also fixes a foot-gun —
without `texSrc` the manifest's `srcMtime` never sees the sheet, so repacking it rebuilds nothing.

The emitted fallback behind `DECO_BOOKCASE_GLB = false` carried the same fault from the other end
(`FacilityGeom.cap` phases its UVs off the WORLD) and now takes `localCap` at `DECO_BOOKCASE_W`, so
both routes lay the lid the same way.

**Not fixed:** the flank is packed at `0.9 x 2.4` and wraps twice in v, with comparable error
(`deco-bookcase-side wrapH 4.92 / wrapV 6.09`). Not reported, and its repeats are up a vertical face
rather than across the one horizontal surface the camera reads.

Verdict: **KEEP.**

## The per-kind warm gets the boot screen too (`GameScene.hx`, `render/View.hx`, `Main.hx`, `app.css`)

The boot warm was split by area kind so a session pays only for the art it reaches: the city warms
at boot and the tunnels and the facility each warm on the FIRST entry to that kind
(`View.warmKind`). The screen did not come with it. A first facility entry is **~1.7s of blocked
main thread** (measured here at 2.6s and 8.1s on a cold driver cache) and it runs inside
`GameScene.draw3D`'s `fader.cover` callback — i.e. behind plain black with no readout, which is the
exact complaint the boot screen was added for ("The boot warm gets a SCREEN, because it was never
invisible").

So `#warmup` is **hidden and no longer removed**: `Main`'s reveal puts an `off` class on instead of
calling `w.remove()`, and `draw3D` takes it off again around the warm, putting it back on the same
beat the fader lifts. The screen sits at `z-index: 100000`, above `#fader`, so hiding it uncovers
black that is already fading out — no second cut.

**It is asked BEFORE it commits, and that is the whole of the new API.** `View.needsWarm(kind)` is
`warmKind`'s own guard lifted out (`warmKind` now calls it, so the screen and the work cannot
disagree), because a kind already warmed is a straight call-through and a screen for it would be a
flash. Traced live off the element's `className` through one facility entry: `"ready off"` ->
**`"ready"` at +103ms** -> `"ready off"` at +2699ms, and `needsWarm` afterwards reads
facility/city/wilderness `false`, sewers `true`.

**Still not covered, deliberately:** a second area of an already-warmed kind still pays for any glb
only that layout places, and the wilderness has no warm scene at all.

Verdict: **KEEP.**

## Gnats over the park lamps, for four draw calls and no new code path (`render/actors/PropFX.hx`)

A `PropFly` row is written entirely in FRACTIONS OF ITS PROP'S HEIGHT, so a lamp mast is just a very
tall prop: `PropFX.drawFlies` takes `FacilityStyle.LAMP_H` and puts the ring under the head. That is
the whole feature — same stateless swarm (every dot's radius, height, speed and plane tilt rolled
off a hash of the cell and its index, so nothing is spawned, stored or despawned), same pooled
additive quad, same material as `Sprites.glowQuad`, already in the boot warm. `progs` did not move.

**Only the PARK's masts get them.** `FacilityLamps` already separates them — the lit-line scan
collects `parkHits` through `FacilityModel.isParkPath` before merging into `hits` — so the set is
carried out on `LampSet.park` as the same `LampPost` objects. **No field was added to `LampPost`**:
it is shared with the city and the tunnels, and one area kind's atmosphere is not worth a field
every construction site has to set. `Area3D.flyLamps()` returns `[]` for the other three kinds.

**Every pooled quad is a draw call and that is the entire design constraint** (measured previously:
21 dots took `calls` 88-90 to 109-111, exactly +21). So `trail: 0` — a trail multiplies a swarm by
`trail + 1` — and the feature is capped at `posts` 2 x `count` 4, gated on player distance the way
`LampLights` gates its pool. A/B/A/B on one pose, one mast in range: **`calls` 98 / 102 / 98 / 102,
`tris` +8**, perfectly repeatable.

Tuned once off the frame: at `tilt 0.55` / `yVar 0.07` the dots fell away down the pole and read as
separate sparks; `0.45` / `0.06` at `y 0.88` gives `r * sin(tilt)` = 0.34 either side of a centre at
5.2 of the 5.9 mast, so a dot laps from just under the hood to level with it. `rate 0.9` is five
times the arch's — an insect's orbit is frantic where an organ's is slow — and `twinkle 0.7` keeps
each one blinking out of the light and back into it.

One coupling fixed on the way: `PropFX`'s clock was advanced INSIDE the `PROP_FX.enabled` gate, so
turning the props' FX off would have frozen the flies mid-air. It runs unconditionally now; the
flies have their own switch.

Verdict: **KEEP.**

## Tactical mode paints an arrow at every door in the window (`render/TacticalGrid.hx`)

> SUPERSEDED (the SIDE half only) by *The door arrow moves onto the doorway tile and grows a second
> head*. The mesh, the material and the axis reasoning below all still hold.

`TacticalGrid` already owns exactly the right mesh — one `BufferGeometry` of thin ground quads, one
HDR-tinted `MeshBasicMaterial` at `GLOW 5.0` over the bloom threshold, rebuilt only when the
player's cell moves, hidden with the HUD — and an `addSeg` that lays a widened ground quad carrying
per-endpoint height. So an arrow is **three `addSeg` calls, 6 triangles, and NO new draw call and no
new material**: shaft plus two barbs swept back 45 degrees off the tip.

**Asked of the door OBJECT and of walkability, never of a model.** `objects.Door` is laid by
`gen.GenSpawner` for every generator that deals one, so this works in a compound, an underground lab
and anywhere else alike; `render.facility.FacilityModel.DoorCell` carries a real `alongX`/`inDir`
but exists only in a facility. The door object itself has no orientation either — only its icon
frames — so the passage axis is read as "which pair of opposed neighbours is BOTH walkable", asked
of the NEIGHBOURS and not of the door's own cell, which a shut leaf blocks.

**The side is the player's, and it costs nothing**: the grid is rebuilt when the player's cell moves
and never otherwise, so "which side am I on" is already answered by the centre it was built around.
Verified in game on one doorway — standing north of it the arrow points south into it, standing
south of it, north. No open/shut state on the arrow and therefore no new `invalidate` hook: it marks
a door you can go through, which is true whether the leaf is standing open or not.

`ARROW_LEN 0.52` / `ARROW_BARB 0.24` / `ARROW_W 0.022` are all several times the lattice's own `ARM`
and `WIDTH`, deliberately: this is a MARK and not a texture, and at the lattice's weight it read as
two more crosses.

Verdict: **KEEP.**

## The door arrow moves onto the doorway tile and grows a second head (`render/TacticalGrid.hx`)

Reported as "make a two-sided arrow for doors and put it on a tile underneath the door itself". Both
halves fall out of the same edit and together they DELETE code: the side, the approach cell and the
unit vector all go, because a double-headed arrow centred on the door cell has no side to pick.

`ARROW_BARB 0.24` → **0.28**, and it has to be read with `ARROW_LEN`: a head eats `LEN/2 - BARB` of
shaft at each end, so at the single-headed arrow's own 0.52/0.24 the two heads met in the middle
(0.02 of shaft between them) and the glyph came out a **diamond**.

Cost: 5 `addSeg` calls where the single arrow took 3 — **10 triangles per door instead of 6, still
0 extra draw calls**, same mesh and same material.

**THE LENGTH IS SET BY THE WALL AND NOT BY THE CELL, which took four measured tries.** The glyph
lies on the DOORWAY tile, where `WALL_T` 2.0 of masonry stands centred in a 4.0 cell and rises
`WALL_H` 6.0 — and at the facility camera's 51° a wall hides `6 / tan(pitch)` = **4.9 units** of
floor behind it, which is `RenderConfig`'s own figure for why a corridor reads the way it does. So
an arrow sized to the CELL cannot show its far tip:

| `ARROW_LEN` | tips, from the cell centre | on screen |
|---|---|---|
| 0.78 | ±1.56 (0.56 past the masonry) | **one head**, reported |
| 1.20 | ±2.40 | **one head** |
| **2.00** | ±4.00 — half a tile past the cell | **both heads**, tips inside the neighbouring cells |
| 2.60 | ±5.20 | both heads, further out than the read needs |
| 3.00 | ±6.00 | both heads, but they land on the NEXT cell's crosses |

Landed at **2.00 / 0.28**, i.e. the glyph deliberately leaves its own tile by half a tile each way.
Verified in game at 18,12 on one frame carrying eight doors: every door in a wall seen ALONG ITS
LENGTH draws `←▌→`, the wall band swallowing the shaft's middle.

**A door in a wall seen ACROSS it still shows one head**, and no sane length fixes that one: its far
side is the full 4.9 units of hidden floor, so the tip would have to sit ~5.9 units out (`LEN` ≈ 2.95)
and the glyph would then be longer than the room. Recorded, not chased. Not a height fault either —
`WorldCtx.floorY` returns 0.00 for the door cell and all four of its neighbours on every door
measured.

Verdict: **KEEP.**


## The corp office becomes a 3D area kind, off the facility's emitters and a `ShellTex`

`AREA_CORP` was one of the last two kinds still drawn by the 2D `AreaView` — not in
`GameScene.is3DArea()`, topbar reading `0 dc | 0k tri`. Rather than a second quad emitter, the
compound's `FacilityGeom` was made ART-AGNOSTIC and the tower drives it.

What moved: the sixteen `FacilityStyle.FLOOR_TILE` / `WALL_ROOM` / … constants at `FacilityGeom`'s
flush became `ShellTex`, a record hanging off `Facility.tex`, and `Facility` grew `kind`. `Surf` went
from 11 values to 20 (`CARPET`/`CUBICLE`/`MEETING`/`KITCHEN`/`EXEC`/`WASHROOM`/`SERVER`/`LIFT`/`OPEN`),
`isIndoor`/`isThemed` became range tests, and the four named interior wall buffers became
`[for (_ in 0...SURF_SLOTS) MeshBufTools.make()]` indexed by the Surf a face LOOKS INTO. An empty
buffer emits no mesh, so the nine unused facility slots cost nothing. `ShellOpts` carries the rest of
what differs — `surfOf`, `wallOf`, and a `hangars` flag that gates the concrete-majority shed test and
the study pads off for a tower.

Two behavioural gates and one derived number, all forced by the geometry rather than chosen:
- **no flat ceiling for kind `corp`** (`flatDeck = !st.hangar && m.kind != 'corp'`). The player is
  always inside a plate, so a deck would be permanently faded — dead geometry in the sorted pass.
- **no reveal ease.** One structure and the player is in it, so `inside` is pinned at 1 at build and
  `glaze.value` never moves. `CorpArea.tick` is the vision sweep and the chunk cull, nothing else.
- **the pane ASPECT moved onto `ShellTex` too** (`aspect`/`aspect2`). `paneTall` derives a run's
  height from the art's own width:height and never stretches, so the compound's 2.90/1.963 are a
  property of ITS images: the corp units measure **2.798** (512x183) and **1.829** (512x280) off their
  built crops, and drawing them at the facility's numbers would have been a stretch.

`CorpModel.fromArea` delegates to `FacilityModel.fromArea` with `CorpStyle.shell()` and then runs
`loneWindows`: `gen.corp` writes single-cell openings and `findWindows` assumes a run is never 1 cell,
so it dropped them and left a hole in the masonry with no pane. A 1-cell opening has no art of its
own, so it becomes `SOLID`.

Measured on a generated 65x50 tower floor, first entry: **`corp warm` 72 programs** cached in 418ms
(the facility's is 109/8.1s — a tower has no outdoors, no lamps yet and no glb props). In game,
**99 dc / 12.9k tri / 1347 geom** standing in the lift lobby and **89 dc / 12.7k tri** in the open
plan. The facility was re-walked after the refactor and is unchanged: 3 structures, 24 rooms, 42
windows, grime 687, exits 14, placards 50, cabinets 8, sinks 24, parapets 92/616 and 108/719 with the
hangar skipped.

Trap worth keeping: `FacilityGeom.floorBuf`'s fallback could not stay `Surf.TILE`. A corp floor has
no TILE art, so a cell whose surface has no entry emitted nothing at all — a hole in the plate. It
falls back to `Surf.CARPET` for kind `corp`, which is what `__corp().surfs` reporting **238 cells of
Surf.TILE** on a live floor is showing: the table cells `themeRooms` could not spread a room theme
over, i.e. the furniture standing in the corridors.

Verdict: **KEEP.**

## The corp shell's own art: two packed floor sheets, seven solo walls, two glazing units

Phase 3 of the same port. 20 labels under `corp/` off 14 generations, all at the 1,756-token tier
(~$0.77). None of it is the facility's; the one thing shared is the emitter.

**Eight of the nine floors came off TWO 2x2 packed sheets** — the trade `3d-textures.md` describes,
taken deliberately because a family of carpets and stones is exactly what wants harmonising. The
model honoured the split this time to within a pixel: per-column/per-row mean `|diff|` put pack-a's
seams at **512/512** and pack-b's at **511/511**, peaks **32.3-39.8** against a background of
**2.5-6.6**. Crops are inset 6 px and kept square (500 and 498). The server room's raised-access panel
is the one SOLO floor and the reason is the rule itself: its panel grid has to close, and a packed
cell's doubled wrap error is a visible step in a joint.

**The two glazing units are `tile` and not `sprite`, which is the useful finding here.**
`background: "transparent"` was asked for THREE times — gpt-image-2.5-flare, 2.5-sunburst and
gpt-image-2 — and came back opaque every time (alpha min 40, **0.0%** transparent), the model painting
a dark vignette field instead. Rather than chase it: the unit is a RECTANGLE, and the pane quad is
exactly the opening, so nothing outside it is ever drawn. Crop to the unit's own bbox (measured with a
luma+gradient mask: `[48,345,929,332]` and `[78,275,869,475]`), set `res` to carry the aspect, and no
alpha is needed at all. The see-through glass comes from `glass_alpha` as usual, and the threshold was
free: frame median **54/47**, glass median **164/173**, nothing in the histogram between 100 and 120.

Values were fitted against the compound's own built ladder and not predicted — interior floors land
**0.090-0.124** linear against its 0.094-0.135, interior walls **0.115-0.219** against its
0.137-0.159, the exterior **0.0314** against its 0.0327, the capping **0.0349** against its 0.0352.
Two gammas came out extreme in the DARKENING direction (`wall-office` 4.042 from srgb 205.7,
`coping` 4.591 from 187.4) because the drops were painted far brighter than a night interior wants;
they crush the skirting to near black, which reads correctly as a shadow line. Noted as a prompt
fault rather than a pipeline one: a corp interior brief asks for "premium" and gpt answers with
daylight exposure.

One label is deliberately reused across two slots — `corp/cap-alu` serves `tex.head` and `tex.roof`,
which ARE the same extrusion seen from the same angle. Four interior surfaces share `wall-office`
(corridor, open plan, cubicle farm, server room) for the same reason: in a real tower they are one
wall, and a room reads by its FLOOR and its furniture.

Verdict: **KEEP.**

## The corp fittings: eight families, nine merged meshes, one file

Phase 4 of the port. A desk, a kitchen counter, a boardroom slab, a cubicle spine, a server
cabinet, a vanity and a WC divider are every one of them an axis-aligned slab whose read is a
MATERIAL or a RHYTHM, so the triage comes out the same way for the whole set: **emitted quads, no
glbs**, one texture per FACE.

**It is ONE file and not the five the plan named**, because the buffers are keyed by TEXTURE rather
than by object kind. An exec desk and a cubicle desk are the same laminate and share a draw call
for free; splitting them across files could only have taken that back. Nine textures, nine merged
meshes, measured in game at **84-138 `dc`** across the rooms against phase 3's 89-99.

Three things the saved grid could not answer, and what was added for each:

- **`Const.isTableTile` deliberately EXCLUDES the corp furniture.** It is a stride test over the
  first 8 columns of tile rows 8-11, and the back half of those same rows is exactly the corp
  office's wood, carpet and marble tables. So `m.table` came back empty for a tower and the first
  build emitted **0 desks, 0 counters, 0 tables** against 35 partitions and 18 racks. Added
  `Const.isCorpTableTile` (the exact complement, columns 8-15) and a `tableOf` on `ShellOpts`, so
  neither kind can use the other's: **136 / 6 / 34**.
- **A cubicle spine, a server cabinet and a washroom fixture all paint their ROOM's own floor**, so
  the surface grid cannot separate them and the raw tile id is the only thing that can. Same
  argument `Facility.parking` already carries, so the same answer: a `fit` grid on the model, filled
  from a `fitOf` on `ShellOpts`. All three ids are a floor tile's unwalkable twin, which is how
  gen.corp says "something stands here" without spending a tile.
- **A BASIN and a WC CUBICLE are the same tile id.** Nothing had to be persisted to tell them
  apart: `CorpRooms.toilet` lays the basins as a continuous run along the room's top wall and the
  stalls every OTHER cell along its bottom one, so CONTIGUITY is the distinction and a neighbour
  test recovers it.

Two faults found by looking, both fixed:

- **A CONSTANT INSET DREW THE BOARDROOM AS A GRID OF SEPARATE SLABS.** Every cell pulled in 0.12 on
  all four hands, so a five-by-five table's top caps stopped touching and a dark groove ran between
  every pair. The rect is now cut per HAND against the family's own run predicate — inset only
  where the run really ends — and a run is one unbroken top again. Same fix carries the desk runs
  and the rack ranks.
- **A RACK'S EQUIPMENT FACE HAS TO BE AIMED AT THE CAMERA.** The aisle search took the first open
  neighbour, which for rows running along x is -z, i.e. away; the whole server room showed its
  backs. The order is now +z, +x, -x, -z — this camera rests with no yaw of its own, so unturned IS
  facing it, the same reasoning `ObjModels.PropYaw.FRONTAL` runs on.

And the hook that mattered most for how the floor READS: **`WorldCtx.ground` now answers the
FURNITURE**. gen.corp writes a decoration onto the same cell as the worktop tile it belongs to, so
before this every monitor, phone and mug on the plate hung at y = 0 with three quarters of a metre
of carcass in front of it — which is what the first 3D corp screenshots show. One hook, and the
actors, decals, path line, tactical grid and cursor pick all followed.

Art: 13 labels off FOUR generations (~$0.22) — three packed 2x2 family sheets whose seams landed at
512/512, 511/510 and 510/509 (peaks 34-72 against a 2.3-5.5 background), plus the rack front solo
because it is the one 0..1 AUTHORED composition in the set and its placed status lights want the
resolution. Two lacquer gammas came out at 4.4 and 5.2 in the DARKENING direction, the same prompt
fault phase 3 recorded: a "premium corporate interior" brief gets answered with daylight exposure,
and the white pieces landed at srgb 200-206 against an 85-95 target.

Facility re-walked after the `tableOf` / `fit` split and byte-identical on every counter:
3 structures, 24 rooms, 42 windows, grime 687, exits 14, points 6, placards 50, cabinets 8,
sinks 24, clutter 220, work 12. Both oracles green at 300 seeds.

Verdict: **KEEP.**

## The corp tower's glb props: seven models, five of them hand-modelled (phase 5 of the 2D → 3D port)

A task chair at every manned desk, a monitor and a keyboard on half of them, a WC pan in every
stall, and a potted plant, a water cooler and a printer standing against the walls. One pass
(`render/corp/CorpProps.hx`, ~300 lines), seven `Models.instanced` batches, **+7 draw calls exactly
— one per batch** (A/B/A/B at a pinned free-cam pose over an open-plan bay, `calls` **45 on / 38
off** three times running, identical each time; `tris` 158,758 / 14,450).

**FIVE OF SEVEN ARE HAND-MODELLED, WHICH IS THE OPPOSITE BALANCE TO THE COMPOUND'S AND NOT A CHANGE
OF POLICY.** `docs/3d-models.md`'s fourth route says to hand-model when the brief is a NUMBER, and
on a floor plate nearly every brief is: a chair that has to sit at `DESK_H`, a monitor that has to
stand on it, a pan built to `WC_D` so its cistern meets the divider rather than floating off it.
Three of the four are CLONES of the compound's own build scripts with the paths and the numbers
changed — which is the same split the whole port runs on. The arithmetic in `chair_build.py` (five
arms at 72°, a wheel resting at `R·cos(π/n)`, a raked back whose length comes off `CHAIR_H`)
belongs to neither area; only the sheet does.

**BLENDER IS NOT OPEN HERE AND DID NOT NEED TO BE.** The `blender` MCP drives a live session and
refused (`Cannot connect to Blender at localhost:19876`), and its CLI fallback wants `BLENDER_PATH`.
`blender.exe --background --python <script>` across the WSL boundary runs the same scripts
unchanged — `models-src` is a symlink to a Windows path, so every absolute path in them already
resolves. One throwaway `_preview.py` (import glb → ortho camera at 35°/28° → EEVEE 420px) is what
made the loop a loop; `BLENDER_EEVEE_NEXT` is gone in 5.1 and the enum is plain `BLENDER_EEVEE`.

**A "PREMIUM CORPORATE" BRIEF CANNOT REACH THE REFERENCE VALUE BAND AT ALL, AND THE FIX IS
DOWNSTREAM.** `style_corp` names MATTE WHITE LACQUER, so the cooler's reference measured **p50 213**
and the printer's **208** against the 69-77 that bakes correctly. `propstat --lift 74` does not
correct that: lift is a gamma and lifts DARKS hardest, so it took the cooler to **p50 64 with p05
5** and the printer to **p50 0** — both destroyed. So the references shipped bright and the value
was taken on the BUILT glb, where a flat linear `baseColor` preserves the ratios: cooler **0.17**,
landing it at 92 srgb. Same conclusion as phase 3's absurd darkening gammas, from the other end.

The built ladder, against the plate's own (carpet 84-101, desk-top 94.7, desk-body 58.2):

| prop | route | tris | built srgb | why |
|---|---|---|---|---|
| `corp/keyboard` | Blender | 44 | 50.9 | a wedge, 0.05 front lip to 0.089 back |
| `corp/monitor` | Blender | 268 | 70.5 | 16:9, 0.045 bezel inset (compound 0.075), stainless stem |
| `corp/chair` | Blender | 1,344 | 71.5 | `lift` 0.84 on the built glb, from 56.5 |
| `corp/plant` | TRELLIS | 4,206 | 72.9 | `lift` 0.83, from 58.7 — self-occlusion between forty leaves |
| `corp/printer` | TRELLIS | 1,200 | 87.6 | white half answered by the anodised half, no correction |
| `corp/wc` | Blender | 652 | 91.0 | built to `WC_D` 1.400 exactly |
| `corp/cooler` | TRELLIS | 1,198 | 92.0 | `baseColor` 0.17, the brightest thing on the plate |

**`propstat`'s COMPONENTS GATE IS WRONG ON A MULTI-PART OBJECT** and all three bakes tripped it:
plant 5 components / 84.4% largest, printer 12 / 61.2%, cooler 4 / 48.4%, every one a REJECT by the
rule. Looked at, the components are leaf clusters off a trunk, four feet and a scanner lid, and a
bottle sitting on a cabinet — real parts of real objects. The gate reads a blob cloud and a genuine
assembly the same way; the preview render is what tells them apart, and it cost one Blender call.

Live census off `__corp().glb` on a real tower: **105 chairs, 56 workstations, 10 plants, 8 coolers,
9 printers, 4 pans**, `glbBatches` `[105,56,56,4,10,8,9]` — keyboards match monitors exactly, which
is the invariant `WORK_EVERY` thinning the workstation and never the seat.

Two shapes that only this pass could state: **a desk's back is not always a wall** —
`FacilityTables.wallHand` knows only masonry and an open-plan run backs onto a CUBICLE SPINE or the
next desk, so `backHand` takes the first hand that is not clear floor and a spine serves exactly as
a wall does. And **a desk nobody can sit at carries nothing at all** rather than a monitor with no
chair, which is the compound's own `seat` finding asked one level up.

Art: **two generations** (~$0.11) for seven props — a three-band chair material sheet and the 2x2
workstation sheet (`corp/workstation`, `lift` 0.77 → built srgb 61.2 against the compound's 60.4) —
plus three TRELLIS references (~$0.17) and three bakes (~$0.03). The WC pan's sheet is **a paste and
not a generation**: a pan is three flat materials and a 64-pixel water patch, so it is composited
out of art the tower already owns (`textures/corp/wall-washroom` flattened and gamma'd to a
115-luma glaze, the chair sheet's anodised and stainless bands for the seat and the flush plate)
into the band geometry (edges at v 0.4965 / 0.7456) the cloned script's rects are measured to.

Both oracles green at 200 seeds. Skipped: the visitor chair, a second plant, the vending machine,
the fridge, the exec sofa and the basin bowl — all additions to a table, none of them a new shape
problem.

Open lead: **105 chairs is 141k triangles**, i.e. 89% of the pose's whole triangle count, and the
plant's 4,206 is what a shattered TRELLIS atlas costs (it would not decimate past that; 19,794 →
4,206 against a 1,200 target). Neither shows at 60 FPS / GPU 2.49 ms here, but they are the two
numbers to spend first if the plate ever needs them.

Verdict: **KEEP.**

## The corp tower's dressing: two PACK64 worktop sheets and four wall signs (phase 6)

**+2 draw calls measured** at a pinned pose over an open-plan bay (A/B/A/B, `calls` **59 on / 57
off** three times identical, `tris` 159,174 / 158,782 — +392). Three merged meshes exist (desk
sheet, util sheet, sign atlas) and one is off-frame at that pose. Live: **328 decals, 45 signs**.

**THE COMPOUND'S CLUTTER FILE COULD NOT BE CLONED AND THAT IS A FACT ABOUT THE MODEL, NOT THE ART.**
`FacilityClutter` is 517 lines and most of them are the CLUTTER SLOTS — the lid of every standing
fitting in `m.deco`, the store's crates, the shelving's three plates, the pallet racking's levels.
A tower plate has no `m.deco` at all: its furniture is emitted quads off `m.table` and `m.fit`
(phase 4). What is left once that goes is the worktop scatter, ~130 lines, and it needs none of the
compound's open-hand arithmetic either — a corp worktop fills its cell (`CorpFurniture.worktop`)
where a compound bench is cut to `DESK_D` on its open side, which is what made a decal wander off
the front edge there.

**TWO SHEETS AND NOT FOUR.** The kitchenette, the boardroom and the washroom would each have filled
about twenty cells; a PACK64 is 64 cells and ONE draw call whatever is on it, so all three share
`corp/util-clutter` and the desks get `corp/desk-clutter` to themselves. Picked off the cell's
`Surf`, so the split costs a branch.

**THE FIRST DESK SHEET WOULD NOT PACK, AND THE FIX WAS ARITHMETIC IN THE PROMPT.** `pack16.py`
refused it: *no empty corridor near 640 — thinnest line there still carries 41 opaque px*, i.e.
row 5's books and folded newspaper touching row 6, ten times the `--tol 4` the tool will clip
through. The re-roll spells the grid out in PIXELS — 128 px cells, nothing wider than 75 px, and
the seven seam lines named by coordinate — and packed at **tol 0, scale 0.9106, largest group
123x114**. The util sheet took the same prompt shape and packed first time at **tol 0, scale
1.0566**. Both drops came back **66% transparent** from `gpt-image-2.5-sunburst` with
`background: "transparent"`, which is the setting that failed outright on phase 3's window: it
works for an isolated CUT-OUT and not for a surface. Built values 81.6 and 82.9 srgb against the
compound's office sheet at 71.4 — right, because they lie on a 94.7 desk-top rather than a 60.4 one.

**FOUR ASPECTS ON ONE SIGN SHEET, WHICH IS WHY `CorpSigns` HAS AN `ASPECT` TABLE AND
`FacilityPlacard` DOES NOT.** The compound's eight plates are all square, so `PLACARD_W ==
PLACARD_H` and a quad needs no arithmetic. A landscape exit sign (**1.655**), a portrait directory
(**0.704**), a square room plate (**1.040**) and a landscape print (**1.503**) are not, and any of
them on a square quad is the stretch the aspect lock forbids. So `SIGN_MAX` 2.1 is the LONGEST edge
and the other comes off the art.

And the sheet is a **crop-and-repack, not a chroma key**: the drop draws each panel floating in a
charcoal wall margin, and a quad mapped over the whole quadrant carries that margin as a dark
border over a wall that is lighter than it. Keying it was the other route and was refused — the
framed print's own charcoal bands sit inside any tolerance that would catch the background. Each
panel was cropped to its measured bbox and pasted back filling its quadrant.

Signs hang **one per RUN of unbroken masonry**, at the run's MIDDLE — where the compound picks the
cell by what stands under the plate, because a hazard triangle is placed AT its hazard. None of
these four names a thing, so none has anywhere it would rather be. `SIGN_Y` 4.6 clears the tallest
thing that can share the cell (a server rack at 4.0), so the family needs no claimed-cell list.

**THE ELECTRICS ARE DELIBERATELY NOT PORTED**, although the brief explicitly allows reusing
`facility/electrical-pack` and `facility/cable` and that was the plan. Two reasons, and the second
is the real one. `FacilityCable` is 1,155 lines gated throughout on `Surf.LINO`/`TILE` and reads
`m.deco`, `FacilityPoint.places` and `FacilityTables.runs` — none of which a tower has, so "reuse"
would have been a second clone the size of the file. And a premium tower does not WANT it: exposed
skirting runs, wall sockets with leads dropping out of them and a cable drum on the floor are the
compound's language, and `style_corp` is "fine consistent reveals, no ornament, everything new and
maintained". The one thing worth having from that family is the lit lift-call panel, which is
phase 7's.

Art: three generations (~$0.17) plus one re-roll. Both oracles green at 200 seeds.

Verdict: **KEEP.**

## The corp tower's lighting rig, and the bug it was hiding (phase 7)

**THE PLATE HAD NO LIGHT SOURCE AT ALL FOR FIVE PHASES.** `CorpArea.tick` has called
`lampLights.update([], ...)` — an EMPTY post list — since phase 2, so a whole floor of offices was
lit by `IndoorMask`'s flat ambient and nothing else. Every screenshot in the phase 2-6 entries
above is of an unlit building, and reading them as "the art is dark" was wrong. The fix is one
argument, and everything else here is what had to exist for it to have something to pass.

`render/corp/CorpLamps.hx`: the fixtures AND the additive mesh in one file, because the fitting and
the panel drawn where it hangs are the same decision. Live on a real tower: **125 posts (74 room
lattice + 51 circulation), 125 panels, 65 pools, 2 call plates.** Posts is how many fixtures COMPETE
for the shared 12 spotlight slots and never how many are lit — `LampLights` hands the bulbs to the
nearest twelve every frame.

**THE COMPOUND KEEPS ITS CEILING GLOW OFF (`FacilityStyle.CEIL_GLOW = false`) AND A TOWER CANNOT.**
A compound room is seen through a roof deck that FADES, so the pooled spotlight lands on a floor
the player is looking straight down at. Here there is no deck at all (phase 2 gated it off) and the
camera sits at 51° over an open plate — past the twelve nearest fixtures the floor falls to flat
ambient, and a plate is wider than twelve spotlights reach. So the panel and the pool are both ON
for corp, with `C_PANEL` pulled to **0.8** against the compound's 1.0 because the corp bloom
threshold is **0.72** against its 0.9, i.e. lower.

One pool per ROOM RECT and not one per lattice point: two pools overlapping in an additive mesh is
twice the brightness down the strip they share, and a ceiling grid lights a room evenly whatever
its count.

The lift-call plate is **a second colour in one mesh**, which the per-vertex brightness channel
cannot do on its own: the plate's quads carry `C_CALL` scaled by the LUMINANCE RATIO between
`CALL_COLOR` and `LAMP_COLOR`, so one additive material draws both and it is right whatever colour
space `new Color` works in, both terms being in the same one. The compound does exactly this for
its warm bulkhead lamp.

**PERF: THE 8 FPS IN THE FIRST SCREENSHOT WAS A BUILD FRAME AND NOT A REGRESSION.** Sampled over
six reads at the game camera afterwards: **57-61 FPS**. An A/B on the eight shadow-casting
spotlights came back **cast 5.10 / nocast 9.66** and then **cast 4.82 / nocast 27.60** — i.e. noise
with no sign, which is the integrated-GPU power-state problem `3d-render.md`'s measurement rules
already record (the identical pinned frame has measured 11.61 and 4.06). `calls` is the number that
held still; GPU on this machine did not, and no conclusion was drawn from it.

**PHASE 7 BASELINE, which phase 8's street is measured against** — pinned free cam at
`lookFrom(-152, 26, -150, -172, 0, -172)` over a real tower:
**`calls` 49 · `tris` 159,918 · `programs` 127 · geometries 1,373 · textures 439.**
`corp warm` is now **76 programs / 2,663 ms** (up from 72 / 418 ms at phase 2 — the glb props are
what the warm now waits on).

One Haxe trap, the third time this port has hit it: `d:FacilityModel.DoorCell` in a signature is
`Type not found : FacilityModel`, and that ONE error at line 205 cascaded into eight bogus "Unknown
identifier" lines for every static declared after it. Importing a module makes its sub-types
available by BARE NAME and `Module.Type` is not a path from another package —
`import render.facility.FacilityModel.DoorCell;` and use `DoorCell`.

Both oracles green at 200 seeds.

Verdict: **KEEP.**

## The twentieth floor: the tower under the plate, a real citygen street, and a crowd on a wall clock (phase 8)

Three pieces, **+8 draw calls and +9,792 triangles over the phase-7 baseline** (49 → 57 calls,
159,918 → 169,710 tris at the same pinned pose). The plan's budget was ≤ 90.

**8a — `CorpFacade`: nineteen storeys and a soffit.** 194 cladding quads off every outward face of
the perimeter and 2,180 soffit quads under the plate. `STREET_Y` is **−114**, which is nineteen
`WALL_H` storeys and not the plan's −72 (that was twelve, and the plan's own note calling it
nineteen was wrong arithmetic). The drop takes the PARAPET's plane and not the cell's masonry slab
— a glazed cell's slab is `GLASS_T` where its neighbours' are `WALL_T`, so a facade following the
slab jogs half a unit in and out at every window run's ends, and taking the ring plane puts the
drop dead flush with the parapet band six units over it.

**IT IS UNLIT, AND THAT IS THE ONE DECISION IN THE FILE.** A `MeshBasicMaterial`, not the lambert
every other shell surface uses: the plate's lighting rig has nothing to do with a wall 114 units
below it, and under the scene ambient a lambert takes the art's lit window bays to nothing — the
whole read gone. Unlit means the authored value IS the rendered value. Fog still applies, which is
what makes the drop fade out rather than stop at a line. Neither the facade nor the street takes a
`VisionMask` patch: the mask's rim channel sinks a surface to the fog colour at the AREA BORDER,
and the border is the tower's own edge, so patched they would be cut to nothing exactly where the
player leans over the parapet.

**The facade art took two corrections and both were only visible in the frame.** Built at the
authored value the whole tower came back **a solid wall of gold** — unlit, the dark glass sat at
~40 srgb where it needed to be black, so every bay read as lit. `lift` **2.4** (darkening) fixed
the census — built sheet p50 **1.1**, **4.6%** over 120 — and the tower then came back **a wall of
orange instead**, because the amber is the corp accent hue and is correct for ONE window and not
for a hundred at once. `sat` **0.55** beside a final `lift` **2.8** is what settled it. Two knobs
answering two different questions: the gamma says how many bays are lit, the saturation says what
a hundred of them look like together. And `FACADE_TILE` went 12 → **20**: at 2 × `WALL_H` the six
bays across the image landed 2 units wide and the tower read as a gold mesh screen.

**8b — `CorpStreet`: a real citygen city, rendered by four merged meshes.** The MODEL is the real
thing (`CityGen.generate` with the downtown profile, seeded off the area id, nothing persisted);
what is LOW is the rendering. `render.World` runs eleven passes and lands a city area in the
hundreds of calls, and nothing down there is closer than 114 units — so this emits asphalt,
pavement, roofs and walls itself and skips lawns, entrances, wall decals, roof shadows, roof props,
the kerb, the street lamps and the `Check` audit. Live: **1,557 road + 633 walkway cells, 48 of 112
generated buildings**, 192 wall quads.

**THE PLATE IS NOT ON THE WORLD ORIGIN, AND THAT COST A BUILD.** A corp area is 65-75 by 50-60
cells while `CityConfig.cellToWorld` is written against a `GRID` of 100, so the plate sits off in
the −x/−z quadrant — its centre measured **(−80, −94)**. A disc of city centred on the origin is a
disc that is not under the tower, and from the plate's west edge there was simply nothing below.
The radius is measured from the plate's own centre now.

**8c — `CorpCrowd`: 64 walkers and 28 cars, ONE draw call each** (+2 calls, +184 tris, A/B/A/B
identical three times). Dealt over **39 walkway lanes and 18 road lanes**, where a lane is a
straight run of ≥ 6 cells found on both axes. Nobody turns a corner and from 114 units up nobody
can tell — that is the "fake to simplify logic" the brief asked for.

**ON A WALL CLOCK: raw `dtMs`, no `ANIM_SPEED` and no `BASE_MS`** — `RenderConfig`'s documented
exception for ambient city life, and the point of the feature. Measured live with the game idle at
a turn boundary: a walker moved 4.85 units in 1.5 s (3.2 u/s ≈ 1.6 m/s) and a car 22.6 (15 u/s ≈
7.5 m/s). Position is CLOSED FORM in the clock — lane, direction, speed and phase all off a stable
hash of the index — so nothing is stored per agent and nothing can drift.

**FLAT QUADS OF LIGHT, NOT BILLBOARDS OF PEOPLE**, and this is the shape decision. At 114 units
down, through fog, at 51°, a pedestrian is not a silhouette — they are the patch of light they are
standing in, and a car is its headlights. One additive quad lying on the road wearing the shared
radial gradient buys no billboarding, no atlas, **no new art at all**, one call per family, and a
read that is more correct than an upright sprite three pixels tall. `ponytail:` marked in the file
with its upgrade path (per-instance UV rects off the people atlas, the way `DecalBatch` does it).

Art: two generations (~$0.11) — the curtain-wall facade and a 2x2 street pack cut into four crops
(asphalt, pavement, roof, podium) at **res 256**, because at that distance a road cell is a few
pixels and the texel budget belongs to the plate the player is standing on.

Nothing under `render/facility/` was touched in phases 5-8 — `git diff --stat` over the four
commits is `RenderConfig.hx` (12 lines of MODELS paths) and `render/corp/` — so the compound cannot
have regressed by construction. Walked one anyway: renders, no console errors. Both oracles green
at 300 seeds.

Verdict: **KEEP.**


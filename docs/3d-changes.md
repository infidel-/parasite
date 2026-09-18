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

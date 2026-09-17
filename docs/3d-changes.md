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

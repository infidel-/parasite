# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. When this file reaches ~2600
lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one.

Older entries live in [`3d-changes-2026-09.md`](3d-changes-2026-09.md) (rolled at 2634 lines) and
`3d-changes-2026-08c.md` and its predecessors.

## An atlas icon caps a floor fitting at 32 texels: the drain becomes geometry (2026-09-06)

Reported as blurry, standing on it. Measured live: the drain drew on a `Sprites` quad of **3.0**
world units with the whole **64 x 64** atlas cell as its map, its art the middle **32 x 32** of that —
so **32 texels over 1.5 world units = 21 per unit**, against `floor-tile`'s 512 over `FLOOR_TILE_SZ`
7.0 = **73**. **3.4x coarser than the floor it is set into**, and about 7 screen pixels per texel at
that camera.

**WHY IT WAS IN THE ATLAS AT ALL, because two of the three reasons are still good.** `objects.FloorDrain`
is a game OBJECT and every object's art is an `entities64.png` cell — the 2D area view needs it there
regardless. And the 3D ground-decal path BATCHES by sampling that one atlas with a per-instance UV
rect, because `tex()`/`texContent()` cut each cell into its own texture and force a draw call per
cell (`Sprites.hx:517`). The third reason was the one that did not hold: `FacilityGeom.floorBuf`
refuses `Surf.GRATE` because a cell-wide 2 m square of grating read as a vehicle pit and tiled down
as four drains — **that finding is about the SIZE, not about the route**, and a centred 1.5-unit quad
was never tried.

New `FacilityDeco.drain`: one 0..1-mapped square per drain, `DECO_DRAIN_SZ` **1.5** kept to the pixel
so the swap changes resolution and nothing else, merged into one mesh for the compound. **256 over
1.5 units = 170 texels per unit, 8x.** `+1 draw call` measured by hiding the mesh at the pose
(**81 → 80 → 81**). The atlas cell STAYS for the 2D view; `FacilityDeco.draws` now returns true for
`floor_drain` so the icon is not also laid flat under the geometry.

**AND IT CONFIRMS THE SPRITE DEFICIT FROM THE DOOR PASS.** As an atlas sprite the drain rendered at
scene **0.0183** against the floor's 0.1526 = **0.120**, where its albedo ratio was 0.195 — 0.62x of
prediction, the same shortfall the vent shows at 0.53x. Re-emitted as ordinary lit geometry with
`lift 0.783` (0.445 x `floor-tile` 0.118 = 0.0525) it measures scene **0.0685** against **0.1526** =
**0.449**, i.e. exactly its albedo ratio. **So the deficit is the sprite path and not the art**, and
moving one fitting off that path fixed its value and its sharpness in the same edit. sRGB on screen
**9.0 → 38.1**.

## The doors went dark when the WALLS were repainted, and ACES doubled the gap (2026-09-05)

Reported as "the facility doors are way too dark compared to texture and walls around". Not a
lighting bug and worth saying how that was settled: door and wall carry the same patches
(`visionMask` + `indoorMask`, key `visMasksindoor`), the indoor mask reads **255** at the door's own
xz and the vision mask reads **255** too, and disabling `shadowMap` left the door byte-identical
while the floor moved 0.0727 → 0.0782. **Inverting ACES** (tone mapping 4, exposure 1.5) gave
scene-linear **0.0236** for the door against **0.1078** for the wall, ratio **0.219**, against an
albedo ratio of **0.2216** — 1% apart. Same light, both vertical, both on exactly `indoorAmbient`.

**THE ART WENT STALE UNDER A NEIGHBOUR'S REPAINT.** On 2026-09-03 `wall-interior` took lift 1.48
(0.069 → **0.1561** built) and `wall-room` lift 1.91 (0.058 → **0.1341**). The three door sources are
`last_converted` 2026-08-26/27 and carried **no lift at all**. `door-cabinet` was designed at
0.0319/0.0689 = **0.46** of its wall and was left at **0.19**.

**AND THE TONEMAPPER IS NOT A SCALE DOWN THERE.** At these levels ACES is
`(0.0246x − 0.00009) / (0.238 + 0.433x)`, which crosses zero at x ≈ **0.0037** — darks are crushed,
not scaled. Measured in one frame: **2.1x** in the files (48.5 vs 103.6 sRGB) drew as **4.8x** on
screen (12.9 vs 61.8). A stale ratio costs double what the file says it should.

`lift 0.721` on `door-cabinet` alone, solved through the same crop-lift-LANCZOS path `make tex`
takes: built **0.0724** linear, and in one frame the door goes sRGB **12.9 → 33.9** against the same
wall's 61.8, scene ratio **0.52**. Taken KNOWING it publishes the cast — spread 10.8 → **12.6**, over
the >6 re-roll rule — because the prompt asked for grey-GREEN laminate, so the hue is the brief.

**THE OTHER TWO DOORS WERE CHECKED AND ARE CORRECT**, which is the useful half: `door-glass` hangs on
`wall-exterior` (**0.0341** built, never repainted) at ratio **0.62** against a design 0.64, and
`door-metal` on `wall-hangar` (**0.0374**) at **0.83** against 0.80. Only the surfaces facing the
REPAINTED walls drifted. Same test found `floor-grate` stale the same way — **0.026** against
`floor-tile` 0.118 = **0.23** where it was designed at 0.445 — and that one turned into its own
change, below.

**Open lead, measured but not chased: an object SPRITE renders at about half what its albedo says.**
`vent`'s atlas cell is **0.1073** against `wall-room`'s 0.1341 = **0.80**, a sensible grille ratio;
in game on an interior wall mount, same normal, same cell, it reads scene **0.0438** against the
wall's 0.1038 = **0.42**, i.e. **0.53x** of prediction. Not shadows (disabled, byte-identical), not
the vision mask, not a tint (`color` 1,1,1, metalness 0, roughness 1). The one structural difference
is the material: the sprite pool is `MeshStandardMaterial` + `IndoorMask.patch`, the walls are
`MeshLambertMaterial` + `VisionMask.patch`. If that is real it applies to every object sprite in the
game and no texture lift can fix it.

## A server made out of shelves: "same material" is not a reason to share a texture (2026-09-05)

Reported from the game in four words — *"lol, server made out of shelves"*. The rack was already a
cuboid with a per-face split; what was wrong was WHICH faces shared. Its two ends and its lid were
emitted into `B_SHELF_TOP`, the shelving's perforated shelf plate, on the argument recorded in
`FacilityDeco`'s own header: both are dark steel, and a shared buffer is a shared draw call. But a
cabinet's flank has no holes in it, and the holes are what the eye picks up — the unit read as
shelving with a server front stuck on it.

**A PACK4 SHEET, AND THE RACK'S WHOLE CABINET IN IT.** One 1024 generation, four quadrants: front (a
re-roll), blank side panel, top lid with slots and grommets, and a blanking/cable panel nothing draws
yet. It cost **$0.2138 and should have cost $0.053** — the call passed `quality: "high"` where the
tool's own default is `medium`, and at 1k the tiers are low $0.006 / medium $0.053 / high $0.211 for
art that is downsampled to 512 before it is drawn. Front / side / lid wired, `+2 draw calls` measured by hiding
the two new meshes at the pose (**111 → 109 → 111**).

**THE SHEET HAS A DARK 2px FRAME, NOT JUST A SEAM BAND, AND IT POISONS EVERY WRAP MEASUREMENT.**
Column means at the left edge run `1.9 / 8.6 / 47.5`, and the seam sits at **511-513**. Slicing the
naive `[0:512]` quadrants reported wrapH/wrapV **23.7 / 21.5** on the front and **32.6** on the lid —
all of it the frame, none of it the tile. Inset from BOTH (crops `[2,2,508,508]`, `[514,2,508,508]`,
`[2,514,508,508]`) and the real numbers are **2.7/8.0**, **4.0/2.2**, **4.0/10.4**, in line with the
pack4 rule's own 3.4-4.5 / 3.8-9.9. Insetting from the seam ALONE is worse than not insetting: it
puts the crop's edge two pixels inside the dark band and reports **50+**.

Vertical wrap on the front actually IMPROVED over the solo roll it replaces, **18.0 → 8.0**. Lifts
solved so the swap changes art and not exposure: front `0.824` → built **58.9** against the solo
roll's 59.1; side and lid share `0.839` → **66.4 / 66.2**, above the front's 59 and under the
shelving steel's 73.4.

**AND THEN THE ART CAME OUT PHASE-SHIFTED, WHICH IS `FacilityGeom.face` DOING ITS JOB.** Reported as
"front and top look like they're drawn with a u or v shift" — and they were. `face` and `cap` divide
the WORLD coordinate by the period, which is what makes two neighbouring wall cells carry one
continuous course, and is wrong for a cabinet: the rack's left edge stands at world x **−48.88**, so
u opened at **−33.71** and the art began **0.29 of a tile in**. On a material swatch nobody can see
that; the rack's front is an authored composition with an end rail down each side, and both rails
landed in the middle of the face. New `FacilityDeco.localFace`/`localCap` lay these three faces from
the UNIT'S OWN CORNER, on `FacilityGeom.ends`' winding rather than a re-derived one, and
`DECO_RACK_TILE` becomes the unit's WIDTH (1.6) instead of half its height: read off the built mesh,
the front is now u **0..1** exactly with the rails on the corners, v 0..1.8125; the sides 0..0.75;
the lid 0..0.75 x 0..1, under one repeat both ways so it never draws a wrap.

**THE HEIGHT IS THEN A DERIVED NUMBER, AND THE LIGHTS ARE READ OFF THE ART.** Laying the front from
the unit's corner makes `DECO_RACK_H` a texture constant: the image holds **3 chassis per repeat**,
so a height that is not a whole number of thirds of the tile cuts the top unit in half at the lid.
It stood at 2.9 = **5.44 chassis** and the half unit was reported. `DECO_RACK_H = DECO_RACK_W * 2` →
v exactly **2.0**, 6 whole chassis. The LED field followed: it shipped as an even **6 x 3** grid over
a band of the face, i.e. specks across the vent mesh and across the recessed gaps, and is now **one
pair per chassis** — rows at `(k + 0.5) / rows` with `rows = h / tile * 3` (measured: the gaps sit at
v 0.34-0.37 and 0.66-0.69 of the tile, so every row lands inside a unit within 0.05 world of its
centre), columns in the blank strip at u **0.72-0.90** (the vent mesh's per-column deviation falls
18.5 → 10.1 past u 0.66 and the screw column stands at 0.91). 18 lights → 12. **The band has to be
measured from the TEXTURE'S u origin**, which `FacilityGeom.ends` puts at x1 or z1 on two of the four
hands — the old grid was symmetric about the face and could not tell; a strip pinned the wrong way
round lands on the vent panel.

Verdict: KEEP. Three traps worth carrying forward — two surfaces being the same MATERIAL says
nothing about whether they can be the same IMAGE; world-aligned UVs are for RUNS, not for objects;
and once a face is laid from its own corner, the object's SIZE is downstream of its art.

## Everything that stands against a wall was standing in the wrong place (2026-09-05)

Three things reported from the game in one breath — "the bookcase halo clips the bookcase", "the
opened door clips the table", "move the table closer to both walls, the halo looks dumb" — and the
first and third are the same fact from opposite sides: **the tile grid and the masonry are not in the
same place.** `FacilityGeom.slab` insets a solid wall's room face by `(CELL - WALL_T) / 2` = **1.0**,
so a thing built on its cell is a unit off the wall, and a thing built off the slab face is as close
as its own gap constant says.

**A HALO IS A PLANE AT `HALO_EPS`, SO A BACK CLOSER THAN THAT IS BEHIND IT.** `DECO_GAP` shipped at
**0.05** against `HALO_EPS` **0.09**: read live, the bookcase back sat at x −112.95 and its halo quad
centre at **−112.91**, the plane **0.04 INSIDE the box**. It cuts both side faces and the top cap
along a line and everything deeper than 0.09 along a view ray draws over them — a sliver from
straight above at 71°, opening up as the hold-RMB orbit drops the pitch. `DECO_GAP` is gone;
`STAND_GAP = HALO_EPS + 0.03` lives in the halo block because that is what fixes it, and both
families that stand against masonry read it. All **10 fittings** in the compound (2 shelving, 7
bookcase, 1 rack) now measure exactly **0.12** off their own wall face.

**THE BENCH SLIDE WAS BUILT, MEASURED AND REVERTED — A BENCH DOES NOT TOUCH ITS WALL, SO IT DOES NOT
GET A CONTACT SHADOW.** A bench block sits on its CELLS, so its halo was painted on masonry **25 px
away** at the game camera (1.0 world, 0.8 at worktop height after the lip) — a shadow with bare floor
under it. The built answer moved the bench: `BENCH_SLIDE = (CELL - WALL_T) / 2 - STAND_GAP` = 0.88,
per BLOCK via a flood fill over `m.table` (per cell tears a 2-deep block into two rows), a side moving
only when the WHOLE of it stands against solid masonry so an L of two touching rectangles stays put,
`ContactMask.prop` and the halo span moving with it. It worked — 0.12 off both walls, window runs
byte-identical, 0 quads in masonry (27 overlapped a `slab` BOX and every one was inside a `notches`
corner square, which is room floor). **Rejected on looks anyway: called on the game as "revert the
table movement and just remove the haloes for them because of distance."** The right read, and it is
the cheaper one — the halo family exists to say *this is touching that*, and 0.8 of floor is not
touching. `FacilityTables.halos`/`backs`/`slide`/`faces` are gone, **halo mesh 74 → 38 quads, 36
bench run halos removed, `calls` 91 / `programs` 91 unchanged**. The corridor casework keeps its
halos: `unit` builds off the wall FACE (`x0 = s.x1`), so a cabinet really does touch.

**THE DOOR IS A GENERATOR BUG AND IT IS FIXED THERE.** Door (24,8) is open in the save, leaf 0 hinges
at world **(−104, −166)** and swings to (−104, −168); bench (23,7)'s worktop reached **−103.8** after
`BENCH_LIP`, so the leaf's last **0.2** was inside it and the whole quarter disc crossed the corner.
`FacilityAreaGenerator` already had `isBlockNearDoor` and it missed this in two ways. It is called
inside the `len >= windowSize` branch, which fires at a block BOUNDARY — **a run's OPENING block was
never tested at all**, and that is the block this bench was in. And it was taken on the WINDOW line,
whose ±1 border does not reach a doorway one row PAST the tables. Now taken on the TABLE line, and
evaluated once before the loop for the first block; the flag is per block rather than latched like
`noTable`, so a run that passes a door carries on tabling afterwards. The freed cells fall through the
branch that was already there and get a floor decoration, forced LOW — a bin or a drum beside an
opening, where a 2.8-tall fitting reads as blocking it. The cell orthogonally next to the doorway
still gets nothing, which the existing `nextTo(... INNER_DOOR)` guard was already doing.

**AND THE RENDERER KEEPS A GUARD, BECAUSE TILES ARE PERSISTED.** The generator change reaches only
newly generated areas; this compound still has **1 table cell in a door's 8-neighbourhood**. So
`facesDoor` stays in `FacilityTables.build` — `FacilityModel.nearDoor`'s diagonal reach narrowed to a
single face, dropping the `BENCH_LIP` overhang only on the side a leaf swings past and leaving the
silhouette on the other three. With the slide reverted it carries the case alone: **0 of 169 worktop
quads** intersect any leaf's swing quadrant, down from 1.

`STAND_GAP` is the part of this that stayed.

## The corridor floor goes blue-cyan, and the value does not move (2026-09-05)

Called on the game: drab grey was already everywhere indoors. `facility/floor-lino` had been re-rolled
PERFECTLY NEUTRAL one repaint earlier, so this is that clause inverted rather than a lift on top of it
— hue is fixed by re-rolling, and a gamma cannot put a cast in any more than it can take one out.

**THE VALUE IS THE PART THAT HAD TO SURVIVE.** The corridor's brightness is not a taste number: it is
the room's own floor:wall ratio (0.12 / 0.1394 = **0.861**) applied to the corridor's own wall,
`facility/wall-interior` at 0.1595, which is what makes a corridor read as light walls over a slightly
darker floor exactly as a room does. New drop 116.9/135.5/140.3 = **0.2358 linear**, so `lift` was
re-solved against the drop rather than carried over: **1.361 → 1.38**, landing 0.1365 against the grey
roll's 0.1361. Same surface, same ladder, different hue.

**MEASURED AGAINST ITS OWN WALL IN ONE LIGHTING BAND**, which is the only comparison worth making
indoors: floor **60.2/95.5/107.2** (G−B **−11.7**) against the wall at 66.4/77.2/79.9 (G−B −2.7 — the
number every neutral surface here sits at, because the rig is blue). So the tint is **9 points of cyan
beyond the ambient**, with R 6 under the wall's and B 27 over it, and not just the blue rig showing
through a grey.

**THE 24.9 BYTE SPREAD IS DELIBERATE AND DOES NOT BREAK THE >6 RE-ROLL RULE.** That rule exists
because a lift PUBLISHES a cast nobody asked for — the olive drop's whole story. Here the cast is the
brief, so the gamma widening the drop's 23.4 to 24.9 is the knob working. What did carry over from
that story is the spec: the prompt names the bytes outright (**88/104/112**) instead of saying "light
blue", because a chroma target is unreachable from prose.

One wrinkle worth knowing: `filename_prefix` was `facility-floor-lino`, and `make adopt` strips only
the `image-<ts>-<hash>-` part, so the source landed as `facility/facility-floor-lino.png` rather than
`facility/floor-lino.png`. `src` points at what is actually there instead of moving a generated drop
by hand; the superseded grey is on the `unused/` shelf as `facility-floor-lino-grey.png`.

## The plate under the box gets the wall halo laid flat (2026-09-05)

The other half of "shadows on the shelves". The box's vertex channel darkens its own SIDES down to
the plate; the patch of PLATE the box sits in still had nothing, so a box met the shelf on the same
hard line a fitting used to meet its wall on.

**NEITHER OF THE TWO THINGS ALREADY THERE CAN DO IT.** `ContactMask` is one top-down field painted
from footprints with no Y, so a box on shelf 2 would darken the floor tile under the whole unit. And
the vertex channel cannot either, which is the part worth writing down: a box's footprint is a patch
INSIDE one plate quad, and a channel only ramps between a quad's corners — painting a patch means
subdividing the plate, which lives in `B_SHELF_TOP` with the rack's two sides and its top.

**SO IT IS THE WALL HALO, LAID FLAT.** New `FacilityDetail.pool` is the same collector, the same
drain, the same merged mesh, the same ramp and the same `HALO_ALPHA` as `stand`. **12 quads, +24
triangles, +0 draw calls, +0 programs, 0 art.** The halo mesh went 62 → 74 quads with `calls` 75 and
`programs` 91 unchanged, and read 74 again after a reload — the drain's clear still holds. Measured
against the 12 quads collapsed at one pinned pose: **max 10.3/255 over 1.9% of the unit**.

**THE REACH IS THE ONE NUMBER THE WALL HALO DOES NOT SHARE, AND WITH THIS RAMP IT COSTS THE CONTACT
LINE.** Up there the quad is the object over `HALO_CORE`, so the art's opaque core lands exactly on
the object's edge — and that pins the visible ring at **0.533 of the object's half-extent**, which is
locked by the art. It is too wide for a 0.55-wide box on a 1.67-deep plate. **A single linear uv over
a single ramp cannot narrow it**: pinning both edges of the box at the core boundary DETERMINES the
slope, and with it the ring. So the core is allowed to shrink INSIDE the footprint instead — the quad
is the box plus `POOL_GROW` 0.4 of its own half-extent with the art mapped 0..1 over that — which
costs nothing where the box is standing. Ring **0.533 → 0.288** of the half-extent and the peak
**27.7 → 10.3**, because the box's own edge now sits partway down the falloff at 0.66 alpha. Holding
the core on the edge AND narrowing the ring wants a second ramp with its own `halfFrac`, i.e. a
second alphaMap, a second material and the draw call this whole family exists to avoid.

**TURNED WITH ITS BOX.** Built axis-aligned first and reported from the game as not respecting the
box's angle, which it did not: a rotated rect clamped against an axis-aligned plate is no longer a
quad, so the first cut used the turned box's AABB. Building the quad in the box's own frame and
rotating it out costs one thing — the clamp measures the room on the AABB and then spends it on a
LOCAL margin, which is conservative by the corner's swing. Measured on the built geometry: edge
bearings **−14.0 to +12.7 degrees** against `DECO_BOX_YAW`'s ±14.3, and the worst quad overhangs its
plate by **0.04 units**, inside the fade's own tail.

**CUT PER SIDE, BECAUSE SHRINKING BY THE TIGHTEST SIDE GIVES 3 OF 12 BOXES NOTHING.** The plate
rarely has the whole reach: a full-depth box leaves 0.17 of a 1.67-deep shelf and one against the end
of a 2.6 run leaves nothing on that side. Built first as one scalar, the largest fraction that fits
all four sides — **9 pool quads came out for 12 boxes**, because `FacilityDeco.boxes` fits its big
ones EXACTLY (`hd = (deep/2 − bw/2·sin)/cos` is an equality), so the room is 0 and so is the scalar.
Each side takes the room it actually has instead, with the art centred on the BOX rather than on the
quad and a clamped side's uv cut off the ideal reach, so the falloff stops where the plate does.

`POOL_EPS` is **0.01** and not `HALO_EPS` 0.09. That ladder is a WALL ladder — it clears the grime
band and the corner strips, which are other things drawn on the same masonry — and there is nothing
else on a shelf plate. 0.09 in a 0.83 bay is a ninth of the bay and at the camera's 51 degrees it
slides the shadow 0.07 out from under its box.

## The benches and the casework get the wall halo too — a RUN is a point once you merge it (2026-09-05)

The half the halo pass held back. The fittings and the lab kit went in because each is one object on
one cell with the hand of its wall already computed; the benches and the corridor casework did not,
because a quad per CELL would overlap along one wall and **two of these at 0.5 compound to 0.75** —
the seam the corner strips shipped with once.

**MERGING THE RUNS IS THE WHOLE OF IT, and only one family already had them.** `cabinets` walks runs
already (it computes `first`/`last` for the end caps), so that one is a single call at the end of the
walk. The benches never did: the generator deals 1x1, 1x3, 3x1, 2x3 and 3x2 blocks and `build` emits
per cell toward any neighbour that is not a bench, so nothing upstream names a run **or** a direction.
New `FacilityTables.halos` finds them with the same claimed-per-direction walk `cabinets` runs on —
`key` cuts a slot per (cell, dir), which is what lets a block in a room corner take one halo on each
of its two walls.

**+0 DRAW CALLS, +0 PROGRAMS, +88 TRIANGLES.** 44 run halos land in the mesh and the material that
already existed. Whole mesh interleaved A/B/A/B, 4 rounds identical: **+1 call, +124 tris (62 quads),
programs unchanged**. Measured on the casework band in a corridor: **max 19.0/255, touch line
68.7 → 49.7 (28% drop)** — the same family as the fittings' 16.7 and 27%.

**THE REACH HAD TO STOP BEING A PURE FRACTION.** The art fixes fade = 0.2667 x the object, which is
right for a bookcase and absurd for a 16-unit casework run: **4.3 units of wash up a 6-unit wall**.
`HALO_GROW_MAX` 1.1 caps the grown margin, and the number is set ABOVE the largest margin anything
already emitting asks for — the gas rack's 3.0 height wants exactly 1.0 — so **every fitting and
every kit prop is untouched by it**, while a run is held to a 0.88 fade, inside the band
`CONTACT.blur` 0.7 was swept in.

**The cap needs no end cap and leaves no hard edge**, which is the part worth writing down. Past it
the object's own edge maps OUTSIDE the art's opaque core, so the alpha at a long run's end is already
near zero — the halo thins along its length rather than stopping on a line. The band ABOVE the run
keeps its full profile the whole way, because the rounded-box field is a `max` and a point over the
middle of a long edge reads the short axis.

**The clamp grew a `len`.** `FacilityGeom.slab` is per CELL and a cell is 4 units, so clamping a
4-cell run to the first slab would cut it to a quarter of itself; the two END slabs bound it instead,
and for a single object they are the same slab. Built widths read off the geometry: **4 / 8 / 12 /
15 / 16**, with the masonry visibly cutting the last two.

**Most of a bench block gets nothing and that is correct.** The generator lays its runs under WINDOW
walls and `isSolidWall` answers false for glazing, so a bench is grounded where it meets real masonry
and nowhere else. Measured on one compound: **139 bench cells carry 71 solid-wall sides against 75
glazed ones**, and 76 of the cells touch no masonry at all.

## A box on a shelf carries its own shading, because the room has none to give it (2026-09-05)

The other half of the thing the wall halo did not fix. **Three shelf plates 0.83 units apart in one
shelving unit rendered 53.6 / 52.8 / 53.0** — 0.8/255 apart — and a box met its plate at
**69.7-on-53.0** with nothing between. The unit read as a stack of identical slabs.

**IT IS NOT A TUNING GAP.** Every plate is a `FacilityGeom.cap` with a +Y normal and the indoor fill
is an AmbientLight-shaped term (`IndoorMask`), which is normal-blind — so two horizontal quads at
different heights in one room are *identical by construction*. No light in the compound can separate
them, and the wall halo cannot reach them either: at 51 degrees down you look INTO an open frame and
a box is read against its SHELF, not against the masonry.

**So the shading is baked into the vertex channel.** `crate`'s five quads go `quad` → `quadC`
carrying two things in one number: the bay's weight over the whole box (`DECO_BOX_AO_LOW` 0.78 at
the bottom shelf ramping to **1.0 at the top** — an open frame is closed above every shelf but its
last, so the top bay's own missing lid is why it takes none) and a darkening down each side to the
plate it stands on (`_FOOT` 0.70), which is the box's own contact shadow. The side quads wind p0/p1
on the shelf and p2/p3 at the lid, so the contact runs UP the face whichever way the box was turned.

**+0 draw calls, +0 triangles, +0 PROGRAMS.** The mesh and the geometry are the ones already there
plus one attribute. The program is free for a reason worth writing down — `vertexColors` IS in
three's program key, but **Lambert + map + vertexColors is a permutation the facility already
ships**: 3 such meshes in a lab (the ground layers at 5,993 and 4,702 verts, and this at 240). Boot
**64 → 90** on entry, identical with the channel and without.

Measured against `vertexColors` toggled off at one pinned pose: **low-shelf boxes 51.5 → 45.3**,
**top-shelf box unchanged** (its `ao` is exactly 1.0, by design), max **18.7/255** over the unit.
Deliberately in the same modest family as everything else indoors — the corner strips do 30, the
wall halo 16.7, the contact field's prop pools 27.

**TWO DERIVED HOOKUPS, BECAUSE A MISMATCH HERE IS SILENT.** `FacilityGeom.geom` dropped `b.col` and
the material has to set `vertexColors`; get either wrong and you have an attribute nothing samples or
a shader reading one that is not there, with no error. Neither is a flag: `geom` attaches `color`
when `b.col.length == b.pos.length`, `solid` sets `vertexColors: b.col.length > 0`. Both read the
same fact. `col` is opt-in (only quadC/quadRGB fill it — `MeshBuf`'s own word), so all five other
`FacilityDeco` surfaces and every other `FacilityGeom` buffer come out byte-identical.

`crate` also crossed the argument limit at ten and became `FacilityCrateOpts`. Its call site was two
`dir < 2 ?` ternaries feeding four adjacent Floats — the mis-orderable list the style guide names.

**What is still true:** the plates themselves are untouched and still read flat. They live in
`B_SHELF_TOP`, shared with the rack's two sides and its top, so giving them a channel means every
quad in that buffer pushes one — i.e. colour-carrying variants of `FacilityGeom.face`/`cap`. Darker
boxes on lower shelves buys most of the depth cue for none of that.

## The facility's LOW list goes 3D with no new art at all (2026-09-06)

Inventory first. `entities64` rows 8-14 hold **73** facility decoration frames, `FACILITY_FITTINGS`
had claimed **10**, and all 63 left drew at **21.3 texels per world unit** — 64 px over a
`Sprites.SIZE` 3.0 quad, the number the drain migration recorded as blurry (floor tile 73, emitted
drain 170). Live area: **132 decorations = 29 floor + 103 table**, the 29 matching the corridor
-lighting pass's own `TILE_FLOOR_TILE_UNWALKABLE` count exactly.

**Three of the four new kinds cost NO ART AND NO CALL, and that is the entry.** `FIT_RACK_LOW`
(12/7-10, **6 here**) is the existing rack cabinet at `DECO_RACK_LOW_H = DECO_RACK_TILE` 1.6 — one
exact repeat, so v lands on 1.0 with no wrap seam; same three textures, same three buffers, and 3 LED
rows fall out of `h / DECO_RACK_TILE * DECO_LED_PER_TILE` untuned. `FIT_BIN` (12/3-4, **1 here**)
costs no BATCH either: `FacilityGround.bins` already instances `facility/trash-bin` and already
places indoor corridor bins, so these push into its own `places` — **11 → 12**. Only `FIT_DRUM`
(12/1,2,5, **4 here**) opens one, reusing the tunnels' `sewer/drum` (`Models.cache` is keyed by path).

**A DRUM AND A BIN HAVE NO QUAD ROUTE AT ALL** — `FacilityGeom` emits axis-aligned rects — which is
what put them on the glb side of silhouette-vs-surface. They are still in `FACILITY_FITTINGS`,
because being there is what turns the sprite off AND what stamps `m.deco`, and stamping is what keeps
`FacilityKit` off the cell. Before this, `findDeco` stamped only frames WITH a kind, so a plain
-sprite decoration cell was invisible to `isFitting` while passing every test `FacilityKit.wall`
makes: **a gas rack could be drawn standing inside a 2D fridge.** Now every row-8/12/13 frame carries
a kind and the overlap is impossible by construction.

**A WINDOW COUNTS AS A WALL FOR THESE AND MUST.** `isSolidWall` rules one out for a fitting because a
sill is where a worktop would be — right for a 2.8 cabinet, wrong at 1.8 — and the generator FORCES
the low list beside glazing (`nextToWindow`), so on masonry alone most of this family stands adrift
mid-cell. Off the instance matrices: all 4 drums landed **2.28 off their cell centre** (the slab
face), base y **0.0005**, height **0.9895 × 1.819 = 1.80**. The wall halo stays SOLID-only — on a
window cell it would land on the glazing.

**Measured on one pinned pose (`p -74/48/-78`, identical quaternion): `calls` 103 → 98, `tris`
56,684 → 76,034, `programs` 93 → 94.** Calls went DOWN because the sprite pool is one Mesh per quad,
so 11 suppressed icons outweigh the one new batch. The whole tri delta is the drum — **4,826 each,
19,304 in frame** — and it costs nothing: batch `visible` A/B, 4 interleaved phases, 48 samples each,
GPU median **1.672 vs 1.664 ms**, delta **0.008**. `cabinets` 30 / `boards` 2 / `exits` 16 /
`shadows` 401 all unmoved.

**AND THE 43 TABLE FRAMES ARE NOT MIGRATING — SHRINKING THEM IS THE SAME FIX.** `groundY` anchors a
bench decoration at `BENCH_H` 2.0 and the quad is 3.0 square, so their alpha bboxes put them at
**1.03-2.25 world units on a 1 m worktop**: a microscope 1.08 m tall, two thirds of the wall.
`DECO_TABLE_SCALE` fixes size and resolution in one constant. A flask is what a mesh generator is for
and what an emitted box cannot state, so 43 glbs was never the answer: the blur was a SCALE bug
wearing a resolution costume.

**IT SHIPS AT 0.54 AND NOT THE 0.36 THE MEASUREMENT ASKS FOR**, called on the game. True size puts
the biggest icon at 0.81 units — 40 cm, correct for a distillation rig and a SPECK at the resting
camera, where the whole job of bench clutter is that the room reads as worked-in from across it.
**1.5x true size** is the emphasis every icon in this game already carries; the bug was never that
they were emphasised, it was that they were emphasised by **2.8x**. At 0.54 the 64 px covers 1.62
units = **40 texels per unit** against the floor tile's 73 — still 1.9x the 21.3 it started at.

**Two things that scale broke.** `Actors.drawActor`'s ground anchor dropped a sprite by
`Sprites.SIZE * gs.by` with no scale in it, so a scaled quad sinks — the correction is
`0.5 * (1 - s) + s * by`, collapsing to the old expression at s = 1. The CENTRE at `Actors.hx:870` is
deliberately untouched: the attached-parasite pose reads it and has its own tuned `ATTACH_HEAD_Y`.
And `CastShadows.project` sizes its silhouette off the full `Sprites.SIZE` with no scale hook, so a
20 cm flask laid a blob three times its own width; `LampShadows` skips a bench decoration outright
rather than plumbing a scale through every call site.

**The generator needed one guard.** `addFitting` picks a random kind off `FACILITY_FITTINGS` and only
ever runs on HIGH cells, so three new low kinds would have been **3 of every 6** high fittings —
drums where fume cabinets belong. `_Fitting` gained `high: Bool` and `Const.highFittings()`.

**Nothing persisted**: a kind is still recovered from the decoration's own atlas frame, verified by
loading a pre-existing slot — **6 rack-low, 4 drum, 1 bin, 8 still sprites**, all off frames that
were in the save already. Those 8 (8/0-3 cabinets, 8/4-8 machines, 12/0 placard, 12/6 appliance) are
what the two packed sheets of phases 3-4 are for.

## Reusing a prop indoors published a colour bug the docs had already named (2026-09-06)

Reported from the game against the model viewer: the litter bin, newly standing in a lit corridor,
was a **black cylinder** where the viewer shows a green bin with a grey lid.

**IT WAS NOT TOO DARK, IT WAS NEUTRALISED, AND THIS IS THE FLAT-SCALAR RULE'S OWN WORKED EXAMPLE.**
`propstat app/models/facility/trash-bin.glb` reads the bake as **atlas 122/142/122, chroma 20.1** —
genuinely green — and `models.json` shipped `baseColor [0.14, 0.1, 0.14]`, a per-channel factor with
**G below R and B**. Shipped sRGB is atlas × f^(1/2.2), so 122·0.412 / 142·0.351 / 122·0.412 =
**50/50/50 at chroma 0.4**. `3d-render.md`'s colour-deletion row names this prop by number already
("bottle-green body 20.1 → **0.1**"); nothing had gone back to fix the entry it was measured from.

**AND THE LEVEL WAS STALE, WHICH IS THE PART THE REUSE EXPOSED.** 46-52 is a luma family fitted
OUTDOORS. The interior was repainted ~2x linear afterwards (`wall-interior` 0.069 → 0.1595,
`floor-tile` 0.0607 → 0.12) and this prop was not, so a bin that reads fine on a night lawn reads as
a hole in a pale corridor. `propstat` suggests a flat **0.12** to hold the old band; **0.30** follows
the repaint instead.

Measured on one pinned pose, before/after, with the lino and end wall in frame as controls
(**identical to within 1.2**, so only the bin moved): bin luma **23.5 / 18.7 → 49.2 / 49.4**, chroma
**8.8 / 6.3 → 25.1 / 22.5**, rgb 16.6/25.4/25.4 → **30.3/55.3/44.2** — G now the top channel, against
lino at 89 and wall at 68.

**ONE MATERIAL HAD TO SERVE BOTH, and it does.** `SOLID` does not clone, and this glb is the park's,
the lot's, the corridor dead ends' and now the deco cells' — so a second label would have split
`FacilityGround.bins` into two batches and given back the +0 draw call the deco bins had just won.
Checked outdoors at a park bench: **luma 20.7 / 21.6 against a lawn at 11.6 and a walkway at 20.3**.
A moon-only park is far too dark for a 1.55x albedo lift to blow out, so the fallback was never
needed. **The general form: a prop fitted before an area was repainted is fitted to a surface that no
longer exists — re-check the props when the ground under them moves.**

## Three drums off one mesh: repainting a glb without an image model (2026-09-06)

The reused drum read correctly as a 200 L barrel and wrongly as a GRIMY one — it is the tunnels'.
And collapsing the low list's three barrels (12/1 grey + hazard triangle, 12/2 yellow biohazard,
12/5 red radioactive) onto one prop had thrown away the marking, which is most of what those three
icons ARE.

**THE PLANNED `edit_image` PASS WAS REJECTED ON INSPECTION, and the reason generalises.** Exporting
the base map (`make model-export label=sewer/drum`) shows a **fragmented UV ATLAS** — circular
lid/base charts scattered through rectangular body panels — not a picture. An image model
regenerates the whole canvas; this file already records gpt refusing to honour even a stated seam
position (asked 768, drew 616). A chart that moves a few texels is a smeared prop. **Do not send a
UV atlas to an image model.**

**ONE HSV PASS DOES BOTH JOBS, and that is a property of this bake worth measuring for.** The rust
and the steel have nearly the same LUMA — 54/44/42 against 44/47/54 — and differ only in HUE: **17%
of saturated texels at hue 0-30 against 71% at 210-240**. So assigning ONE hue to every saturated
texel deletes the grime and applies the livery in the same operation, and the untouched value
channel keeps the dents and weld seams reading as wear. Near-neutral texels (`SAT_MIN` 0.12: dark
lid rims, baked contact shadows) are left alone or the shadows take the paint. `tools/livery.py`,
~90 lines, and it cannot move a texel by construction.

Three labels, all `"src": "sewer/drum.glb"`: **steel** (hue 212, sat 0.22, gain 1.63 → atlas
72.6/79.4/87.3, luma 78.5), **bio** (hue 48, 0.62, 1.85 → 99.2/88.4/52.6, luma 88.1), **rad**
(hue 6, 0.58, 1.97 → 105.9/62.7/59.6, luma 71.7). No `baseColor` on any: the gain lands the atlas
ON the ~78 indoor band `facility/lab-trolley` fixes, so the map IS the shipped albedo. Built chroma
**45.9 / 45.5** against the sewer drum's **6.3**, texels/tri 54, in band. Red takes the HIGHEST gain
and still lands the LOWEST luma — at hue 6 the G and B channels carry almost none of the luminance —
and is left there, because a red drum brighter than the yellow beside it reads as orange.

**`tris` IS LOAD-BEARING AND WAS GOT WRONG ONCE, which is the entry's second lesson.** `propstat` on
the BUILT sewer drum prints "UNDECIMATABLE, generate AT the budget with `tris -1`". That is advice
about the 4,826-tri file it was handed; `models-src/sewer/drum.glb` is the **100k MASTER**, so `-1`
built a **97,214-tri** drum. `sewer/drum`'s own 1200 is what meshopt floors to 4,826. **Read a
`propstat` line against the file it was run on.**

**A LIVERY IS A DRAW CALL and there is no way around it**: `Models.instanced` is keyed by path and
carries no per-instance UV offset. But an EMPTY one is free — `instanced` returns early on zero
placements and adds no mesh, so a livery this compound does not deal costs nothing. Verified live:
**steel 0, bio 1, rad 3**, exactly the atlas histogram, so this seed pays **2** batches and not 3.
`EXTRA`, `FacilityWarm` and `FacilityArea` all derive their rows from `FacilityDeco.PROPS`, so a
fourth livery is one table row.

## Four atlas frames on one emitted kind: the twin-door lab case (2026-09-06)

`entities64` 8/0-3 draws a fridge, a glass-door freezer, a twin-door storage cabinet and a biohazard
safety cabinet. At 64 px those are ONE silhouette with a different decal on it, so they became ONE
kind — `FIT_CABINET` — with one authored front and two tiling swatches, not four of anything.

**One 1024 packed sheet, laid out like the bookcase's**: the front as a tall sub-rect on the left,
the side swatch top-right, the top swatch bottom-right. `quality: "medium"`, **$0.056**.

**THE MODEL MISSED THE STATED SPLIT BY MORE THAN LAST TIME, and the sheet has a RIM as well as a
seam.** Asked for three quarters (768) it drew the vertical seam at **587** — per-column mean |diff|
**75.4 at 566**, which is the front's own right upright, and **43.3 at 587**, which is the split —
and put the horizontal one at 512 as asked. On top of that a 1px dark rim runs along the top, bottom
and left edges (col 0 at **93** against the sheet's 123). Every crop insets from both. The front is
`[2,2,584,1022]`, and **584 x 1022 is exactly 4/7**: that is what `DECO_CABINET_W` is locked to, the
third aspect lock in this family. The swatches are `[600,40,400,400]` and `[600,560,400,400]`,
wrapH/wrapV **3.1-3.5**, in line with what a packed quadrant costs elsewhere.

**THE HEIGHT CARRIES THE EMPHASIS, NOT THE WIDTH.** 4/7 is narrower than any of the four sprites read
(2.25 / 1.64 / 2.53 / 2.86 units over their alpha bboxes), and the width is not free — it is the
lock. So `DECO_CABINET_H` takes the same flat **1.2** the bookcase beside it took, `2.86 * 1.2 =
3.43`, and the width follows at **1.96**. Under `WALL_H` 6.0, dealt on the HIGH list only so there is
never a sill to clear, and it still slides inside the 3.0 a run-end wall cell offers.

**THE FIRST LIFT IN THIS FAMILY THAT DARKENS.** The drop came back at **0.180 linear**, the palest
surface generated for this compound, against a `facility/wall-room` of **0.1375** — and a fitting
cannot read lighter than the wall it stands against. g **1.394 / 1.632 / 1.624** (over 1 darkens)
lands **0.0952 / 0.0948 / 0.0860**: just over the shelving steel's 0.1034, clear of the bookcase's
0.0852, the top authored darker than the front because a horizontal face keeps 0.71 of its albedo
against a vertical's ~0.2. All three solved off `built_linear` in the manifest rather than a
throwaway measuring script — the first change to use the tooling pass that put it there.

**A CAST KEPT ON PURPOSE, against this file's own re-roll-over-6 rule**: chroma **9.6** with G over B.
The four icons it replaces are pale grey-green themselves (atlas chroma **15.2 / 11.8 / 13.6**), so a
neutral roll would have been the wrong OBJECT. The rule is about a cast the art did not ask for.

**+3 CALLS AND NO PROGRAM.** A/B'd on the three meshes' `visible` at a pinned free-cam pose:
**81 → 78 → 81**, exactly +3 for the compound's 3 units and **24 tris**. The material config is the
bookcase's exactly, and that is verified rather than argued —
`renderer.properties.get(mat).currentProgram.cacheKey` is byte-identical to the bookcase front's — so
`FacilityModel.demo` needs no cell for the new kind. Controls unmoved: `cabinets` 30, `boards` 2,
`exits` 16, `shadows` 401, `grime` 528.

## A PROMPTED "seamless tile" is not one, and the object pays for it: the machine casing (2026-09-06)

The last seven floor frames: `entities64` 8/4-8 (hopper filler, analyser console, CNC enclosure, gear
press, bench lathe) on the HIGH list at **2.81** units, and 12/0 and 12/6 (radiation placard panel,
grey appliance cabinet) on the LOW one at **2.06-2.25**. Two heights, and every earlier kind in this
family would have needed two of everything for that.

**THE PLAN WAS A TILING FRONT, AND IT SHIPPED WRONG.** An authored 0..1 front locks the face aspect
(`DECO_SHELF_D`, `DECO_BOOKCASE_W`, `DECO_CABINET_W` are all that lock), so two heights would be two
kinds, two crops and two images. A machine's read looked like a RHYTHM — louvre band, panel joint,
control strip — so `face`/`cap` replaced `pane` and both heights came off one image. Reported from
the game within one pass: **"both top and front are misaligned"**, and on another unit a lid
**"missing corners"**.

**THE PROMPT ASKED FOR A SEAMLESS TILE. THE MODEL DREW A COMPOSITION.** All three quadrants carry
DISCRETE, PLACED features — a control strip of buttons and two round dials along the bottom edge, a
bolt column down each side, two grille patches and a cable gland on the lid — and a swatch with
placed features in it can only be shown WHOLE. `FacilityGeom.face`/`cap` divide the WORLD coordinate
by the period, so every unit took a different sub-rect at a different phase: a dial cut in half, a
bolt column landing mid-face, the lid's corner bolts outside the rect entirely. **Wrap error said
nothing about this** — wrapH/wrapV measured **2.9-4.9 / 2.6-3.0**, better than a packed quadrant
usually costs, because wrap only measures whether the EDGES join. It cannot see that the interior is
a composition. *Look at the drop and ask what is placed in it; the tiling statistic will not tell
you.*

**The fix was the mapping, not the art.** Every face maps 0..1 — `pane` for the front and both
flanks, `localCap` at the unit's own width for the lid (that helper gained a period argument; the
rack still passes `DECO_RACK_TILE` and keeps its u 0..0.75). Verified live: every UV in all three
merged buffers spans **exactly 0 to 1**.

**And 0..1 on a square image makes the object a CUBE.** That is the aspect lock arriving by the back
door, and it costs nothing here: four of the seven sprites this replaces measure square themselves
(61x61, 60x60, 60x60, 48x48), so `DECO_MACHINE_SZ` **2.8** (their own 2.81) and
`DECO_MACHINE_LOW_SZ` **2.2** are one number each for all three axes. **The second height is still
free off one image** — a square image fits a square face at any size — so the plan's actual goal
survived; only its mechanism was wrong. Verified in the built geometry: one unit at 2.8 and four at
2.2, cubic. The `fit` squeeze is no longer free (a narrowed front would now stretch), same as the
bookcase and the cabinet; at 2.8 against the 3.0 a run-end wall cell offers it has not fired.

**The 2x2 came back honest for once** — vertical seam at **509/513**, horizontal at **508**, against a
per-column background of 2.2 — but it carries a dark **4px rim down the LEFT and RIGHT edges only**
(col means 22.5 / 13.6 / 22.8 at the left, 24.3 at 1021) and none top or bottom. Crops
`[6,4,500,500]` / `[516,4,500,500]` / `[6,516,500,500]`. **$0.056, medium.**

**The darkest drop this compound has ever taken**, and the mirror of the cabinet's problem one entry
up: **0.0268 linear**, below even the server rack's own front (0.0473). g **0.722 / 0.730 / 0.750**
brightens to **0.0651 / 0.0701 / 0.0632** — a machine casing between the rack and the bookcase
(0.0852). Side over front by the rack's own margin, because a front that is half black louvre slot
measures darker than the plain flank it shares paint with; top authored 0.90x under the side for the
horizontal/vertical albedo ratio. Chroma **9.1** with B over G over R kept, the cabinet's call in the
other direction: the frames it replaces run 0.6 to 32.4 and the two blue ones are the cool-steel read
the prompt asked for.

**THE ROW-12 PLACEMENT TRAP WAS REAL AND THE FALLBACK LOOKED WRONG.** `nextToWindow` FORCES the low
list beside glazing and `isSolidWall` rejects `Wall.WINDOW`, so `FacilityDeco.wall()` returned -1 and
the "stood square in the cell, dir 0" fallback fired. On screen at (46,28) the machine floated a
clear half cell off the glass with floor all round it. Fix: `wall()` now takes masonry on any hand
FIRST and falls back to glazing, for a LOW kind only — the rule `placeRound` already ran the drums
and bins on. The halo is the part that does NOT follow: `hasWall` became an `isSolidWall` test of the
chosen hand rather than `dir >= 0`, or a wall shadow lands on the pane. The plan had assumed a
2.2-unit machine clears the sill; measured, **the sill is 0.93** (a 4.14-tall pane centred in
`WALL_H` 6.0), so it takes the bottom third of the opening — which is where a machine in a lab
stands anyway, and a HIGH fitting still refuses glazing outright for the same arithmetic.

**TWO BLINK PATTERNS OFF ONE PROGRAM, and the vertex channel that pays for it.** The 0..1 front put
the control strip at a FIXED place on every unit, so its lights could be read off the art exactly:
per-column means over the built 500 in the button band (py 438-474, background 72.2) give five dark
runs 19-24 px wide at u **0.132 / 0.218 / 0.304 / 0.767 / 0.853** — the three-button bank, then the
two-button bank. The 5-9 px runs between them at u 0.43-0.66 are the DIALS and are skipped.

A rack's ports are independent traffic and its square wave says so; a machine panel is a SEQUENCER,
and five specks twinkling at random on one reads as a small rack. So the machine runs ONE lit dot
along the row with a decaying tail, `(1 - fract(t*chase - phase))^6` — 0.26 one slot behind, 0.12
two. Both patterns share the same buffer, mesh, material and clock as the rack's lights, so this is
**+0 draw calls and +0 programs** (91 either way, one `decoled` cache key). The mode had to travel
per VERTEX and there are only three channels, so **it rides the hue**: `vColor.b` in 0..1 is a rack
burning `mix(A, B, b)`, in 2..3 a machine burning `mix(A, B, b - 2)`. Safe because the include that
would otherwise sample this attribute is the one being replaced, and a varying is not clamped — a 2
reaches the fragment stage untouched. Both branches are evaluated and `mix`ed rather than branched
on. One per-cell offset added to every slot's phase, or every machine in a room steps in lockstep
off the shared clock. Verified live: 73 quads in the lamps mesh, **25 machine** (5 units x 5 slots)
and 48 rack.

**+3 CALLS.** A/B'd on the three meshes' `visible` at a pinned free-cam pose: **102 → 99 → 102**
tiled, **132 → 129 → 132** after the remap, for 5 units and 40 tris either way — the mapping changed
no geometry, and the lights added none. No new program (the bookcase's material config again). Controls unmoved:
`cabinets` 30, `boards` 2, `exits` 16, `shadows` 401, `grime` 528; console at 0 errors. That closes
the FLOOR families — rows 8, 12 and 13 are entirely 3D, and the 43 TABLE frames stay sprites by
decision.

## A window looked the same from both sides, and splitting the buffer was the WRONG fix (2026-09-07)

Reported from the game, standing in a lab room: every pane read as the same white glowing slab from
inside as from outside, with the same bloom halo on the masonry — and the lot seen through the glass
came out WASHED BRIGHTER instead of darkened.

Cause is one line of `FacilityGeom.structure`: a run's exterior and interior quads go into the same
`MeshBuf`, picked by RUN LENGTH alone, so one material serves both facings. Measured live — **4 pane
meshes**, 30 + 14 = **44 quads on the 3-cell art (22 runs x 2 faces)** and 18 + 24 = **42 on the
2-cell (21 x 2)**, and 22 + 21 = **43** = `__facility().windows`. All four at `emissiveIntensity`
2.2, `emissive` ffffff.

The obvious fix is a second buffer and a dark interior material. **It is wrong, and the second half
of the ask is what proves it**: the OUTER face must also stop blooming indoors. The camera pitches
51 degrees down from outside the building, so the face it reads at the NEAR wall of the room the
player stands in is the EXTERIOR one, and the interior face cannot be seen at all while a structure
is solid — its own roof is over it. Both faces want the same value in both states. The split would
have bought nothing and cost 4 → 8 pane meshes, a program, and the shadow caster:

**THE CASTER IS THE INTERIOR QUAD.** `side` is `FrontSide`, so three forces `shadowSide = BackSide`
and the depth pass draws the face pointing AWAY from the moon — the inward one. An interior-only
mesh with `castShadow` off re-opens the "window holes in building shadows" bug the pane was given
`castShadow = true` to close in the first place.

Landed as one per-structure material lerp instead. `Shell.panes` carries the structure's 0..2 pane
materials, `FacilityArea.glaze` drives `emissiveIntensity` **2.2 → 0** and `color` **ffffff →
0x39424a** on the roof fade's own `REVEAL_MULT` clock.

**Keyed off the player's OWN CELL (`model.owner`), NOT off `reveal`.** `reveal` also opens a
structure the player is merely peeking into from the lot (`PEEK_CELLS` 3), and dimming a facade you
are standing outside and looking at is the one thing this must not do. It is the same easing loop
and a second target array, not a second clock.

The bloom half needs no pass change: bloom is ONE global `UnrealBloomPass` (threshold **0.9**,
strength 0.25) with no layers and no selective mask, so "stop blooming" is arithmetic on the pane.
The art's glass band is linear 0.26-0.62, so **0.9 / 0.62 = 1.45** is where the brightest texel stops
crossing — anything under that is dark enough for the bloom pass and nowhere near dark enough for the
eye, which is why this goes to 0 and not to 1.4.

Darkening the lot THROUGH the opening is then free: the glass half of the art is alpha 128
(`glass_alpha`), so the pane composites as `0.5 * tint + 0.5 * outside`.

Verified live, standing in the south lab: that structure's two meshes (14 + 24 quads) read
`emissiveIntensity` **0** / colour **39424a**, the other structure's (30 + 18) stay **2.2** /
**ffffff**, and `FacilityEntry`'s own opaque booth band is untouched at 1.4. `transparent`,
`alphaTest` 0.02 and `castShadow` unchanged on all of them. **+0 meshes and +0 materials by
construction** — nothing is created, four existing materials take different uniform values — so
there is no draw call and no program to A/B. No geometry, no art, no persisted change.

> The `material.color` half of this was WRONG and lasted one build — see the next entry. Everything
> else here stands: one material, the interior quad as caster, and `model.owner` over `reveal`.

## `material.color` cannot dim glass without dimming the frame — the alpha already knew (2026-09-07)

Reported one build after the entry above: **"the window frames also go dark"**. Correct, and obvious
in hindsight — `material.color` multiplies the WHOLE map. The art's frame members are already sRGB
**16-127**; multiplied by 0x39424a (linear ~0.036/0.050/0.066) they land near zero, so the mullions
crushed into the glass and every opening read as one flat black rectangle instead of glazing in a
frame.

The thing that separates them was already in the file and had already been measured twice for other
reasons: **the ALPHA**. `tools/textures.py`'s `glass_alpha` took the bright half of the art to 128
and left the frame at 253-255, off a luma histogram that splits outright (frame 16-127 at 30.6%,
glass 144-207 at 58.8%, a 0.2% valley between). It is a PER-TEXEL split, so nothing but a fragment
can read it — which is the whole reason this had to stop being a material property.

New `FacilityGeom.glaze` folds the dimmer into the pane's own shader, installed BEFORE
`VisionMask.patch` so the mask chains onto it:

- `<map_fragment>` — `diffuseColor.rgb *= mix( vec3(1.0), paneTint, paneGlaze * paneGlass )`, where
  `paneGlass = smoothstep( 0.90, 0.70, diffuseColor.a )`. That anchor is the only point the alpha
  means the ART's alpha, and it runs BEFORE `<alphatest_fragment>`, which this must not disturb —
  only `.rgb` is touched. `smoothstep` and not `step`: bilinear filtering leaves intermediate alphas
  along every member edge and a hard cut draws a bright fringe round each mullion.
- `<emissivemap_fragment>` — `totalEmissiveRadiance *= 1.0 - paneGlaze`, the WHOLE pane. The frame
  never crossed `BLOOM_THRESHOLD` at any intensity, so there is nothing to preserve there.

**The per-frame cost went DOWN, not up.** The transition is now one shared uniform per structure
(`Shell.panes:Array<Material>` became `Shell.glaze:Dynamic`), so `FacilityArea` writes ONE float per
structure per frame and touches no material property at all — `emissiveIntensity` stays 2.2 and
`color` stays ffffff for the life of the area. The `Three.hx` `color` extern added a build ago was
deleted again with it.

**+0 programs**, and the cache key is why: `customProgramCacheKey` returns `'paneGlaze'`, which
`VisionMask` chains, so the four panes read **`paneGlazevisMasksindoor`** against the entry booth's
**`visMasksindoor`** — distinct, so three can never hand a pane's program to a plain masked material
(the trap `VisionMask` documents). Live: **90 programs**, the same count the colour version ran at,
60 FPS, 118 calls.

Verified live standing in structure 0 of three: `inside` **[1,0,0]** = `glaze` **[1,0,0]**, so the
hangar and the far lab stay lit and blooming while the room the player is in reads dark glass with
the frame plainly standing off it. `transparent`, `alphaTest` 0.02 and `castShadow` unchanged on all
four panes.

**The threshold alone left a bright hairline, and the mask had to be GROWN.** Reported straight after
as "small issues on the tex": the alpha split is exact in the SOURCE and fuzzy on SCREEN — the pane
minifies through mipmaps and samples bilinearly, so every glass/member boundary arrives as a ramp
from 0.5 up to 1.0 across a texel or two, and the outermost row of each light reads as frame at the
0.90 threshold and stays undimmed. Widening the smoothstep band cannot fix it: to catch that row the
band has to reach past the frame's own **253/255 = 0.992** and then the whole frame dims, which is
the bug this entry started from. So the mask is DILATED before it is thresholded — `paneA` is the
`min` of a plus-shaped tap at `FacilityStyle.WINDOW_TINT_GROW` **2.0** texels, i.e. a fragment counts
as glass if anything within two texels of it is. Four taps and not eight: the members are a mullion
and a rail, both axis-aligned, and a corner nick two texels across is not visible. `textureSize( map,
0 )` rather than a uniform, because the art is cropped to its own alpha bbox at LOAD and its size is
not known when the material is built — and `float( .. )` wraps the constant, since Haxe prints 2.0 as
"2" and a bare integer over a vec2 leans on ESSL 3.00's implicit conversion. Live after: **90
programs**, 112 calls, 60 FPS, 0 console errors, `inside` **[1,0,0]** = `glaze` **[1,0,0]**.

## The room floors get MARKINGS, and they ride the mesh the parking lot is already struck on (2026-09-07)

> SUPERSEDED by "An aisle is marked at its EDGES" below, which reversed both of this entry's figures
> — reported from the game within one build. The measurement of the two surfaces, the decomposition
> method and the `ContactMask`-vs-`VisionMask` trap all still stand.

Phase 1 of the lab-interior pass. Measured first, by hiding a layer, diffing the frame and restoring:
standing in room 109 (10x3 lab, cell 8,14) the **room walls are 10.25% of the frame** and the **room
floor 12.05%** — 22% between them, and both are undressed. A room wall carries the damp band and
nothing else (the exit signs are `Surf.LINO`-gated, the notice board is entrance-only); a room floor
carries the contact field and the spotlight falloff and **no decals at all** — `FacilityDebris` is
lot-only and `FacilityPaint` was asphalt-only. The wall also renders **2.8x darker than the floor**
(srgb 53.4 / linear 0.0417 against 93.9 / 0.1163) despite the authored ladder saying the opposite
(`wall-room` 0.1375 > `floor-tile` 0.1185): `IndoorMask` fill is ambient-flat and the ceiling spots
land on the floor.

**+0 DRAW CALLS, +0 ART, AND THE +0 IS THE WHOLE POINT.** `FacilityPaint` already merges the road's
lane lines and the lot's bays into ONE area-wide mesh in `city/ground-road-paint`, already
`VisionMask`-patched — and `VisionMask.patch` calls `IndoorMask.patch` (`VisionMask.hx:921`), so that
mesh lights correctly indoors with nothing added. A room floor takes the same worn paint a lot does,
so the indoor half is a third emitter into the same buffer. Live: **112 calls before, 112 after**;
hiding the whole mesh reads **111**, so the pass is one call and it was already being paid.

Two figures, both OUTLINES — the paint is 0.2405 linear against a room floor at 0.1185, so anything
filled would be a white slab at twice the value of everything round it:

- a **keep-clear box** on the room side of a doorway: two sides `MARK_KEEP_D` 2.4 deep plus the line
  closing them. `MARK_KEEP_W` **3.0** is deliberately under a cell's 4.0 so the sides stand inside
  the opening rather than out on the flanking masonry.
- an **aisle line** down a room's long axis, `MARK_AISLE_MIN` 5 cells minimum, stopped
  `MARK_AISLE_INSET` 1.2 short of both end walls.

**THE PAINT MESH TAKES `VisionMask` BUT NOT `ContactMask`**, and that is what both clearances are
for. Only the three interior FLOORS carry the contact patch (`FacilityGeom.addFloor`), so a line laid
into a wall's crease draws at full value over floor that has been darkened and reads as sitting on
top of the shading. The one place the box is allowed to touch the wall line is its threshold, and
that is correct rather than lucky: a doorway carries no masonry at floor level at all —
`FacilityDetail.masonry` skips it and `FacilityGeom.floorStrips` runs the floor straight through.

Gated on **`Surf.TILE` and nothing else**, the gate `FacilityKit` runs on: every corridor family is
gated on `Surf.LINO` (casework, dead-end bins, directional signs), so this cannot collide with any of
them however they are retuned, with no shared claimed-cell list and no ordering between builders.
`freeRoom` also asks `isWall`/`isDoor` separately — a door cell finalises to corridor lino and a wall
cell keeps whatever surface it was laid over, so the surface alone answers neither (the pair
`FacilityExit.corridor` makes for the same reason) — plus `isTable`/`isFitting`. **The aisle needs no
stale-`generatorInfo` guard** where `FacilityLamps.lit` does: it walks `m.rooms` but strikes per CELL
off the saved grid, so a rect that no longer describes the building lays nothing, one cell at a time.

**Verified by DECOMPOSITION, before looking at it.** The mesh splits cleanly by y — **456 verts at
0.0300** (indoor, `PAINT_Y` off a floor at 0) and **888 at -0.1700** (the lot, `KERB_DROP` 0.2 below,
untouched). That is **114 indoor quads = +228 tris**, 0 non-planar vertices, and **every one exactly
0.180 thick** (`LINE_W`). The length histogram is the real check and it accounts for all 114:
**2.40 x 22** (11 boxes x 2 sides), **3.18 x 11** (`MARK_KEEP_W` + `LINE_W`, one closing line each),
**2.80 x 20** (10 rooms x 2 ends trimmed by the 1.2 inset) and **4.00 x 61** (whole-cell aisle
segments). So `marks` **92 = 11 boxes + 81 segments**. Two of the twelve rooms take no aisle end: one
is the HANGAR, which is `Surf.CONCRETE` and correctly strikes nothing at all.

Rendered: the line reads **srgb 148.8 / linear 0.3022** against the floor beside it at **104.3 /
0.1417** — **2.13x in light**, the authored 2.03x carried through, and far under `BLOOM_THRESHOLD`
0.9. Reach **0.48% of the frame at delta > 8, max delta 180/255, mean 39.8 over covered pixels** —
small area, hard local contrast, which is what a placed line is. Controls unmoved: `boards` 2,
`grime` 528, `cabinets` 30, `exits` 16, `shadows` 401. Nothing persisted, so no Saver/Loader change
and every compound already saved gets its markings the moment it is drawn again.

`__facility()` gains **`marks`**, a static on `FacilityPaint` in `ContactMask.count`'s shape: the
indoor half shares its mesh with the lot's own lines, so nothing in the scene separates the two and
this is the only count of it.

## An aisle is marked at its EDGES, and the marking convention is a colour ladder, not a taste (2026-09-07)

Both figures of the entry above came back from the game as wrong, and the reason each was wrong is
worth more than the fix.

**A CENTRE LINE IS ROAD LOGIC.** A lane divider only means anything where two streams pass in
opposite directions; indoors nothing divides. What a building marks is a strip that has to stay
CLEAR — a zone — so the marking is a PAIR of lines bounding the walkway. OSHA 1910.22(b) requires
permanent aisles be marked and fixes neither colour nor shape, but the convention every warehouse
and lab runs on is unambiguous about both: **yellow = aisles, traffic lanes, work cells; white =
equipment and fixtures; red = fire equipment**, with ANSI Z535.1 fixing yellow as caution and OSHA
1910.144 red for fire equipment. So the aisle went yellow and the lot's bays and the road's lane
lines stayed white — which is what they should always have been.

**AND A KEEP-CLEAR BOX DOES NOT BELONG TO A DOORWAY.** Zones belong to fire equipment, electrical
panels and exits. Signing every interior door is the same error `FacilityExit` already recorded from
the other side (NFPA 101 wants a door that could be MISTAKEN for an exit marked NOT AN EXIT), so the
per-door box was cut outright. It comes back in a later phase attached to real equipment.

**TWO MESHES, SPLIT BY COLOUR AND NOTHING ELSE: +1 CALL, +0 PROGRAMS.** One shared
`city/ground-road-paint` map, two `color` uniforms — `color` is a Lambert UNIFORM and not a program
key, so the second mesh compiles nothing. Measured **112 → 113 calls, 90 → 90 programs, +732 tris**
(366 quads, exactly one per segment). Rendered, the yellow reads by HUE rather than by value:
**rgb 124/113/32, chroma 91.5, linear 0.1663** against a floor at **0.1368, chroma 21.2** — only
**1.22x** in light where the white version was 2.13x, so it stops reading as a light strip and starts
reading as paint. That is the accent-against-the-rig rule doing exactly what it says: the compound is
lit `0x46536b` / `0x8294c0`, so a warm mark survives on chroma with almost no value to spare.

**THE PAIR'S OFFSET IS DERIVED, NOT SET.** `reach` walks out from the middle until something stops it
and reports WHAT stopped it, because the two answers take different clearances. Rooms take the
MINIMUM reach over the whole run, so the pair comes out straight where a per-cell edge would wobble
at every bench end; a cell whose middle is not free breaks the run instead of collapsing it.

**`MARK_FURN_CLEAR` IS A CAMERA NUMBER AND THE FIRST VALUE MADE THE NEAR LINE INVISIBLE.** 0.3 was
reasoned from "nothing stands off the front of a bench" and it is the wrong question. Measured in the
frame by scanning rows for `(r+g)/2 - b`: the FAR line banded over its whole run and the NEAR one
only in the gaps between benches — it was inside the bench's own occlusion. A worktop is
`WorldCtx.ground` **2.0** tall and overhangs its cell by `BENCH_LIP` 0.2, and `CAMERA_FACILITY`
pitches between `atan(20/16)` **51.3°** and `atan(48/16)` **71.6°**, so a bench hides
`2.0 / tan(pitch)` = **1.60 / 0.91 / 0.67** units of the floor behind it. At **1.2** both lines band
across the full width — verified at three x windows, `(501-508, 546-553)` at every one. The wall
clearance is a different number for a different reason and stayed at 1.7: it clears `CASE_D` 1.4 and
keeps the paint out of the contact crease.

**CORRIDORS ARE IN, AND THEY NEEDED NO CLAIMED-CELL LIST.** The obvious objection to a fourth family
on corridor lino is the three already there — casework, dead-end bins, directional signs. Everything
those stand is against masonry, and `MARK_WALL_CLEAR` 1.7 clears `CASE_D` 1.4 outright, so a
clearance replaced a coupling. A corridor is also in no list anywhere and is an L, a T and a ring as
often as a length, so it is read per CELL off the two runs through it — the SHORTER is the passage's
cross-section — which is `FacilityLamps`' own reading of a corridor cell. Emitted once per section
and not once per lane, or a two-wide corridor lays the same pair twice, coplanar.

**AND THE HOLE IN THE LINE WAS A GRATE.** Reported from the game as a gap with nothing visible in it,
and that is exactly what it was: cell (4,14) is `TILE_FLOOR_TILE_GRATE2` → `Surf.GRATE` with **no
`FloorDrain` object on it**. The generator lays a grate tile in every chemistry lab and stands a
drain on it about a third of the time, and `FacilityGeom.floorBuf` deliberately routes GRATE to the
ROOM floor buffer — a drain is a fitting IN the floor, not a floor of its own — so a bare grate cell
draws as ordinary tile. `FacilityModel`'s own comment already stated the rule the first build broke:
*the surface says where a drain COULD be and the object says where one is.* `freeFloor` now accepts
GRATE and rejects `m.drain`. Verified: room 109's run comes back **10 segments per line, unbroken
through col 4, symmetric at z −143.70 / −140.30**.

`marks` **366**, controls unmoved (`boards` 2, `grime` 528, `cabinets` 30, `exits` 16, `shadows`
401). Still nothing persisted.

## Three reports off the aisle build, and all three are one question asked wrongly (2026-09-07)

Reported from the game standing in the corridor: *"each door has a line near it moved towards it"*,
*"wall ending one triangle looks fine, the other one has line moved — other corridors ending in a
wall/window do not even have these additional lines, which is correct?"*, and *"i thought yellow
lines should start at the door, no? they dont"*. Diagnosed off the emitted geometry and the tile
grid, not off the frame.

**A DOORWAY IS NOT MASONRY, AND `reach` WAS ASKING `isWall`.** Measured: the N–S corridor's lane edge
sat at col **14.30** on row 14 and at **14.425** on every other row of the same run — a step of
exactly **0.5**, which is `MARK_WALL_CLEAR - MARK_FURN_CLEAR`. Row 14 is the one beside the door at
(13,14): `isWall` is false at a door cell, so the clearance flipped to the furniture number and the
edge jumped toward the opening. **The question is "did FURNITURE stop me", not "is that a wall"** — a
wall, a doorway, a window cell and the edge of the grid all END the floor, and only a bench or a
fitting is a thing STANDING on floor that carries on underneath. `Reach.wall` became `Reach.furn`,
read off `isTable || isFitting`.

**`reach` CANNOT TELL A PASSAGE FROM A BRANCH, AND AT A T-JUNCTION IT MEASURED THE BRANCH.** The
stray perpendicular lines were emitted by cells **(14,11)** and **(15,11)** — where the E–W corridor
meets the N–S one. Their perpendicular run walked four cells DOWN the side corridor, so the
"cross-section" came back **5 and 7 cells** and the far edge landed at row **15.70**, four cells away
and nowhere near the cell that drew it. Reconstructed from the arithmetic before it was fixed:
`e1 = r + 1 + hi.cells - clear` solves to `r + hi.cells = 15.0` at r = 11, hi = 4. New
`MARK_LANE_MAX` **3**: wider than that is a junction or a hall and takes no lane at all, which is
also what a real marked floor does — a lane cannot run across the junction it ends at. **So the
corridors with no extra lines were the correct ones**, and the answer to the report is that the
junction should have had none either.

**AND A ROUTE GOES THROUGH THE DOOR.** `MARK_AISLE_INSET` was applied to both ends of every run
unconditionally, so a lane stopped 1.2 units short of the one opening it leads to and read as a line
that leads nowhere. The inset is now taken only where MASONRY ends the run: at a doorway the line
carries to the threshold. A doorway also holds no masonry at floor level (`FacilityDetail.masonry`
skips it), so there is no contact crease to keep off there either — the same fact the cut keep-clear
box was standing on.

Verified by re-dumping the same region. The N–S corridor pair now reads **14.40..14.45 and
15.55..15.60 on every one of rows 12, 13, 14, 15** — no step at the door — and both lines run
`r[15.00..16.00]`, into the doorway at (14,16) rather than stopping at 15.70. Room 109's pair runs
`c[..13.00]` into its own door at (13,14), where room 110's west end correctly keeps its inset
because col 16 there is masonry. **Zero corridor cells now carry both an X and a Z quad**, against
four before (14,15 / 15,15 / 24,42 / 34,42).

`marks` **366 → 358**, the eight segments the junction cap removed. A/B interleaved on a pinned pose:
**104 → 105 calls, +716 tris**, still +1 and +0 programs. Controls unmoved: `boards` 2, `grime` 528,
`cabinets` 30, `exits` 16, `shadows` 401.

## Floor marking is a NETWORK, and four reports were four ways of saying it wasn't one (2026-09-07)

Four reports off the aisle build: should the lines connect, there are no corners, some doors have a
line in front and others don't, and should a line start from a door at all. The last two are design
questions and the convention answers both. A line does NOT start at a door — the lines are the
aisle's EDGES and an aisle starts where the route starts — but an aisle exists to serve traffic, so
one that ends at a door runs to the threshold and one a door opens onto from the SIDE breaks for the
door's width. That break is the missing figure. And corners: a corner belongs only at an L, where an
aisle changes direction with no through route. **Measured the corridor topology first — dumped the
LINO cells: every junction in this generator is a T or a cross, zero L-bends.** So no corner is
called for anywhere here; the correct figure at every meeting is a break, and what shipped was the
right figure at the wrong size.

Three defects, all one cause. **The whole cross-section was the wrong question.** The pass asked
`lo.cells + hi.cells + 1 > MARK_LANE_MAX` and rejected the cell, which at a T drops BOTH lines though
the branch opens off only one — so the through lane broke on its far side too, over cols 14..16 and
19..21, and over the *union* 24..27 of two branches that are not even opposite each other. Asking
per EDGE answers all of it: `cells == 0` on a side means this cell touches that boundary, so the edge
is struck there and nowhere else. A two-wide corridor has each cell strike one line, a three-wide
leaves its middle cell striking neither, and at a branch mouth the near side carries straight past
while the far side strikes nothing. It also makes the old stray stub impossible by construction — an
edge can only land on the boundary of the cell that emitted it — so `MARK_LANE_MAX` is deleted along
with the bug it guarded.

**A branch stopped 1.7 units short of the line it met**, at the cell boundary rather than at the
through lane's line. `trim` now has four answers instead of three: passage carries on → 0; masonry →
the inset; doorway → 0; **boundary ends but floor does not → NEGATIVE `MARK_WALL_CLEAR`**, because
the through lane's line sits exactly that far past the cell boundary. The mouth mitres.

**And most rooms should not be marked at all.** Marking is for TRAFFIC; the gap between two bench
runs is a work aisle. `MARK_LANE_MIN` 1.5 → **4.0** (one clear cell), which drops the 1.6-unit pairs
that read as one thick line — 6 rooms of 12, including the two reported. The opposite failure needed
its own knob: a big lab has its benches against the walls, so the derived pair landed **25.6 units
apart in a 9x10 room** and outlined the room instead of marking a route across it. `MARK_ROOM_MAX`
8.0 pulls both edges in equally, keeping the lane centred where the clear floor put it.

Verified by re-dumping every segment as cell coords. Branch `col 14.42` runs `11.58..14, 15..16` —
meets the spine's south line at **11.58** (was 12.00), breaks at the door (13,14), runs into the door
(14,16). Spine `row 11.58` runs `3.3..14.42, 15.58..22, 23..27` — breaks over the mouth exactly and
meets both branch lines, plus a break at the side door (22,12). Spine `row 9.42` now **carries across
col 14** and breaks only at cols 7, 15, 24 (its three side doors) and at the cols 19–20 mouth. In
structure 2 the two spine lines break at *different* columns for the first time — `row 31.43` over
25..26 and 35..36 (the north branches), `row 33.57` over 24..25 and 34..35 (the south ones). Rooms:
5 marked of 12; room 102 clamped 39.3/45.7 → **41.5/43.5**, room 105 36.3/38.7 → 36.5/38.5.

`marks` **358 → 246**. A/B interleaved ×3 on a pinned pose: **104 → 105 calls, +492 tris**, still +1
and +0 programs. Controls unmoved: `boards` 2, `grime` 528, `cabinets` 30, `exits` 16, `shadows` 401.

Follow-up, reported from the game as bends that overlap. **A junction mouth's two lines are a BEND,
and run to the same point they lie ON each other** — coplanar at `PAINT_Y`, the intersection is a
quarter of a line width of doubled paint at every corner in the compound. Made a BUTT JOINT instead:
the X-running line runs on to the FAR edge of the line it meets (`-(MARK_WALL_CLEAR + LINE_W/2)`) and
the Z-running one starts at that far edge (`-(MARK_WALL_CLEAR - LINE_W/2)`), a half width apart, so
no overlap and no gap. Which of the two extends is arbitrary and has only to be the same everywhere,
or a compound's bends are made two different ways. Verified directly on the mesh by intersecting
every quad pair in XZ: **0 overlapping pairs, 207 touching**, against 246 quads. Corner reads
`row 11.58` → 14.4425 and `col 14.42` → 11.6025, exactly `LINE_W/2` either side of 14.42 / 11.58.
`marks` 246 unchanged, +492 tris unchanged, +1 call.

## A keep-clear zone belongs to the EXIT, and the opaque hatch cannot borrow the aisle's map (2026-09-07)

Phase 1a step 1 of the lab-interior plan. The aisle pass had already cut its per-door keep-clear box
on the grounds that a **zone belongs to fire equipment, an electrical panel or an exit — never to a
doorway as such**; every interior door boxed off says nothing, and the floor is marked where
obstructing it is what kills someone. So the input here is `FacilityExit`'s own terminal-door test
(`FacilityGlow.outward` plus circulation behind it) and no placement rule of its own: **6 zones on
this seed**, exactly the terminal half of `exits` 16.

`freeFloor` turns out to BE the "circulation behind it" test with nothing added. The far side of an
exterior door is walkway or lot, neither an indoor surface, and the hangar's shutter has concrete
behind it — so the shutter drops out with no case of its own, exactly as it does for the signage.

**The red is baked into the art and is NOT a `color` tint, and that is the finding.** The plan had
this sharing `city/ground-road-paint` the way the yellow aisle does: one map, one Lambert `color` per
mesh, +1 call and +0 programs. That works for the aisle only because **every texel of that map is
paint**. A hatch's gap has to read as the FLOOR, and a tint multiplies the gap too — the room floor's
0.1163 linear through a signal red is a dark maroon, so the zone would have drawn as a dark slab with
the floor showing nowhere. **One map per colour is what an opaque hatch costs.** It changes nothing
about the bill (same material, same defines, +1 call either way); it changes what a later yellow
panel hatch costs, which is a second gen and not a second uniform. *(That argument holds only while
the hatch is OPAQUE. `FacilityStyle.ZONE_COLOR` carries why it stopped being: a painted gap can match
the floor's value and not its HUE, and cannot serve lino 0.1353 and room tile 0.1185 off one bake.
A cut re-opens the tint; this art's stripes are painted red, so the trade is recorded, not taken.)*

Art: `facility/floor-hazard`, 1k medium, 45° stripes, opaque — `alphaTest` is a program key and this
was the one phase in the set that could have bought a program. It did not: **progs 90 either way**.
The drop came back with the gap at **0.1575 linear** and was pulled to **0.1132** by `lift` 1.18 —
*and that lift was fitted against a WRONG NUMBER, corrected here because it stands in this log: the
corridor lino these zones land on is `built_linear` **0.1353**, not the 0.0749 quoted from the
verdict row above, which was true before the lino was re-rolled blue-cyan and is now stale text
inside `floor-tile`'s own note. So the raw gap was 1.16× the floor, already close, and the lift moved
it to 0.84×. Value was never the failure.* Tiling is approximate and accepted: gpt drew nearer 34° than 45 (6 stripe transitions across
the top edge against 4 down the left), so the two axes cannot both close on a whole period — measured
wrap error 3.1/255 on x and 7.2 on y, which never shows, because a zone is 4×3 units against
`ZONE_TILE` 3.0 and shows about one repeat.

The near edge is the **slab's face and not the cell boundary**. `slab()` returns the lintel box,
whose two perpendicular sides come back inset a unit, so the boundary is under the opening and the
face is where the floor inside it starts; taking the boundary would lay a unit of hatch across the
threshold. Width is the door cell's own exactly, which is what keeps it out of the contact crease —
this mesh carries `VisionMask` but not `ContactMask`, the same reason `MARK_WALL_CLEAR` exists.

**First real claimed-cell coupling in the family.** Markings never cross, and `MARK_WALL_CLEAR` could
not answer this one: it separated the aisle from the casework because everything the corridor
families stand is against masonry, and a zone lies in the OPEN floor a lane runs down. So the zone
pass writes an `Array<Bool>` and the aisle reads it — **at EMISSION and never inside `reach`**, which
is the trap: `reach` walks clear floor to derive where a lane's edges GO, so a zone cell answering
"not floor" there would move a whole section's lines as if a wall had appeared in the corridor. The
zone takes segments out of a line; it does not move the line. It also forces the build order, zones
before aisle in `FacilityPaint.build`.

`marks` **246 → 240**, one per zone cell. `zones` **6**. A/B interleaved ×3 on a pinned pose:
**102 → 103 calls, +12 tris, progs 90 unmoved**. Controls unmoved: `boards` 2, `grime` 528,
`cabinets` 30, `exits` 16, `shadows` 401. Verified no marking crosses another by intersecting every
aisle quad against every zone quad in XZ: **0 crossings**, 240 against 6.

Follow-up, same day, asked as "is that a correct real-world thing? should it be red on lino instead
(with transparency)?" — and the answer to the first half is yes. **Red-and-white diagonal hatch is
the floor-marking code's own figure for "keep clear for safety/compliance"** — in front of
extinguishers, electrical panels, eyewash stations and emergency exits (OSHA 1910.144 / ANSI Z535.1
put red on fire protection and danger; yellow-and-black diagonal is the *caution / physical hazard*
figure and is a different statement). Two legitimate physical forms exist, though, and the opaque
build was neither cleanly: **(a)** a fully painted red/WHITE hatch, contiguous bands, no floor
showing — for which opaque is correct; **(b)** red stripes stencilled on bare floor, which needs a
cut. Ours had red bands with a NEUTRAL MID-GREY band: not white paint, not the floor.

**Went to (b), and the reason is HUE, not value.** With the lino's real 0.1353 in hand the value case
collapses — the raw gap was 1.16× the floor, which is close, and the lift had moved it to 0.84×. What
opaque cannot do is match `facility/floor-lino`'s deliberate pale BLUE-CYAN with a neutral grey band;
a neutral patch on a cyan floor reads as a different material however well the value lands. Nor can
one bake serve two floors: every zone on this compound is on lino at 0.1353, and the storage hatch
planned under drums stands in ROOMS, on neutral floor-tile at 0.1185. A cut serves both.

Source hand-edited to carry alpha; `needs_alpha: true` is the gate (the bake refuses an opaque source
with a named warning, which is what caught it), `lift` dropped with the gap it was fitted to. Built:
**42.8% opaque, 54.3% fully clear**, kept pixels **0.0905 linear** = 0.67× the lino they lie on.
`ZONE_CUT` **0.5** — mid-scale, not `addPane`'s 0.02, which only has a transparent margin to throw
away where this is a real stencil edge. Opaque + `alphaTest`, never `transparent`: one pass, still
writes depth, nothing to sort against the floor under it. `add` takes the cut as an argument and the
two solid paint meshes pass **0**, so they compile exactly what they compiled before — three defines
`USE_ALPHATEST` off `alphaTest > 0`.

**It cost the program the plan budgeted for, and the guess that it would not was wrong.** progs
**90 → 91**; the compound already draws alpha-cut Lambert indoors (`FacilityDeco`'s `DECO_CUT` end
frames, `FacilityGeom.addPane`'s glazing) but those are different permutations — different sides,
different shadow flags, different mask key. It is WARMED, not compiled on first entry: the facility
warm went **83 → 84 programs cached**, so there is no first-entry hitch, and the later storage hatch
now costs +0 programs against it. Everything else held: **102 → 103 calls, +12 tris**, `marks` 240,
`zones` 6, **0 crossings** of 240 aisle quads against 6, controls unmoved.

The cut also **re-opens the `color` tint the opaque gap had closed** — a tint multiplies only what
survives `alphaTest`, so neutral stripes plus one uniform per mesh would serve red and yellow off one
map. This art's stripes are painted red, so a yellow panel hatch is still a second drop. Recorded,
not taken.

## A zone with nothing over it is a stain — the fire points and panels, phase 1a step 2 (2026-09-08)

Step 1 struck a keep-clear hatch inside every exit and left the other two things the convention marks
a floor for standing nowhere. `render.facility.FacilityPoint` stands them: a **fire point** and an
**electrical panel**, both as wall QUADS off ONE atlas (`facility/wall-points`, two 512x1024 portrait
cells side by side, `POINT_U_FIRE` 0.0 / `POINT_U_PANEL` 0.5). Neither earns a glb — the
silhouette-vs-surface guard answers a panel outright (a flat door with a label, no silhouette at all)
and a fire point reads from this camera as its red backboard, since at the measured 65.6° pitch an
extinguisher on a bracket is a few pixels of edge. `FacilityExit`'s shape verbatim, so the whole
family is **one draw call**: **95 → 96 calls, +22 tris** (11 quads), interleaved A/B ×3 on a pinned
pose. `points` **11 = 2 panels + 9 fire points**, `zones` **6 → 17**, `marks` **240 → 229**.

**+0 programs, and this time it is proved by identity rather than by a count.** The material is Lambert
+ map + `FrontSide` + `VisionMask.patch`, `receiveShadow` on, which is the interior-wall permutation:
`renderer.properties.get(mat).currentProgram` is **program 64 for the fitting mesh and 64 for the
benches**, `usedTimes` 53. Worth doing that way — the renderer's `info.programs.length` is a
session-cumulative cache and read across two poses it looked like +1.

**The zones ride the hatch mesh already built, so they are +0 calls**, and they are the ones the aisle
really breaks for: a door zone lies in a cell the lane already ran to and stopped at, where a fitting
stands mid-corridor and `MARK_WALL_CLEAR` 1.7 puts the lane's edge line 1.7 off the same wall face the
zone reaches `ZONE_D` 3.0 from. Without the claim the line runs straight through the hatch. `marks`
dropped by exactly 11, one per fitting cell, and **0 crossings** of 229 aisle quads against 17 zone
quads in XZ.

**The casework collision is real and got a real check, not a clearance.** Casework, dead-end bins and
directional signs are all `Surf.LINO`-gated and a cabinet and a fitting want the same wall face —
`MARK_WALL_CLEAR` works for the aisle only because a lane runs down the MIDDLE of a corridor.
`FacilityTables`' run walk is now a public `runs(m):Array<CaseRun>` that both `cabinets()` and
`FacilityPoint.places` call: a pure function of the saved grid, so no ordering between the two
builders and no shared list to go stale — the discipline `hugs` and `FacilityGround.bins` already
keep. The refactor is behaviour-identical, checked on `cabinets` **30 before and after**. The BINS
need no test of their own: `hugs` rejects the dead-end and inside-corner cells, which are the bins'.

Placement is one sort and one greedy pass, not two rules. Candidates are the free corridor wall faces
ordered by cell distance to their own structure's nearest exterior door, so a structure's first kept
face is the one by its entrance — that is the **panel**, one per structure, and everything after it in
that structure is a fire point. `POINT_SPACING` **8** thins the rest, measured between CELLS and not
along one wall so a two-wide corridor cannot take one on each hand. 2 panels on this compound = the 2
lab buildings; the hangar is concrete, has no corridor and correctly takes nothing.

**No lift, and the fire point is deliberately the darker half.** Against the corridor wall
(`facility/wall-interior` **0.1578**) the drop is panel **0.0750 = 0.48×** — within a hair of
`facility/notice-board`'s 0.46× — and fire point **0.0519 = 0.33×**, sheet 0.0635 = 0.40×. A FITTING
READS BELOW ITS OWN WALL here (`deco-cabinet-front` 0.60×, notice board 0.46×), so lifting toward the
wall is the mistake those two entries record. In the frame the tonemapper crushes both further —
panel 0.0236 against a wall at 0.0649 (**0.36×**), fire point 0.0075 (**0.11×**) — and the fire point
still reads, because its read is CHROMA: rgb 34.8/8.1/10.3, chroma 26.7 on screen off a source at
107.6/32.0/28.1, spread **79.6**. One lift moves both halves and would push the panel past
`deco-cabinet-front`; chasing the darker half would cost the one that is already right.

`POINT_Y` **2.1** puts the quad at 0.1..4.1, LOW where everything else in the compound is hung high
(`BOARD_Y` 3.0, `EXIT_Y` 4.75) — an extinguisher is meant to be in reach, and standing it nearly on
the floor is what glues it to its own hatch. It clears `BENCH_H` 2.0 nowhere and does not need to,
the casework being excluded before anything is placed. The span along the wall is clamped to the slab
for `FacilityTables.unit`'s reason, and the plane is the slab FACE: measured, all 11 quads came back
at the full `POINT_W` on this seed, so the clamp did not fire — it is there for the run end that
will. Controls unmoved: `exits` 16, `cabinets` 30, `grime` 528, `boards` 2, `shadows` 401.

**`POINT_W` shipped at 1.6 and came back from the game as "i see no panel, no fire point".** They
were drawing — mesh visible, 11 quads, texture loaded — and the miss is a geometry one, not a bug:
**a wall fitting is pitched AWAY at the 65.6° gameplay camera while its own floor hatch lies flat and
facing it.** Measured in one frame, the hatch renders **0.0588 linear against a wall at 0.0636**, and
the fire point on that same wall **0.0078** — the mark is **7.5× the fitting it belongs to**. That is
row 912's finding restated one surface over: the indoor fill is ambient-flat and the ceiling spots
land on the floor, so paint on the floor is lit and a plate on the wall is not.

The aspect is locked by the art at 1:2, so **scale is the only lever without a re-gen**: 1.6 → **2.0**
(+56% area, +0 art), with `POINT_Y` 2.2 → 2.1 to keep the top clear. **The ceiling is the exit sign**
and it is 0.15 away — a terminal sign's bottom edge is `EXIT_Y - EXIT_H / 2` = 4.25 and the two hang
on the same corridor walls at the same `MOUNT_PROUD`, so anything over `POINT_W` 2.05 puts a fire
point through the sign above it.

**SIZE WAS THE WHOLE FIX AND THE VALUE NEEDED NOTHING — a re-gen was proposed off ONE POSE and is
withdrawn.** The 0.0078 / 0.12x-its-wall figure above was measured on a stretch of corridor with no
ceiling spot on that wall, and generalised to the family, which is the mistake this paragraph exists
to record: **an indoor wall's value is a POSE number here, not a surface one.** Measured again in a
normally lit corridor, the same fitting reads **0.0142 linear against a wall at 0.0550 = 0.26x**, at
**chroma 46.5** against the earlier pose's 26.7 — it reads as red. The hatch is still the brighter
half (0.0676, so 4.8x the fitting rather than 7.5x) but that is a lit floor against a lit wall, which
is true of every pair of surfaces in the compound. **Measure a wall fitting in at least two poses
before fitting a `lift` to it**; one dark corridor is not the family.

**Then lifted anyway, on the call — and TWO things turned up on the way that matter more than the
gamma.** First, the source in `textures-src` was **not the drop**: it had been hand-edited, and the
edit was **value-neutral** — fire cell 93.4/45.1/42.5 against the gen's 107.6/32.0/28.1, chroma
**79.6 → 50.9**, luma **0.0518 against 0.0519**. It moved saturation and not value, which is exactly
why it was invisible in the game. A texture source here is not safe to assume is the last thing
generated: diff it against the drop before touching it, and never archive it as "raw".

Second, **that is why the gamma stays in `textures.json` and is not baked into the source.** A file
being hand-edited will lose a baked gamma on the next edit or take it twice; `lift` is declared, is
re-applied by every bake, and is one line.

**The PANEL caps the lift, not the fire point.** Swept in source space against `facility/wall-interior`
0.1578: g 0.90 gives fire **0.41x** / panel **0.60x**, g 0.85 gives **0.46x / 0.68x**, g 0.80 gives
**0.52x / 0.77x**, g 0.70 gives **0.67x / 0.98x** — the panel reaching the value of the wall it hangs
on. So the half that was already right runs out first, and chasing the fire point past about 0.5x
costs it. **`lift` 0.85**, built fire **0.45x** and panel **0.67x** (the bake comes out over the
source-space prediction because LANCZOS averages in sRGB and high-variance content — the panel's
louvres and frame — reads brighter in linear afterwards).

In the frame, same lit corridor, as a ratio to its own wall so the pose cancels: fire point
**0.26x → 0.38x**, absolute linear 0.0142 → 0.0230, **+62%**. **It costs saturation and that is
structural, not tuning**: a gamma raises the low channels proportionally more than the high one, so
the source R/B goes 2.20 → 1.97 and on-screen chroma **46.5 → 26.0**. Brighter and less red is the
only thing one gamma can do to a red plate. A re-roll of the left cell is the lever that separates
the two, and is now wanted for SATURATION rather than for the value it was first proposed for.

**And a fitting must not stand on the LAST CELL of a wall run**, reported as "we have an extinguisher
right on the corner where i'm standing". Measured at the reported cell **(34,31)**: the wall at row 30
runs cols **32..34** and col 35 is the mouth of a passage, so `FacilityGeom.slab` insets that face by
a unit, the masonry shows 3 units of a 4-unit cell, and a `POINT_W` quad centred on the cell lands
flush against the inset end — which is the corner. The clamp is no defence and that is why nothing
caught it: the quad fits the inset face EXACTLY, so it measured at full width and never reported.

The guard is `FacilityKit.wall`'s own, verbatim — the wall line has to `FacilityGeom.carries` past
the cell BOTH ways. `FacilityTables.hugs` does not ask it and should not: a casework RUN answers the
same fact by CLAMPING to the slab, which shortens the last cabinet and looks right, where a single
fixed-width quad has nothing to clamp and rejects the cell instead, exactly as a kit prop does. A
DOOR cell carries and that is correct — the wall line runs on through a doorway — and `hugs` has
already refused the door's own neighbours through `nearDoor`. `points` stays **11**: rejecting the
run-end candidates frees the `POINT_SPACING` budget for cells further along, so the compound places
the same number in better places.

## A one-cell gap in a bench run was costing four rooms their aisle, INVERTED (2026-09-08)

Reported as "why the fuck the majority of the rooms have no lines". Binned every aisle quad into the
room rect it lands in: **5 of 12 marked**. Two of the misses are the documented work aisles (10x3,
benched down both long walls) and one is the hangar (`Surf.CONCRETE`, `least < 0`). **The other four
are a defect, and the shape of the rule is what is wrong, not the thresholds** — no room in the
compound fails `MARK_AISLE_MIN`.

`roomAisle` took the **minimum** clear reach over every cell of the middle run. The generator cuts a
**one-cell walkway through each bench run**, and on those four rooms that gap lands exactly on the
centre line — so the middle cell of a bench run is free floor with casework on both hands, reports
reach **0**, and sets the whole room's lane to **1.6**, under `MARK_LANE_MIN` 4.0. Room 100, middle
column 20:

```
col   17 18 19 20 21 22 23
row20  w  x  y  .  w  x  y     <- free, reach 0 both ways -> least = 0 for the whole run
row21  .  .  .  .  .  .  .     <- reach 3 each way
```

**It was INVERTED, which is how it hid.** The 9x10 that IS marked has a bench sitting *on* col 42 at
row 20: not free floor, skipped by the existing `freeFloor` test, never contributes a reach, and the
room keeps its real 25.6. A bench run that BLOCKS the centre line earns a lane; one with a doorway
through it does not.

Three changes, and the second two are what the first needs to be safe:

1. **a cell with reach 0 is dropped from the minimum** — it is not part of the lane.
2. **`strikes` asks the LINE's own cell, not the run's.** Dropping the pinch widens the offsets, so
   the line can now sit whole cells from the run it was derived from — and testing the run cell said
   "free floor" while the paint lay under the casework, exactly what `freeFloor`'s header forbids.
   The run cell is still asked too (an island breaks the lane rather than collapsing it).
3. **both lines must PAINT at least half the run before either is struck**, or (1) hands a lane to
   the 3-cell work aisle, whose clear columns are the *gaps* in the casework.

**Guard (3) was got wrong twice and both wrongs are the point.** First as *longest unbroken stretch ≥
`MARK_AISLE_MIN`*, with the door break inside `strikes` — that counts the design as damage (the break
at a doorway is the figure tying a room's lane to the corridor's), cut the 8x5's run from 7 to 3 and
**rejected every room in the compound, 0 of 12**. The door test moved out to `line` alone. Then as
*longest unbroken ≥ 5* — still wrong, because **a lane is allowed to break**: an island splits the
9x10's ten cells into 2 and 4 while it draws 6 good segments a side. **7 of 12.** Then as *total ≥ 5*
— one too many for a small room, the 5x5 and 6x5 painting 4 on one side, blocked at both ends by
fittings. **9 of 12** at *total ≥ half the run*, and the two families separate on the FRACTION and
not on the count: every real lane paints **50-100%** (5/10, 6/10, 6/8, 7/8, 8/8, 4/5), the work
aisles **30% and 40%**.

Final: **9 of 12**, the three misses being the two work aisles and the concrete hangar. `marks`
**229 → 275**. Controls unmoved — `zones` 17, `points` 11, `exits` 16, `cabinets` 30, `grime` 528,
`boards` 2, `shadows` 401. **0 crossings** of 275 aisle quads against 17 zone quads, and the new
check the widened offsets made necessary: every one of the 275 quads binned to its centre cell and
asked for that cell's tile — **0 buried**, none on a bench or a fitting.

## The room walls finally carry something — the safety placards, phase 2 (2026-09-08)

The surface the whole interior phase was aimed at. A room wall is **10.25% of the frame** and carried
the damp band and **nothing else**: `FacilityExit`, `FacilityPoint` and `FacilityTables` are all
`Surf.LINO`-gated and `FacilityBoard` is one per front entrance, so **every fitting in the compound
was hung in the circulation and none of them ever reached a room.**

New `render/facility/FacilityPlacard.hx`, `FacilityExit`'s shape verbatim: one quad per sign, one
atlas, one merged mesh. **`placards` 30** on a generated compound.

**ONE PER RUN, ON THE RUN'S MIDDLE CELL.** A run is a stretch of room tile hugging unbroken solid
masonry — and the DOORWAY is what ends one, a door cell not being `isSolidWall` — so a wall with an
opening in it is two runs and takes two signs, which is where a real pair is (confirmed in room 103:
two on the east wall, split by the door between them). Middle and not end, or the sign lands beside
the doorway that broke the run. `PLACARD_RUN_MIN` 3 drops the stubs.

**IT NEEDS NO CLAIMED-CELL LIST, AND THAT IS BOUGHT WITH HEIGHT.** `PLACARD_Y` 4.75 spans 3.85..5.65
and clears `DECO_CABINET_H` **3.43** — the tallest thing that can share a room cell — by 0.42, so the
collision the fire points had to answer against `FacilityTables.runs` simply does not arise. It never
meets `EXIT_Y` 4.75 either despite reading as the same band: those are LINO and these are TILE.

**`runsOn` earned its keep a second time.** The wall line must `FacilityGeom.carries` past the wall
cell both ways, so an inside corner is refused — which is why the pair-intersection test came back
**0 crossings of 30 quads** rather than finding the corner X two perpendicular runs would otherwise
put there. Note the cell binning does NOT show this: a quad's perpendicular coordinate sits inside
the WALL cell, so two signs round one corner bin to the same key and look like a duplicate. The pair
test is the check; the bin is not.

Art: `facility/placards`, one 1k sheet, **2x2 four square cells**, both divisions landed **dead on
512** so a cell is an exact quarter and no crop rect is needed. **NO lift** — and this is the entry
where a fitting reads AT its wall rather than below it, the opposite of `facility/wall-points` and
deliberately so: a fire point is painted steel, a placard is a printed plate. Against `wall-room`
0.1375: biohazard 0.93x, laser 0.95x, no-entry 1.06x, eye protection 0.76x, sd 35.4-38.7 (inside
`notice-board`'s placed-contrast band 34.3, not a tiling surface's 3.0). *Ask for a value, not a
word* held again — naming 55% brightness with equal RGB landed 0.1268 built first try.

Cost **+1 call, +60 tris, +0 programs.** The +0 by IDENTITY and not by the counter:
`renderer.properties.get(mat).currentProgram` is **64** for the placards, the interior walls, the
room walls, the notice board and the wall fittings alike, all `visMasksindoor`. **And the call/tri
delta needed a control** — measured in room 109 the toggle read +2 calls / +120 tris, because that
pose renders the scene twice; `wall-points` A/B'd in the same pose read +2 / +44 against its known 11
quads, i.e. the same doubling. Per scene pass it is +1 and +60, and 30 quads x 2 tris = 60 confirms
it off the geometry. **A toggle delta is only a per-pass number once a known family has been toggled
in the same pose.**

Controls unmoved: `points` 11, `zones` 17, `marks` 275, `exits` 16, `boards` 2, `grime` 528,
`cabinets` 30, `shadows` 401.

## The placard names what is under it — eight signs picked off the room's own contents (2026-09-08)

The plates above shipped with the pictogram rolled off a cell hash, which hung a biohazard triangle
over a bookcase and an eye-protection disc over a server rack. This picks the sign — and the cell it
hangs on — off what actually stands against that wall.

**THE CONTENT IS WALL-HUGGING BY CONSTRUCTION, which is why this works at all.**
`game.FacilityAreaGenerator.makeWindows` stamps every bench and every fitting on `tx,ty`, the
interior cell directly against the wall line, and that wall alternates window run / plain masonry —
so about half of what a room holds sits under exactly the solid masonry a placard needs. Measured by
re-deriving the runs through the engine's own `FacilityModel.fromArea` and `FacilityGeom.carries`:
**all 30 runs find something, 0 fall back**, where the middle cell alone gave eye protection 13 times
and 11 runs with nothing to say.

**DERIVED, NEVER PERSISTED.** `m.deco` (the fitting kind), `m.table`, `m.drain` and `Surf.GRATE` are
all off the saved grid and the decoration objects already in every save. A room `role` was the
obvious alternative and is the wrong answer twice: `_Room.role` is optional and the facility
generator sets it on nothing (`generateRoomContents` makes every room a `roomChemistryLab`), and a
role written at generation would be null on every compound already saved — the contract
`FacilityModel`'s header exists to keep.

**BOTH PROBES MUST BE SCORED, AND THE FIRST BUILD SCORED ONE.** Asking the cell one step into the
room only when the wall cell itself is bare loses the drum every time, because the wall cell is a
BENCH. 6 of the 30 runs are `bench|drum-rad`, `bench|rack`, `bookcase|drum-bio` and the like, and the
bench answered for all six: biohazard 2, laser 3, radiation 2, gloves 8 on the first build against
biohazard 5, laser 3, radiation 3, gloves 5 once both probes score. The score is
`PRIO * 100 + back * 50 + distance-from-middle`, one comparable number, hazard loudest.

**TWO SHEETS, AND THAT IS WHAT EIGHT PICTOGRAMS COST.** Four cells cannot name a bench, a server
rack, a drum and a shelf of boxes; a 2x2 is the largest cell a 1k drop holds at the 256 the built
sheet keeps, so the fifth sign is a second sheet or a smaller plate. **+1 call.** A hazard triangle is
placed AT its hazard and a mandatory blue disc is a ROOM rule, which is what answers the storage
majority — 15 of 30 nearest fittings are a bookcase, a shelf or a cabinet, and no hazard pictogram
names one. Shipped spread: biohazard 5, laser 3, no food 3, eye protection 4, radiation 3, electrical
7, corrosive 0, gloves 5 — **15 on each sheet**, and the corrosive 0 is right, `FIT_DRUM_STEEL` being
0 on this seed.

Art: sheet B one 2x2 1k gen reusing sheet A's BODY paragraph verbatim, which landed it on A's value
with nothing else holding it there (built cells 0.1258/0.1303/0.1277/0.1230 against A's
0.1278/0.1307). Sheet A's no-entry plate was replaced — **a no-entry sign is a DOOR sign, nothing in
a room can trigger it, and the hash was dealing it 11 times in 30** — by a solo 1024 drop pasted into
the quarter rather than an `edit_image` over the sheet, which would redraw all four cells when three
were right. **The solo plate came back at 0.2123 linear against its neighbours' 0.1220 and 0.1243**:
a prohibition disc is mostly pale off-white field, so the value clause that holds for a triangle does
not hold for a disc. `lift` cannot answer that, being per LABEL and dragging all four cells, so a
gamma of **1.450** was fitted and applied to that one cell at composite time — 0.1220. All eight
plates now sit 0.75x to 0.95x of `wall-room` 0.1375.

Cost **+2 calls, +60 tris, +0 programs** for the family (was +1). `currentProgram` **64** for BOTH
sheets, the same `visMasksindoor` permutation as the walls. **The A/B needs `StreetPerf.lastCalls`
and not `renderer.info` read live** — `info` is reset per render and a CDP eval lands after a 1-call
UI pass, which reads back `calls 1 / tris 1` however busy the scene is; that cost an entire
measurement round before the HUD's own `167dc` gave it away. Control in the same pose: `wall-points`
+2 calls / +44 tris for its known 11 quads, i.e. the same doubling, so per pass this is +2 and +60.

**The corner test had to be re-run and it is the placement that moved, not the geometry.** The run's
middle cell made a corner crossing impossible on its own; a content cell beside one does not. XZ pair
intersection over BOTH meshes: **0 crossings, 0 touching of 30**. Controls unmoved: `placards` 30,
`points` 11, `zones` 17, `marks` 275, `exits` 16, `boards` 2, `grime` 528, `cabinets` 30,
`shadows` 401. Warm still 84 cached.

## Two aisle-marking defects a cell bin could not see (2026-09-08)

Both reported by eye — *"yellow lines go under tables"* and *"large break in the second yellow
line"* — in rooms whose numbers had all been green since the aisle shipped.

**A LINE WAS BEING PAINTED UNDER A BENCH WORKTOP.** `MARK_ROOM_MAX` moves BOTH lines inward after
`MARK_WALL_CLEAR` 1.7 and `MARK_FURN_CLEAR` 1.2 have been applied, and re-checks no clearance at all.
A worktop overhangs its cell by `BENCH_LIP` **0.2** on every open side and stands at `BENCH_H` 2.0;
the line is `LINE_W` **0.18**. So anything within **0.29** of a boundary a bench is across is under
the top. On the 6x8 lab the cap's arithmetic landed both lines EXACTLY on a cell boundary and the
whole line width sat inside the lip: 6 of 13 quads touched a top and **two were 100% hidden** — both
of them the one-cell walkway gap the generator cuts through a bench run at each end of the room.
`MARK_LIP_CLEAR` = `BENCH_LIP + LINE_W / 2` now holds each line that far inside its own cell. Applied
after the cap, per LINE and not per cell (a line has one position for its whole run), so it costs at
most 0.29 a side and `MARK_LANE_MIN` is deliberately not re-tested — a lane that measured as traffic
before the cap is still traffic 0.58 narrower. That lab: 6 touching → **2**, 100% hidden → **0**.

**NEITHER CELL TEST COULD SEE IT, AND THAT IS THE PART WORTH KEEPING.** `strikes` bins the line to
`int(mid + 0.5 + s * off / CELL)` and `buried.mjs` bins the quad's CENTRE — on a boundary both round
to the free side while half the paint lies in the bench's. `buried` read **0 of 275** through every
build that had this. A cell bin cannot answer a sub-cell overlap; the check that finds it is a pair
intersection of aisle quads against BENCH-TOP quads with the lip included, and it has to report
covered AREA, not covered WIDTH — width alone calls a 0.2 overlap at a quad's tip "100% of the line"
while it hides 5% of the quad.

**`strikes` ASKED `mid`, AND `mid` IS NOT IN THE LANE.** The two offsets are derived independently and
are not symmetric, so the room's middle can BE one line's own cell. On the 7x10 lab it was: `mid` was
line 1's column, an island bench stood on it for three cells, and that removed **line 2** as well —
though line 2's own column and the whole walkway between the pair were clear floor. With the door
break beside it that read as a 4-cell hole in a lane you can walk down. It asks the cell one step
INSIDE the line (`q - s`) now, which is the lane it bounds. Line 2 gets its three cells back and the
hole is the 1-cell door break, which is the design.

That second fix also DROPS segments, and correctly: a line whose inward cell is a bench is bounding
furniture and not a lane, which is exactly the line sitting in the one-cell bench-run gap — the other
half of *"lines go under tables"*, and the half `MARK_LIP_CLEAR` does not reach. Net `marks`
**275 → 270**.

**AND THE OVERHANG HAS TWO AXES, WHICH THE FIRST PASS AT THIS ONLY HALF ANSWERED.** Holding the line
off the bench BESIDE it leaves the bench in the next cell ALONG the run lipping 0.2 back over the
segment's END, so a segment ending flush on the cell boundary still runs its last 0.29 under the top —
reported straight back as *"line going straight into table"*, and sitting in the measurements as the
5% figure the first pass had looked at and left. The same knob insets the end, and there it IS per
cell: `strikes` is asked of the neighbour along the run, because the two cells IT tests are exactly
the two that can lip over this line. A neighbour dropped by the DOOR break still strikes, so the door
gap keeps the width it was measured at — there is no worktop at a doorway to clear. Whole compound
after: **0 of 270 aisle quads touch a bench worktop**, where it was 6 of 13 and 7 of 11 in the two
rooms reported.

Rooms marked still **9 of 12** (the two 10x3 work aisles and the concrete hangar, as before), `buried`
**0 of 270**, **0 crossings** against 17 zone quads. Controls unmoved: `zones` 17, `points` 11,
`placards` 30, `exits` 16, `boards` 2, `grime` 528, `cabinets` 30, `shadows` 401.

## Every sprite in the game had a black outline, and the atlas was innocent (2026-09-09)

Reported against the laboratory bench decorations: *"all objects have something black on the edges
after transparency"*, plus too small, too bright, no contact shadow, and a few that should lie flat.

**THE ART WAS RULED OUT FIRST AND THAT IS WHAT MADE THE REST FINDABLE.** Over all 43 cells of
`CHEM_LABS_DECO_TABLE`, the silhouette ring measures luminance **181.8** against an interior core of
**183.9** — 2/255, i.e. no authored outline anywhere. What the atlas does carry is mean RGB **(3,3,3)
under every alpha-0 texel**, and the sprite pool was uploading its crops NON-premultiplied with
mipmaps on. Read live off the running game: `premultiplyAlpha:false`, `generateMipmaps:true`,
`minFilter:LinearMipmapLinear`, `anisotropy:1`. Eight bench quads on screen were drawing a 64x64
texture into **36x37 device px = 1.78 texels/pixel**, so the tap lands on **mip 1** — where the whole
silhouette has already been averaged against that black.

**THE OBVIOUS FIX IS IMPOSSIBLE.** Bleeding edge RGB outward into the transparent texels cannot work
through a `CanvasTexture`: a Canvas2D backing store is premultiplied, so RGB written under alpha 0 is
destroyed before upload. `patternWhiten` has been writing 255s there since it was authored and not one
has ever survived. So the filtering moves into premultiplied space instead — the space it is correct
in — and is undone per fragment.

**AND `SRGBColorSpace` + `premultiplyAlpha` DO NOT COMPOSE. This shipped wrong for one build.**
`UNPACK_PREMULTIPLY_ALPHA_WEBGL` multiplies the sRGB-ENCODED bytes (three `WebGLTextures:883`) while
`SRGBColorSpace` allocates `SRGB8_ALPHA8` (same file, `:214`), so the GPU applies the EOTF *after* the
multiply and *before* filtering: the sampler returns `c_linear * a^2.4` and a divide by `a` leaves
`c_linear * a^1.4`. Simulated through this file's own crop, mip-1 silhouette, alpha-weighted mean back
in sRGB — authored **175.8**, the bug being fixed **161.7**, the sRGB-decoded divide **140.8**. It was
1.5x DARKER than the defect it replaced, and it would have passed any test built from hard 0/255
alpha: only 1,510 of 68,267 silhouette texels are hard, and **97.8% of the band is antialiased**.
`NoColorSpace` stores RGBA8, nothing is decoded before filtering, the divide is an exact inverse, and
the shader runs `sRGBTransferEOTF` once at the end: **176.0**.

Order in the patch is therefore the whole content of it — **divide, decode, then saturate**: Rec. 709
weights are a linear-light instrument and cannot move above the EOTF. The divide is on the sampled
texel and never on `diffuseColor`, which already carries `material.opacity` — this pool fades quads
constantly and dividing there makes a fading sprite BRIGHTEN. `material.premultipliedAlpha` stays
false; three's `<premultiplied_alpha_fragment>` would multiply by alpha a second time.

**THE INVARIANT IS ENFORCED AT THE BIND, NOT AT CREATION**, and that is the other trap. `mkTex` covers
this file's six crop builders and structurally cannot reach a texture it did not make —
`render.decals.WallHole` hands `paintWall` four loader PNGs of its own. Divided by an alpha they were
never multiplied by, an alpha-0.1 texel of `bullet-hole-1` renders at **229** of an authored 79 and
anything under 0.05 clips to white and feeds the bloom pass. `slot()` now forces both flags on
whatever it is handed; `loadHoleTex` also sets them at the source, since those files carry RGB 8-23
under alpha 0 and had the original bleed on their own account. `atlasTex` is the deliberate exception
and is commented as one: it feeds the BATCHED decal mesh, which has neither half of this.

The other four, all on the bench family: `DECO_TABLE_SCALE` **0.54 -> 0.81** (a knowing reversal — the
tallest icon goes 1.215 -> 1.82 units, a 0.91 m microscope on a 1 m bench, where that constant's own
header calls 1.08 m the reported bug; texel density 39.5 -> 26.3 per world unit); `DECO_TABLE_SAT`
**0.5**, carried as a shader uniform on the quad's own material rather than a second cached crop,
because the divide has the texel open anyway; a ROUND contact pool on the worktop
(`FacilityDetail.deck`, the shelf-plate quad with `makeRectGlowGradient`'s corner radius set equal to
its half-extent, which collapses the SDF to a circle) — **+1 draw call, +0 programs**; and
`Const.FACILITY_FLAT_DECO`, a per-FRAME table of three, because the gloves sit among eleven upright
flasks on their own rows and a per-ROW table cannot say it.

Live after: `premultiplyAlpha:true` / `NoColorSpace` / key `indoorunpremul` on the pool, **96
programs** (no split), pool mesh **97 quads all at y 2.01** at opacity 0.26 — 97 being exactly the
area's 103 table decorations minus the 6 flat ones — and the halo mesh unmoved at 56 quads / 0.32.

## The bench pool was under the cell, and the object is not over the cell (2026-09-09)

Reported one build later: *"objs are moved from center by logic but the contact shadow doesn't"*, and
*"still these black things on both sides"*. **They are one defect.** The A/B settles it: hiding the
pool mesh takes the black away completely, and the sprite edge underneath is clean.

**THE SPRITE IS NOT WHERE ITS ANCHOR IS.** `Sprites.paint` leans every upright quad back by `TILT`
0.6 rad about world X, and the rotation is about the quad's **centre**, so everything below the
centre swings toward +z. Measured live on all 8 bench quads in view: the quad's bottom edge sits
**+0.69** world units in front of its own anchor, and `poolOffsetWorldXZ` was `[0,0]` — the pool was
exactly on the anchor and exactly not under the object. Against a pool whose falloff reached 0.71,
that is a full radius of displacement, so essentially all of the shade lay outside the thing casting
it. The diff crops show what is left as an L — a band down one flank and along the bottom, which is
the "both sides".

**AND IT IS NOT ONE NUMBER, WHICH IS WHY IT IS NOT A CONSTANT.** The drop below the quad centre is
`SIZE * DECO_TABLE_SCALE * (0.5 - by)`, and `by` — the icon's own alpha bottom margin — runs 0.125 to
0.391 over the 43 frames. So `dz` spans **0.150 to 0.514**, mean 0.372: a single offset would be 0.25
out at the extremes. It is read off `Sprites.texContent`'s content box instead, per frame.

**THE RADIUS CAME OFF THE SAME BOX FOR FREE, and it needed to.** `TABLE_POOL_R` shipped as a flat
0.55 → a 0.71 falloff, against a MEDIAN icon half-width of 0.72: as wide as the object it was under,
so it showed at the flanks no matter where it sat, and it put one puddle under both a bare retort
stand (0.76 wide) and a distillation rig (1.82 — a 2.4x range). Now `r = span * fw / 2 * FOOT` with
`TABLE_POOL_FOOT` **0.55**, so the falloff lands at **0.71 of the icon's own half-width on every one
of the 43** — constant by construction, because both terms scale with `fw`. Radii now 0.21-0.50.

**THE LOOKUP IS A FUNCTION PARAMETER AND NOT A REACH**, and the first cut of it reached anyway and
died. `FacilityModel` is a grid deriver that knows nothing about the renderer and should keep not
knowing, so `render.View.showFacility` passes the lookup in and `FacilityDeco.poolOf` — beside
`spriteScale`/`spriteSat`/`spriteFlat`, because this too is a property of the sprite — turns a box
into a `TableDeco`. What it passes is the part that had to be learned twice: **the sprite pool does
not exist yet.** `View` creates the actor layer inside `buildFrom`, which runs ON the model this call
returns, so `actors` is null on EVERY facility entry — not just the first. Handing over
`actors.iconBox` compiled clean, then threw `Cannot read properties of null` and the area built and
never presented a frame. The box comes off the decoded atlas IMAGE instead, through a new static
`Sprites.cellBox`, which also collapsed the alpha scan that `texContent` and `contentRect` had been
carrying a byte-identical copy of each into one `boxOf`. Omitted, or before that atlas decodes, both
numbers fall back to `TABLE_POOL_R` / `TABLE_POOL_DZ` — the median and the mean of the measured 43.

Live after: 97 pool quads, `dz` **0.150-0.515 over 15 distinct values** where it was a flat 0, radius
**0.23-0.501 over 17** where it was a flat 0.55, opacity and draw calls unmoved.

**NOT FIXED, AND DELIBERATELY.** `drawActor`'s `groundAnchor` drop is computed for an UPRIGHT quad,
so the same tilt also lifts an icon's base **0.05-0.16** off the worktop. Correcting it would move
every ground-anchored object icon in the game — pickups, hatches, vents, every floor decoration — and
that is a change to how the whole game looks, not to this shadow. The same anchor-vs-drawn-pose gap
applies to every `ContactMask.prop` footprint and to `CastShadows.project`; the bench pool is simply
the first place anything was drawn at the true position for it to be measured against.

## The other axis: the art is not centred in its cell either (2026-09-09)

Reported a third time — *"black splotches on both sides are still there"* — after `dz` had been
measured correct to three decimals. It was: the pool's z was **exact**, and the black was still there,
because the offset that was left is on **x**, and `dz` can never touch x.

**THE QUAD IS CENTRED ON THE ANCHOR; THE ART IS NOT CENTRED ON THE QUAD.** The 43 frames were drawn
to a sheet, not to a plumb line. Read live off each drawn crop's own alpha box against its anchor:
flask **-0.494**, microscope **+0.152**, machine **-0.114** world units. That is why it was "both
sides" and never one — the sign is per frame. At a 0.71 falloff against the flask's 0.835-wide icon,
a 0.49 displacement puts the entire pool clear of the object, which is a detached blob and reads as
nothing to do with a shadow.

**IT IS THE SAME BOX AGAIN AND COSTS ONE LINE**: `dx = span * ((b.x + b.w / 2) / t - 0.5)`, no tilt
term, because the lean is about world X and moves nothing sideways. `TableDeco` carries three numbers
now instead of two and `FacilityTables` adds it to `cx`.

**AND THE WIDTH WAS ONLY EVER JUDGED BESIDE THE OBJECT.** `TABLE_POOL_FOOT` **0.55 -> 0.66**: with
`POOL_GROW` and the ramp's own 0.30 + 0.16 the visible falloff is `FOOT * 1.288` of the icon's content
width, so 0.55 was a puddle the object stood *over* at 0.71 of its width. 0.85 is one it stands in.
Fallback `TABLE_POOL_R` follows the same median icon, 0.40 -> 0.475.

Live after, all 8 bench quads in view: `errX` and `errZ` **0.000 on every one**, visible diameter
**0.85 x content width on every one** — both constant by construction, since every term scales with
the same box. 178 draw calls and **96 programs**, unmoved. The one sprite with no pool is the flat
glove at (-74,-30), which is correct: `FACILITY_FLAT_DECO` frames are excluded by `findDeco`.

**THE LESSON IS THE MEASUREMENT, NOT THE FIX.** Two rounds were spent proving `dz` right while the
error sat on the other axis, because the check compared the pool to the ANCHOR. A sprite's anchor is
not where the sprite is drawn on either axis, and the only honest check reconstructs the drawn content
box through the mesh's own world matrix and compares against that.

## The black on both sides was GTAO, and it was on every sprite in the game (2026-09-09)

The pool was innocent. After `dx` landed the bracket of shade was still there, and the report came
back with the culprit named: *"it's ambient occlusion — it works weird with ALL sprites in the game,
ai, floor objects, table objects"*. Correct, and the pass's own AO buffer says exactly why.

**A BILLBOARD IS A SOLID SLAB TO GTAO.** `GTAOPass` renders its own depth + normal prepass of the
whole scene through ONE opaque `MeshNormalMaterial` override — no map, so **no alpha cut** — which
puts every sprite quad in as a full rectangle standing on the ground. A thin upright plane occludes
the floor along both its edges, so what came out around every sprite was a **U**: a band under it and
a stub at each side, sitting out at the QUAD's corners where there is no art at all. Read straight off
`gtaoPass.output = OUTPUT.AO` (values 229-244 over a bench, stretched to that range): four brackets
down the near bench and one around the actor, and putting the sprite pool on a layer the camera
skipped removed all five and left the bench edge lines untouched.

**HIDING THE LAYER FOR THE PREPASS IS THE WHOLE FIX**, because the prepass is the only thing in the
pass that reads the scene — the composite is a full-screen quad. `render.View` wraps `gtaoPass.render`
and sets `actorGroup.visible = false` around the call, restoring what it found. Sprites still RECEIVE
the world's AO; they stop casting it. `actorGroup` holds 5 point lights and 18 quads and NO props —
glbs live in the area builders' groups — so nothing that should occlude is in there, and the unlit
override means the hidden lights cannot matter either.

A/B on the same frame: the difference is that bracket around all six sprites in view and **nothing
else** — max 18/255, brightest at the two stubs. 175 draw calls, 98 programs; the prepass draws less
than it did.

**WHAT IS LEFT, AND IS RIGHT.** A sprite is still MULTIPLIED by the AO of whatever geometry the
prepass saw behind it, so a billboard in front of a wall corner picks that corner's shade up. That is
the pass working as designed on a flat cutout and reads as the sprite sitting in the room; masking it
out needs a stencil and buys little.


## The benches got their sinks — two quads, one sheet, one draw call (2026-09-09)

A lab bench run terminates in a sink and the compound had none — `facility/bench-top`'s own prompt
says *"no sink, no taps"* outright. `render.facility.FacilitySink` puts one on the end cell of every
bench block that has a free one: a **flat basin decal** lying on the worktop and an **upright tap**
standing at its back edge.

**TWO QUADS, and the triage answers it twice.** A basin at this camera's 51 degrees is not a
silhouette — it is a shape ON the worktop, a rim and a well and a drain, which is a surface and so a
texture. A tap is a thin bent OUTLINE with air either side, which is an alpha cut. Neither wants a
glb, and a box states neither.

**ONE SHEET AND NOT TWO TEXTURES.** `docs/3d-textures.md` warns a packed sheet cannot serve an alpha
cut, because `background:"transparent"` cuts the whole image — but here BOTH cells want the cut, so
the objection inverts into the argument for packing. Measured: **+1 draw call, 9 of 9 A/B pairs**, and
**+0 programs** — and that one is measured rather than reasoned, which it had to be, because the
obvious "94 before and after" reading was worthless: the first frame already had the sinks in it. The
honest check is the program itself. The sink's material binds program **71, `usedTimes` 3, and exactly
ONE program in `renderer.info.programs` carries that cacheKey**, so a mask-patched alpha-cut
DoubleSide lambert really is the permutation `FacilityDeco.cut`'s shelving frame already warms. 24
sinks in the compound = 48 quads, **96 triangles**, one mesh.

**AND THE SHEET HAS NO GRID.** Nothing was split at a half or a third: with the background genuinely
empty (**69.80% of pixels at alpha 0**) each object's own alpha bbox IS its cell, padded outward 2px
so the edge ramp falls inside the rect and `alphaTest` trims it instead of clipping the silhouette.
Basin **618x449**, tap **344x493**, and those aspects are what `SINK_BASIN_D` and `SINK_FAUCET_W` are
locked to. The tap's column is not centred in its own rect — handle out to the left, spout arching
right — so its FOOT is measured separately (x 739..909, centre 824 against a rect centre of 841.5) and
`SINK_FAUCET_AXIS` **0.05087** slides the quad so the tap stands on the cell centre rather than being
hung by its bounding box.

**THE FIRST TAP SHIPPED AS WIRE, which is the entry's real lesson.** Drawn at honest proportions it
came back **18.4% opaque** over its rect at srgb 105.6, and in game it was a faint scribble on black
resin — `docs/3d-geometry.md`'s *honest member width reads as WIRE*, the shelving frame's own failure
at 26%. Re-rolled SOLO at 640x1024 demanding massively thick members and naming srgb 160 outright,
then PIL-pasted into the sheet with the basin untouched: the placards' route, and for their reason —
an `edit_image` over the sheet redraws the cell that was already right. Second roll: opaque fraction
**0.3290**, srgb **156.4**, channel spread **0.6** against the basin's 4.4.

**AND THE FIRST VALUE MEASUREMENT WAS OF THE WORKTOP.** The patch put over the thin tap was mostly
background, so it read **36.4** and implied a vertical face renders at 0.34x its albedo. Sampling only
the metal after the re-roll gives **114.4 from a 156.4 source = 0.73x**, next to the basin's 0.64x —
*a patch over a thin object measures the thing behind it, and the ratio it yields is fiction.*
Built at the game camera against a bare worktop at srgb 32.9: basin **footprint** (rim plus its
shaded well, unthresholded) **56.7 = 1.72x**, the rim alone **95.3**, tap metal **116.1 = 3.53x**.
The tap reading well over the basin is right and not a miss — polished steel standing up into the
room light against a shaded recess lying flat — and it lands in the same value family as the flask
and scale sprites sharing its bench.

**RES 256, WHICH IS A DENSITY DECISION AND NOT A MEMORY ONE.** The basin draws `SINK_BASIN_W` 2.5
world units off a 154-texel crop = **61.6 texels per world unit**, and the bench sprites beside it sit
at **59** — the number `DECO_TABLE_SCALE` was itself fitted to — so the sink samples at the density of
the family it shares a worktop with. The tap lands at 76.1. Halving the sheet moved neither value
(footprint 55.7 → 56.7, tap 114.4 → 116.1 on identically thresholded patches): a box downscale
averages texels and does not shift their mean. One cost, and it is why the 2px pad is quoted at the
SOURCE and not at the output — 2px at 1024 is **half a texel at 256**, so the silhouette now reaches
the outermost texel row of both rects and `alphaTest` trims about one texel off each outer edge. At
61.6 texels per world unit that is 0.016 world units and invisible; a res below 256 starts eating the
rim. **`res` is also NOT in `tools/textures.py`'s freshness test** — it tracks `lift` and
`glass_alpha` but not the output size, so changing it alone reports *up to date* and rebuilds nothing.
Null the label's `last_converted` to force it.

**NO `lift` ON THE LABEL, and it could not have helped anyway:** `lift` is per LABEL and the two cells
wanted opposite moves. If the tap ever needs moving alone it is a per-cell gamma at composite time,
the way `facility/placards`' prohibition disc was fixed.

**THE OCCUPANCY GRID WAS A HOLE.** `FacilityModel.tableDeco` is null for the three frames that LIE
DOWN (`Const.FACILITY_FLAT_DECO`) — nothing lying flat casts the shadow that grid exists to place —
so a null check there would have laid a basin through a pair of gloves. `tableTaken` is a second grid
stamped before the flat test. It matters: the compound has **139 bench cells, 103 of them taken**
(74%, the generator's 70% roll plus its forced room corners), **46 blocks**, and **24 sinks** — the 22
blocks with every edge cell occupied correctly get none. 24 over 12 rooms is **2.0 per room**.

**NOT GATED ON `m.rooms`**, which the pass had to be built around rather than into: `FacilityModel
.demo()` leaves that list empty, so a rooms-gated family emits nothing in the warm scene and compiles
on the frame the player first walks in. Gated on `m.table` it warms for free — the demo's two bench
blocks emit **2 sinks**, and between them they exercise both halves of the edge predicate (a run END
at 1 table neighbour, an island CORNER at 2 on perpendicular hands).

## `alphaToCoverage` REJECTED — it dithers a minified alpha cut instead of smoothing it (2026-09-10)

Started from a correct observation and a correct mechanism, and the fix still lost on measurement.
Kept because the mechanism is right and the trap is subtle.

**The correct part.** AA here is MSAA on the composer's targets (`SceneSetup.hx:52` builds the
renderer `antialias: false`; `View.setAA` puts samples on `rt1`/`rt2`). MSAA resolves TRIANGLE
COVERAGE. An `alphaTest` silhouette is a `discard`, the fragment shader runs once per PIXEL, and one
discard kills all 8 samples — so a cut edge really is the one edge in the game the AA option does
nothing for, at any sample count. That much holds.

**Why the fix fails anyway.** three's chunk is
`diffuseColor.a = smoothstep(alphaTest, alphaTest + fwidth(a), a)`. It assumes the alpha is a smooth
analytic coverage function, i.e. that its ramp spans about a pixel. The sink's does not: projecting
the basin quad's real vertices puts it at **2.32 texels per pixel at 27.5 units** and 2.88 at 44
(256² sheet, trilinear, aniso 4), so the ramp is SUB-PIXEL, `fwidth(a)` is order 1, and it differs
between adjacent 2x2 derivative quads. The same fully-opaque texel then gets a different coverage in
each quad, which MSAA dithers into a 9-level mask. The result modulates up to **1.5 px inside** the
silhouette.

**Measured, render scale 100%, AA 8x, AO off, on the basin's four edges.** Sampled PERPENDICULAR to
the true edge line recovered from the projected vertices — axis-aligned scans are worthless here and
gave window-dependent garbage (RMS 0.14 to 8.7 depending on the window) before that was fixed:

| basin edge | angle | cut | +a2c |
|---|---|---|---|
| **lower-left** | 28 deg | **0.149 px** | **0.296 px** |
| lower-right | 50 deg | 0.124 | 0.170 |
| upper-right | 27 deg | 0.137 | 0.155 |
| upper-left | 46 deg | 0.140 | 0.172 |

a2c DOUBLES the edge-position wander on the lower-left edge (peak-to-peak 0.74 → **1.37 px**) and is
worse on all four. Stable over four window/step choices (a2c 0.227-0.296, cut 0.149-0.152) and
frame-to-frame noise is zero. Raw pixels one px inside that edge, walking along it: the cut holds a
flat ~70 (69.5 68.3 70.7 71.6 71.5 73.3 70.7 60.0 75.6 76.5 73.0 65.5), a2c swings 34 to 73 position
by position (57.7 62.6 49.6 62.3 43.7 73.3 44.8 60.0 38.4 34.5 58.1 39.7). That alternation is the
artifact, and it is visible at 1x.

**THE TRAP, and the reason this entry exists.** The first pass measured a "silhouette ring mean" —
the mean value of the outermost lit pixels — and read 51.9 → 48.4 as a win. It is not a measure of
antialiasing. It rewards DIM edge pixels, and a2c dims them by ERODING the silhouette: body pixels
(>= 60) fell 1293 → 1149, **-11.1%**, with the peak value unchanged at 151. Dimmer edge pixels are
not a straighter edge. **An AA metric has to measure edge POSITION — how far the recovered sub-pixel
boundary wanders from a straight line — not edge intensity.** Every conclusion from the ring metric
was wrong, including a +0-draw-calls / program-swap result that was real but irrelevant.

**VERDICT: reverted** on `FacilitySink`, `WildGrass` and `FacilityPaint`, and the `alphaToCoverage`
extern field removed from `three/Three.hx` with them. `WildGrass` and `FacilityPaint` were never
measured and are subject to the same mechanism, so they went back rather than stay as unmeasured
bets. Do not re-try this on a MINIFIED cut. It is only defensible where the alpha ramp already spans
about a pixel — a magnified sprite, or an alpha authored as a distance field.

**What actually drives the sink's edge quality is texel density, and it is unaddressed:** 2.32
texels/px means the art is minified ~2.3x at a normal viewing distance, so `res: 512` on the sink
sheet (against the shipped 256) would put it near mip 0, which is also the only regime where three's
a2c formulation would have worked. Not attempted here.

**Also found, unrelated and still live: the sink casts AO as solid slabs.** `GTAOPass` runs its
depth+normal prepass through `new MeshNormalMaterial()` (`three.global.js:46112`) — no map, so no
alpha cut. The sprite fix at `View.hx:545-553` hides only `actorGroup`, and `FacilitySink`'s mesh is
a direct child of `Scene` (verified live), so it is not covered. With `vidAO` on, the faucet quad
(32.9% opaque) and the basin quad occlude as full rectangles — the same bracket-of-shade bug the
sprite entry above fixed. `vidAO` was off during this session, so it contributed nothing to the
symptom that started it.
## pack16 — the bench decorations get 256 px art, sixteen to a sheet (2026-09-10)

**The complaint:** the laboratory worktops were dressed out of `entities64` and read blurry and
off-style. Both halves are measurable. A bench sprite spans `Sprites.SIZE 3.0 * DECO_TABLE_SCALE
0.81` = **2.43 world units**, so a 64 px cell is **26.3 texels per world unit** against
`facility/floor-tile`'s own 73 — the same number `facility/floor-grate`'s note records at 21.3 when
that one was reported as blurry. And the sheet is stock flat-design vector art: cell 9/10 measures
chroma **42.4** at linear **0.5592**, five times the brightness of anything else in the room, which
is why `DECO_TABLE_SAT` was halving it in the first place.

**What shipped:** four 1024 generations, sixteen decorations each at 256 px a cell —
**105.3 texels/unit**, 4x. `Sprites.atlasFor` now takes the cell coordinates and returns them, so a
pack cell can live anywhere on its sheet; the five pixel readers take their cell from that record
and their cache key from the arguments, keeping one cache entry per `entities64` frame. 3D-only, the
same trade the 128 px actor atlases make — the 2D path is untouched, `Const.decoHD` is stateless off
the frame, nothing is persisted and no save is migrated. `AtlasBox` had to start carrying its own
cell size (`t`): every consumer turns the box into a cell fraction and divided by
`TILE_SIZE_CLEAN` to do it, which is off by 4x for a pack cell, and `View.iconBox` had to be taught
to ask the pack sheet — a contact pool measured on one silhouette and a quad drawn from another are
two different objects.

**The cost, A/B'd in one pinned pose, 120 GPU samples a leg:** `calls` 102 = 102, `tris` 26,430 =
26,430, `info.memory.textures` 378 = 378, heap 133 MB = 133 MB, GPU median **9.69 on vs 9.97 off**
(p10/p90 8.86-10.52 vs 8.80-11.08) — inside the noise and signed the wrong way. Nothing moves
because nothing changes: the pool binds one cached crop per quad either way and a sheet is only ever
cropped, never bound whole. The real cost is bytes, which that counter cannot see — 40 distinct
frames x 256²x4 = **10.5 MB** of crops against 0.66 MB, plus 4 x 4 MB of decoded sheet.

**The prompt carries sixteen cells; the SPLIT is what it will not honour.** Every named subject
landed in its named cell on all four sheets, companion items included. Sheet 1's columns straddled
256/512/768 cleanly and its rows landed at **261/495/731** — two gaps 17 and 37 px high, with **7 of
16 groups crossing a nominal boundary**. `tools/pack16.py` derives the seams off the alpha coverage
profile and re-pastes each group into an exact cell at ONE sheet-wide scale, centred and
bottom-aligned; that also zeroes the offset `FacilityModel`'s own note measured on the stock icons
(opaque centres **-0.49..+0.15 world units** off the anchor, which is what put a pool BESIDE a
flask). Sheet 4's first roll was **refused** by the tool — thinnest column near 256 still carried 49
opaque px — and the re-roll leads with SEPARATION IS THE MOST IMPORTANT REQUIREMENT plus a stated
15% gutter. **Put that clause first on any future sheet:** it costs nothing and a re-roll costs
$0.057.

**Values.** Sheet 2's darkest cell came back at **0.0336** linear under `facility/bench-top`'s own
0.0401 — `lift_gamma`'s hole-in-the-ground failure. Lift fitted per sheet on the median so the
family lands on sheet 1's 0.109 (which needed none): 0.79 / 0.80 / 0.89 → built 0.1065 / 0.1050 /
0.1048. That breaks the re-roll-over-6-points-of-spread rule deliberately: chroma median 10.4 over
64 cells is tinted liquid and painted casing, and that rule is about a neutral surface hiding a
cast. `DECO_TABLE_SAT` went PER FRAME — 1.0 for a frame with a pack cell, the old 0.5 for one
without — so the knob still records why it exists and the transition needed no flag day.

**x4 bench density is ART and not more sprites.** Every pooled quad is a draw call, and this
compound stands **103 bench decorations over 139 bench cells**: four sprites a cell would be **+309
calls** on a frame that runs 102. A 256 cell holds a CLUSTER instead — measured 3.2 drawn items a
cell on sheet 1, ~4.2 on sheets 2-4 after the prompt went from "two or three" companions to "THREE
OR FOUR". Same quads, same calls, about four times the things on the worktop.

**And 21 of the 64 decorations are frames that never existed.** `entities64` had 5 free columns on
row 14 and nothing below row 47, so the sheet grew **48 → 50 rows** (768x3200) and
`CHEM_LABS_DECO_TABLE` gained row 14 amount 7 → 12 plus rows 48 and 49: the bench family goes **43
kinds → 64**. `tools/atlaspaste.py` bakes the 64 px icon out of the pack cell so the frame exists
wherever it is addressed — insurance rather than a live path (`GameScene.is3DArea` lists 'facility',
so a compound never takes the 2D branch), and the four-item clusters were checked to still be
nameable at 64. It writes via a temp file and `os.replace`: PIL's `save` opens `w+b`, which the
Windows DrvFs mount answers with `OSError 22 Invalid argument`.

**VERDICT: landed.** Free in the frame, +~26 MB of texture, 43 bench kinds → 64.

## worktop clutter — 148 flat decals over the benches for one draw call (2026-09-10)

The worktops carried one standing sprite per decorated cell and then bare resin. `FacilityClutter`
scatters small FLAT things over what is left — a clipboard, a petri dish, a coiled cable — at free
position and free yaw, off one 8x8 sheet (`facility/worktop-clutter`, 64 cells of 128 px).

**RENDER-ONLY.** No `objects.Decoration`, no atlas frame, nothing persisted. Every position, size,
turn and cell index rolls off `FacilityModel.mix`, so an area comes back identical and no save moved.

**Measured live:** `calls` **102 → 103**, confirmed by toggling the mesh's `visible` (102 off / 103
on). 148 decals, 296 tris, 592 verts, one merged mesh. Warm 84 → 88 programs. Count stable at 148
across three area rebuilds. The material is `FacilitySink`'s exactly — opaque `alphaTest`,
`DoubleSide`, `VisionMask.patch` — so it adds no program permutation; the warm entry is for the
texture upload.

**8x8 is the wrong grid for a billboard and the right one here.** 89 art px an object (median
long-axis fill 0.695 × 128). Over a bench sprite's 2.43 units that is 52.7 texels/unit, under
`floor-tile`'s 73. Over the 0.8 units these draw at it is 111. Density is art px over the size a
thing is DRAWN at, never over the cell it was cut from — judging on cell size alone rejects 8x8 for
both routes and gets one wrong.

**The trap: "darker than the surface reads as a hole" is not the rule.** Twelve cells come in under
`bench-top`'s 0.0401, which the pack16 entry above would condemn wholesale. In game the tweezers at
0.0198 and the cable at 0.0195 read fine as dark objects; the tablet at 0.0266 read as a gap punched
through the bench. The separator is **solidity** — opaque px over bbox area, filled slab vs outline
with worktop showing through. Offenders are all >0.62 (tablet 1.00, calculator 0.98, pouch 0.94,
mouse mat 0.94, hole punch 0.87, keyboard 0.70, radio 0.67); every dark cell under it was left in
(stoppers 0.56, cable 0.50, glasses 0.49, torch 0.40, iron 0.30). Seven skipped, 57 dealt.

A lift cannot express that: the gamma needed to clear 0.0177 is 0.78, which drags the sheet median
0.1202 → 0.191 and washes out the 52 cells that were already right.

**Three occupancy answers on the same cells**, which is why `m.tableSink` is a third grid: an empty
cell takes clutter anywhere, a decorated cell takes it around `m.tableDeco`'s contact circle
(measured off the icon's alpha box, so a flask whose opaque box sits to one side keeps clearance on
that side), and a sink cell takes none — `SINK_BASIN_W` is 2.5 of a 4.0 cell. Cross-cell overlap is
impossible by construction: an offset is inset by the item's own half size.

The per-cell count rolls 0..3 and **reaching zero is the point** — flooring it at 1 puts something on
all 139 bench cells and rebuilds the rhythm this family exists to break. 148 over 115 non-sink cells.

**VERDICT: landed.** +1 draw call, +296 tris, 57 subjects on one $0.058 sheet.

## A per-cell LINEAR CAP, which is the thing a per-sheet lift cannot be

Reported from the game: the worktop clutter is too bright. `facility/worktop-clutter` ships **no
`lift`, deliberately** — the entry above records why. Measured, the sheet is **bimodal**, and that is
the whole finding. Over the 57 dealt cells: p10 0.0476, p25 0.0663, **p50 0.1281**, p75 0.2757,
p90 0.3171. The top quarter is white PAPER — index cards 0.3751 (**9.4×** `bench-top`'s 0.0401),
powder heap 0.3741, loose papers 0.3508, label sheet, weigh boat, schematic, floor plan, dust mask,
printout, notebook, logbook, cup lid, barcodes, calendar, clock. In frame, `--scene`: the envelope
decal read **3.80×** its own bare worktop and the barcode sheet 2.37×, against the sink basin's
fitted 2.68× — the only other flat thing on that worktop.

**A lift cannot express it, in either direction.** The gamma that lands the whole sheet on the bench
family's band is 1.25, and it takes the cells rendering under their own worktop from **5 to 13** and
the darkest to 0.0095 = **0.24×** it. The gamma that lands the PAPER at 2× is **2.66 per cell**,
which also crushes its printed detail to black. This is the entry above hit from the opposite side.

**`cells` in `art/textures.json`** — `{"grid": 8, "cap": 0.105}`, ~12 lines in `tools/textures.py`
beside `lift_gamma`. Per cell: mean linear luminance over **opaque pixels only**, and where it is over
the cap, multiply that cell's **linear** RGB by `cap / measured`.

- **A multiply and not a gamma**, because a gamma of 2.66 destroys the contrast inside the cell.
- **It can only ever darken**, so the dark cells are untouched *by construction* rather than by a
  skip list — which is what makes it composable with the solidity finding above.
- `cap` 0.105 is the bench packs' own built value: the clutter and the standing decorations share a
  worktop, so they now share a number.

**Measured after:** 35 of 64 cells moved, all of them ones already over 0.105 and none under it;
whole sheet 0.1528 → 0.0796; brightest cell 0.3751 → 0.104 = **2.59×** the worktop, down from 9.4×;
cells under `bench-top` **5 → 5, unchanged**. In frame the envelope went 3.80× → **1.51×** and the
barcode sheet 2.37× → **1.78×**.

**The trap:** measure on opaque pixels only. Over the whole array the same sheet reports 0.0686
against a true 0.1528 — `tools/pix.py` masks this way and its `opaque 27.8%` column is the tell.
Second trap: `textures.py`'s `fresh` test tracks `lift` and `glass_alpha` and not `res`, so any new
knob must be added to it or an edit reports *up to date* and rebuilds nothing.

**VERDICT: landed.** Zero runtime cost, zero draw calls, zero programs.

## `DECO_TABLE_SAT` goes back to every frame, and the clutter gets it baked

> SUPERSEDES the per-frame split in "PACK16 — the bench decorations get 256 px art"

That split returned 1.0 for any frame with a pack cell, on the argument that pack cells are drawn in
the game's palette already (chroma median 10.4, p90 26.4) so halving them would only turn a tinted
liquid grey. Reported from the game: it does not. `FacilityDeco.spriteSat` now returns
`DECO_TABLE_SAT` for every bench decoration — one line, and **zero cost**, because the uniform already
exists and `Sprites.paint` already writes it per quad.

The flat clutter beside them has no such uniform — it is a merged lambert, not a sprite — so it takes
the same 0.5 through a new **`sat`** key baked by `tools/textures.py`. Mixed toward Rec.709 luminance
**in linear light**, deliberately the same instrument in the same space as `Sprites.unpremul`'s
shader knob: a mix taken above the EOTF desaturates by a different amount at every value, and the two
numbers have to mean the same thing. Luma-preserving, so it composes with `cells` in one pass and
neither knob disturbs the other's measurement. Clutter per-cell chroma ran median 10.2, **p90 50.1,
max 78.9** — a heavier tail than the bench packs'.

**VERDICT: landed.** One line of Haxe, three of Python, no new material and no new program.

## `FacilityCable` — wall cable panels and the runs that sag between them

> SUPERSEDED by *The electrical service — one pack64, four families, still two draw calls*. The
> panels became floor-level SOCKETS and `facility/fixture-panel` was deleted with them; the
> socket-to-socket runs moved into the floor plane. The parabola, the width-axis trap and the
> count-not-a-screenshot findings below all still stand.

Room walls carried placards and nothing electrical. Two merged meshes: the panels, and the runs.

**The art cost $0.0544 for one image and nothing for the other.** `facility/deco-rack-pack4.png`'s
bottom-right quadrant has been a *"blanking/cable panel that nothing draws yet"* since the rack's own
pack landed — a panel with rails, screw columns and heavy cables draped across it. Cropped on the
art's own seams (per-row |diff| peaks at 598/685/772/859/944, an 86.5 px rack-unit pitch; rails at
x 529-548 and 988-991) it is `facility/fixture-panel` at exactly 2:1. **Check the unused quadrants
before generating a wall fitting.** `deco-machine-pack.png`'s spare was looked at and **rejected** —
featureless, so cropped to a fitting it reads as a smudge. A fitting needs a frame.

`facility/cable` is the one generation: an opaque tiling tile, one cable edge to edge, no alpha and
no cut, because **the ribbon geometry is the cable's silhouette**. Prompted featureless on purpose —
v tiles ~4× a cell, so any placed feature would repeat with it.

**Two lifts, both fitted against the built frame and not on paper.** The cable came back at linear
**0.0093** (srgb 23.9), a fifteenth of `wall-room` — black rubber painted honestly is `lift_gamma`'s
hole failure at full strength. **lift 0.64 is the steepest in the file**; it lands 0.0394, just under
the rack front's 0.0473, and the thing to check was that the cross-section survives a gamma under 1
(it lifts darks hardest): 44.0 at the edges to 75.2 down the middle, still **1.71:1**, which is what
makes a 0.18-unit ribbon read as round. The panel shipped at lift 0.84 = 0.0519 linear, correct as
steel and **wrong in the room** — it read as a black slot punched in the wall. **0.72 → 0.56× the
wall**, at the top of the band `wall-points` measured. Growing it instead was not available: `FIX_Y`'s
band is 0.9 tall between the machine tops at 2.8 and the placards' floor at 3.85, and the crop is
aspect-locked, so `FIX_H` 0.9 caps `FIX_W` at 1.8. **Value is the only lever a wall fitting has left
once its band is fixed.**

**The band is what removes the collision problem**, `PLACARD_Y`'s own trick upside down: 2.9 clears
`DECO_MACHINE_SZ` 2.8 below, 3.8 clears the signage floor above, and nothing else in the compound is
hung on a room wall between them — so this family checks against no other builder.

**A parabola and not a spline.** `PathLine` and `SlimeTrail` build exactly this ribbon and are the
wrong shape to borrow: both rebuild per frame from a PATH of many cells, and a cable has **two
anchors**. Straight chord, sag term, `4t(1-t)` taper (zero at both ends, `PathLine`'s taper reached
from the other side), one sine rolled once off `mix` and baked. Nothing ticks.

**The width axis and the sag axis are the same vector and must not be the same variable.** `w =
n × t` is what the ribbon is widened along and what winds the quads; negate it and every face turns
into the masonry and never appears. The sag rides the same axis with its own SIGN, chosen so it
points down where the run has a down — a horizontal run droops, a vertical drop bows sideways, one
rule.

**Four bugs, and every one of them was found by a COUNT and not by a screenshot:**

1. **52 panels, 0 runs.** Both halves broken at once, which one counter could not have said. Splitting
   the readout into panels/wired/runs is what separated them.
2. **`wired` 0** — the greedy spacing deal essentially never lands on the one cell beside a machine.
   Machines now claim their neighbour in a **first pass**, and the thinning works around it.
3. **`links` 0** — the span test borrowed the panels' own predicates wholesale. A bench between two
   panels is not a collision (it is 2.0 tall and stands a clear unit off the slab face, so it
   *occludes* the cable, which is correct), and `hangs`' carries-both-ways clause is a plate's
   problem, not a cable's. A **fitting height** test against the run's own lowest point replaced a
   bare `m.deco > 0`: half that family is low enough to pass under.
4. **`CABLE_SAG` as a fraction of span** — fine on a 2-unit drop, **1.68 units** of droop on a 3-cell
   link, and worse every time the reach went up. It is world units now: a strung cable's sag is set by
   its slack, not by how far apart its ends are, with a taper for runs under a cell.

**And two knobs measured to be doing nothing.** Reach 5 → 8 took candidate pairs 19 → 30 and produced
**no extra runs at all** — what refuses a link is the masonry in between, not the distance. A 1-in-3
skip roll was built to keep the compound from reading as a diagram and then **deleted**: only 4 of 30
candidates are eligible in the first place, so the roll was throwing away the scarce half of the
family to manufacture the abundant one. Emptiness comes from the geometry for free.

**Measured live:** 30 panels / 8 wired / 9 runs, 60 + 180 tris. `calls` **105 → 103 → 105** by
toggling both meshes at one pinned pose. Warm unchanged at **84 programs** — two plain mapped
lamberts through `FacilityGeom.add` is `FacilityPoint`'s existing permutation, so the warm entry is
for the texture upload alone.

**VERDICT: landed.** +2 draw calls, +240 tris, one generation.

## `facility/electrical-pack` — one pack64 in TWO projections, and a cap that reads a row band

Sixty-four pieces of industrial electrical kit on one 1024 sheet, 8x8, and the only sheet in the tree
whose cells are not all drawn from the same angle: **rows 1-6 are front elevation and rows 7-8 are
straight top-down**. That is the whole reason four families that look nothing alike — wall sockets,
corridor fittings, standing floor units, flat floor scatter — cost **one draw call between them**.

**The four sixteens:** 0-15 sockets, 16-31 corridor fittings, 32-47 floor units, 48-63 floor scatter.

**The second roll moved 32-47 from top-down to elevation, and that is the entry.** They were drawn
overhead like the scatter and laid flat, and read exactly as what they were: a welding set, a
compressor and a control cabinet **painted on the floor**. A thing that STANDS has to stand, whatever
its neighbours on the sheet do. Re-prompted onto a common ground line; the runtime stands them as
frontal quads leaned back by `Sprites.TILT`. Rows 7-8 stayed overhead because a cable coil, a
taped-down run and a rubber mat genuinely are flat. **$0.0596 + $0.0604**, gpt-image-2.5-**sunburst**
at quality high both times — sunburst because the risk here is LAYOUT, a strict grid with a projection
change partway down it, and it honoured the split exactly on both rolls.

**The alpha survived a prompt that names a vertical face**, which `worktop-clutter`'s note says it
should not have: 48.3% alpha 0 plus 13.9% in the 1-15 wash `pack16.py` flattens, against that sheet's
51.3%. The difference is **what** the surface is attached to — *"as if bolted to a vertical face"*
names the VIEW; the roll that lost its transparency named what the objects were LYING ON.

**Packed `--valign center`, which is the right compromise and not the right answer for all three
bands.** Correct for the top-down band (no ground line exists, and the runtime rotates those quads
about their own centres) and for the wall band; it leaves a standing unit's feet a margin up inside
its own quad, so `UNIT_SINK` 0.12 drops the quad through the floor by the sheet's own mean vertical
margin (fills 0.64-0.87). Untuned, a lead's end was visibly under a unit floating over it.

**`cells` grew a ROW BAND, and the measurement is why one number could not serve the sheet.** The wall
band's median **0.109** is 0.80x `wall-room` 0.1375 — a fitting that close in value to its own wall is
not seen, which is `fixture-panel`'s failure from the other end (0.38x read as a black slot). Capping
rows 0-4 at **0.0756 = 0.55x** the room wall / 0.48x `wall-interior` puts it inside the band
`wall-points` measured. **Nothing below row 4 is capped and both halves would be ruined by it:** the
standing units run a median 0.061 against `floor-tile` 0.1185, already half the floor they stand on,
and the same cap would take the sheet's only industrial colour — a yellow transformer 0.1931, an
extension block 0.1555, a warning plate 0.2737 — down to a fraction of the tile it lies on.

**VERDICT: landed.** One sheet, four families, two generations, `--tol 4` on the second roll (the
first needed 50: a welding set's cable crossed the y-640 seam).

## The electrical service — one pack64, four families, still two draw calls

`FacilityCable` rebuilt around the report *"not wall fixtures but wall sockets — smaller, near the
floor"*. The panels came down the wall and the family grew three more halves. Two merged meshes: the
pack (one alphaTest DoubleSide lambert, `FacilityClutter`'s own material and so its own program) and
the cable.

**Measured live:** 44 mounts / 22 runs / 13 units / 61 scatter, 236 + 440 tris. `calls` **104 → 105 →
106** by toggling each mesh at one pinned pose — **+2** for the whole service, the same budget the two
panel families cost. Warm unchanged at **84 programs**.

**A socket is the same in every socket of one room.** The choice is rolled off the ROOM's own id
(`m.rooms`, falling back to the structure index — `demo()` leaves that list empty, which is not a
nicety but what keeps the warm scene emitting), so a lab is fitted throughout with one pattern and the
lab next door with another. Verified from `__facility()`: four sockets in the player's room, all
`cell: 6`; the corridor fitting beside them `cell: 20`.

**Scale and not value is what decides whether a small wall fitting is SEEN**, and this family learned
it from the bottom after `POINT_W` learned it from the top. One world unit is about **4.2 device px**
from the resting camera; the art fills 0.7 of its cell; `SOCK_W` 1.0 therefore drew a **seven-pixel
smudge with a cable arriving at it**. 1.4 works and is still well under the 1.8 panel it replaced.
`SOCK_LEAD` came out of the same frame: a run inset by the quad's half-width less its own thickness —
the obvious number — ends in the transparent margin BESIDE the socket. The inset is measured against
the ART (a quarter of the quad, inside every cell on the sheet at fills 0.64-0.87).

**The sockets moving down the wall changed the cable family, not just its height.** A run between two
fittings at head height sags under gravity; between two sockets a foot off the ground there is nothing
to sag INTO and the old 0.45 droop is underground at mid-span. So a socket-to-socket run lies in the
**floor** plane and its whole offset is lateral — `CABLE_SNAKE` 0.55, a cable bowing out into the room
and back. `strip` took a `StripOpts` for it: the plane became a NORMAL (wall face or straight up) and
the bow's sign became a **hint vector** the caller supplies, falling through to the seed when the
chord is too nearly parallel to answer. Five positional args would have become nine.

**Two corrections came from the game, and both were about where a cable is allowed to be:**

1. **Floor leads ran straight OUT from the wall** — across the aisle markings in a room, across the
   corridor itself in a corridor. A lead laid over the route everyone walks reads as a mistake. They
   run ALONG the wall now, and the span test wants free floor **and unbroken masonry** beside it, so a
   run can never be laid across a threshold either. Units **25 → 13**: the constraint is real.
2. **The floor units were flat decals** — see the art entry above.

**And one exclusion that was a spacing by mistake.** The corridor fittings exclude
`FacilityPoint.places`, `FacilityTables.runs` and `FacilityTables.hugs`' own corner rule — all three
pure functions of the grid, so nothing has to run first. Running the fire points through this pass's
**own** `FIT_SPACING` thinning instead left **three fittings in the whole compound**: 11 points at a
reach of 6 cells sterilise almost every corridor wall. An exclusion says *not here*; a spacing says
*not near anything of MINE*, and only the second is about rhythm.

`CABLE_W` **0.18 → 0.126** on a report that it was too thick — 6 cm at the half-metre unit `WALL_H`
fixes. `facility/fixture-panel` was deleted with the panels it drew.

**VERDICT: landed.** +2 draw calls, +676 tris, +0 programs, four families off one sheet.

## The electrical service, second pass — seven reports, and two of them were the same bug

All seven off one look at the built area. Worth keeping because five of the seven are the same shape:
**a family written against `y = 0` and against its own CELL, in a room that has neither.**

**Kit was in the middle of the floor** — corridors and rooms both. `freeFloor` is not the predicate: a
corridor is **two cells wide**, so BOTH its cells touch a wall and a decal centred in one is still dead
in the walking lane. The scatter now needs a `hug` — masonry, a bench or a standing fitting on one
hand — **and** is slid to that hand's cell edge. 61 → **36**.

**A floor lead ran UNDER the yellow aisle lines.** `RenderConfig.PAINT_Y` is 0.03, the lead was at
0.02 and the scatter at exactly 0.03 (z-fighting it). The stack is three deep and has to be written
against the paint's own height rather than against the floor: **paint 0.03 → cable 0.05 → scatter
0.07**.

**A lead stopped short of the wall.** It began on the FLOOR under its socket, which is a socket's
height away from the socket it is plugged into. Every cable in the file now leaves from one
`anchor` — the mount's own low edge — and a floor lead simply lets its chord fall to the floor: with
`n` straight up, `n × t` stays horizontal however the chord is tilted, so the ribbon does not care.

**A machine's lead left from its LID and hung in the air beside it.** These fittings are SPRITES and a
sprite does not fill its quad's top corners, so `q.h` is a point outside the drawn object. Anchored at
`CABLE_LID_H` 0.35 of the unit's height and 0.35 in from its edge, it is inside the art of all four
kinds.

**And that one broke the sag**, which is the entry inside the entry. Anchors at 0.98 and 0.50 with a
fixed `CABLE_SAG` 0.45 plus `CABLE_WAVE` 0.12 put the mid-span **through the floor** — measured on the
emitted ribbon at **min y 0.0203**, under the aisle paint it had just been lifted over. `CABLE_SAG` is
a **cap** now and `droop()` is the value: the run's own lowest anchor less the floor height, the
ribbon's half-width and the wander. Re-measured **min y 0.0500**, exactly `CABLE_FLOOR_Y`. The
short-lived `CABLE_SAG_LOW` the wall links had been given went with it — one rule, both cases.

**Two cables reached one socket.** The sheet's socket cells draw ONE outlet, so a second lead arriving
at the same plate is plugged into nothing: it is a fact about the ART, not a density rule. `Mount.used`
is claimed in order — drops, then links (which need BOTH ends free), then floor leads. On this compound
that costs the links their one eligible pair, which is the honest trade. **`used` == `runs` + links**
is the invariant, and it reads 20 == 20 + 0.

**And the sheet was never desaturated.** Chroma **10.1** whole against `worktop-clutter`'s own
post-`sat` 1.9 and `bench-pack1`'s 3.3 — the electrical kit shipped as the most saturated thing in a
lab room, the exact complaint those two answered. Missed because industrial colour is the one thing
this family is FOR, and that read as a reason to leave it. It is not. `sat` 0.5 → chroma **4.7**, and
the red, yellow and blue are all still legible as red, yellow and blue.

**Measured after:** 44 mounts / 20 runs / 12 units / 36 scatter, 184 + 400 tris, `calls` **104 → 105 →
106** unchanged, counts identical across a full area rebuild.

**VERDICT: landed.**

## Three more, and two of them were the ART disagreeing with the geometry

**A socket that draws its own cable cannot be used by a family that draws one too, and both ways round
are wrong.** One room, two sockets, both on sheet cell 6 (*a plug pushed in with a short stub hanging
down*): the one carrying one of our leads grew **two cables going two ways** — the drawn stub down, the
emitted run out to the left — and the one carrying none showed a plug whose stub **stopped in mid-air**.
Pairing the two would need a per-cell table of a point AND a direction, measured off the art, for three
cells in sixteen, and the run would still have to be the only cable on a plate that draws two. So
`SOCK_SKIP` = **6, 7, 15** and the band deals thirteen BARE faceplates. **A bare plate says nothing the
geometry then has to agree with** — which is the general rule, and the same one `deco-machine-pack`'s
rejected quadrant records from the other end.

`anchor` also went from the mount's low edge to its **centre height**, which the same look made
obvious: a run leaving the bottom reads as plugged into the wall UNDER the socket. A plate is opaque
where the art is, so a run leaving its middle has its cut end hidden by the thing it leaves — and the
extra half unit hands `droop` its full `CABLE_SAG` back on a short hop.

**A button is not an outlet.** A floor unit came back wired to a red emergency-stop mushroom. Sheet
cells 20 (e-stop) and 26 (a bank of light switches) stay on the wall and are fine there; they just
cannot SOURCE a lead — `FIT_NO_FEED`, tested where the lead is claimed rather than where the fitting is
drawn, because the wall wants the variety and only the cable wants the rule.

**And the floor is already telling you where not to put things.** A unit stood in the middle of a fire
point's keep-clear hatch, which is the one mark in the compound that means exactly that. Not a
clearance this file invents: re-derived off the same two pure functions `FacilityPaint` strikes them
from (`m.doors` filtered by `FacilityGlow.outward`, and `FacilityPoint.places`), so neither builder has
to run before the other. **Per CELL is the whole of it** — a zone reaches `ZONE_D` 3.0 off the SLAB
FACE, and the face is already a unit inside the wall cell, so a hatch covers 2 units of the fitting's
own 4-unit cell and never leaves it. The scatter and the lead's whole span take the same gate.

**Verified on the emitted geometry and not by eye**, which is the only way to check a thing that is
correct when it is ABSENT: walking the hazard mesh's 17 quads as xz rects and every standing quad's
base point in the pack mesh gives **0 of 52 on a hatch** (52 because the test catches every wall mount
too, not just the 8 units — a stricter check than the one the report asked for). `fedByButton` 0,
`drawnCableCells` 0, cable min y still **0.0500**.

**Measured after:** 44 mounts / 16 runs / 8 units / 37 scatter, `calls` **103 → 104 → 105**, unchanged
at +2. Units 12 → 8 is what the two new gates cost, and it is the right price.

**VERDICT: landed.**

## `tools/pastecell.py` — refill ONE dead cell of a packed sheet, and the plug that needed it

`SOCK_SKIP` left `facility/electrical-pack` cells 6, 7 and 15 drawn by nothing, and a run arriving at
a socket wanted a **plug head** to end in rather than merging into the plate. Those two facts answer
each other: **the packed sheet is the source of record**, so a single cell can be refilled without
paying for the other 63.

`pastecell.py` is `pack16.py`'s other half — same `CUT` 24, same margin convention, same alpha-box
crop and one-scale fit — but it writes into a cell of an existing sheet instead of re-packing a whole
drop. The plug therefore rides **the same texture, the same mesh and the same draw call** as
everything else in the family: measured, `calls` 104 → 105 → 106, unchanged at +2, pack 184 → 194
tris (8 plugs at 2, less the 4 units the new gates cost, plus a scatter).

**NO CABLE ON THE PLUG**, which is the same finding the three skipped cells taught, applied forward:
art that draws its own lead cannot be placed by a family that emits one. The head has a gland collar
and nothing leaving it. gpt-image-2.5-**flare** at quality high, **$0.0541** — flare and not sunburst
because one centred object is not a layout problem, which is the whole reason to reach for sunburst.

**IT IS BUILT FROM A WORLD BASIS AND NOT THROUGH `pane`**, which is the only interesting line of the
emitter. The art has to TURN so its gland follows the cable, and `pane` takes an axis-aligned rect and
an upright v. So the quad picks the art's own UP — down the wall for a lead heading into the room,
along the wall for one running to a neighbour or up to a machine — and the rest falls out of
**`R = U × n`**, which reproduces `FacilityGeom.ends`' handedness on every face with no table (face
0's "right" really is −x) and keeps the front face looking into the room by construction.

**Sockets only.** A lead leaving a corridor junction box leaves through a **gland**, and those cells
draw their own.

**VERDICT: landed.** +0 draw calls, +16 tris, one $0.054 image into a cell that was already dead.
Cells 7 and 15 are still dead and are where the next one goes.

## A BLOCKLIST WAS THE WRONG SHAPE, and a sprite's quad is not its silhouette

Two reports off one corridor, and they answer two different questions the family had been getting
wrong quietly.

**THE FEED LIST HAD TO BE AN ALLOWLIST.** `FacilityStyle.FIT_NO_FEED` named the two corridor cells
that were obviously absurd — sheet cell 20 a red emergency-stop mushroom button, 26 a bank of light
switches — and shipped the other **fourteen** of the band as cable sources, so the game went on
reporting leads growing out of a sealed breaker board, an electricity meter and a battery box. The
question a blocklist asks is *"is this one absurd"*, and the question that actually decides it is
*"does this one draw somewhere a cable can come out of"*. Only **6 of the 16** do: cell 16 a junction
box with four cable glands, 22 a run of steel conduit, 23 a cable tray with cables already lying in
it, 27 a bracket holding a coiled reel, 29 a bundle leaving the wall through a grommet plate, 31 a
socket outlet box with an isolator lever. `FIT_FEED` is that list, `sources(p)` is the one predicate,
and it is asked at **every end of every run** — `units` and both ends of `links` — where the old test
was asked in one place. A room socket needs no such list: every cell of its own band is an outlet by
construction, less the three `SOCK_SKIP` deals out for drawing their own cable.

Measured, same compound, same seed: **44 mounts unchanged, 14 of them corridor fittings; runs 16 → 11,
units 8 → 3**, and the three fitting cells left wired are **16, 23 and 29** — all three in the list.
Five units went away and that is the whole point; the compound supplies the emptiness, the same
argument `links` runs on. Corridors are also the only place a unit ever stood: of 30 room sockets,
zero reach a clear span, because `run` needs free floor AND unbroken masonry for 2 to 4 cells and a
laboratory is mostly bench.

**BOTH CONTACTS WERE SIZED TO THE QUAD.** A standing unit handed `FacilityDetail.stand` its own
`UNIT_SZ` 2.6 as the extent, and `grow` turned that into **4.33 of gradient for 1.66 of art** —
reported from the game as a wall shadow far too large for the thing casting it, and it was. A sprite
does not fill its quad, which is the same fact `CABLE_LID_H` is a third rather than a lid for.
Measured off the built sheet over all sixteen standing cells (opaque bbox, alpha > `pack16.py`'s own
`CUT` 24): width mean **0.637** median 0.637, height mean **0.767** median 0.754 — shipped as
`UNIT_FILL_W` 0.64 / `UNIT_FILL_H` 0.77, so the halo is now 1.66 × 2.00 grown to 2.77 × 3.33.

**AND THE FLOOR HAD NOTHING AT ALL.** Every builder that stands something indoors feeds
`render.world.ContactMask.prop` and this one never did, so the units alone sat on the floor with no
darkening under them. One call with the same art-sized footprint, square because a sprite has no depth
to read one off. **No quad, no mesh, no draw call** — it is a field. A/B on one pinned pose by setting
`ContactMask.uAmt.value` to 0 and back, on the floor beside a wired cable drum: **92–99 flat with the
field off, 73 / 61 / 53 / 44 / 37 / 31 with it on**. The rects are in `propRects` at the exact 1.664
extent, which is the check that survives the corridor being unlit.

**VERDICT: landed.** +0 draw calls, +0 programs, −5 floor units and −5 runs, and the two shadows a
standing thing is supposed to lay.

## A STANDING SPRITE PARKED ON A WALL CANNOT AFFORD THE TILT, and what going upright costs

Reported from one corridor: a floor unit's **top was cut off**, and its lead **came out under it**
because half the band stands on legs.

**THE TOP WAS INSIDE THE MASONRY.** `render.particles.Sprites.TILT` is 0.6 rad — **34.4°** — and every
actor sprite and bench decoration in the compound leans back by it. A unit is the only one of them
parked ON a wall, and the arithmetic is not close: at `UNIT_SZ` 2.6 the lean carries the quad's top
**sin(34.4°) × 2.6 = 1.47** backwards against the **`UNIT_OFF` 0.9** it stands clear of, so the top
**0.57 of depth is behind the slab face** and the depth test eats it. `FacilityStyle.UNIT_TILT` is a
knob of its own and it is **0**; `stand` keeps the general basis so it stays a knob.

**AND WHAT UPRIGHT COSTS IS MEASURED, because it is not free.** The tilt is not decoration — it is
what points a sprite at a camera that looks **65.6° below horizontal** (read off
`view3d.camera.getWorldDirection`). A quad's apparent height is the cosine of the angle between its
own plane and the view:

| lean | angle off perpendicular | height kept |
|---|---|---|
| `Sprites.TILT` 34.4° | 31.2° | **0.855** |
| upright 0° | 65.6° | **0.413** |

So going vertical **halves the art's apparent height** — measured in frame on the same unit, 43 → 28
screen px. It buys a silhouette that is whole and sells one that is tall, and the two other ways out
both keep the tilt: stand the unit further off the wall (`UNIT_OFF` 0.9 → 1.6 clears 1.47 and is still
inside its own 4.0 cell), or make it shorter. Written down here because the next family that stands a
sprite against a wall meets the same three.

**THE LEAD ARRIVES ON THE BODY.** `UNIT_FOOT` 0.10 of `UNIT_SZ` — 0.26 world — instead of the floor
height the run used to end at. Half this band stands on **legs, castors, feet or a pallet** (the
sheet's own rows 5 and 6 say so in as many words), so a cable ending at the base ends **under** the
object rather than at it. One site, `run`'s `c`; the wall-plane runs are unaffected because they never
touch the floor.

**AND IT ARRIVES BEHIND THE UNIT, WHICH IS THE UPRIGHT CHANGE'S OWN BILL.** Leaning, the quad swept a
range of depths and its base point sat at the front of that range; **upright, the base point IS the
plane**, so a lead ending at `b` ended exactly coplanar with the art and won the depth test often
enough to draw over it — reported as the cable being in front of the object. `UNIT_BACK` 0.15 of
`UNIT_SZ` = **0.39** toward the wall gives the sprite the body depth it does not have, against the
`UNIT_OFF` 0.9 it stands clear of, so the end is behind the art and still well off the masonry. Where
a lead plugs in anyway.

**AND TWO CELLS OF THE BAND CANNOT TAKE IT AT ALL.** Sheet cell **35** is a distribution board up on
four long spindly legs and **43** an extension block on a splayed stand; a tenth of the way up either
of those is the **open air between the legs**, reported from the game as a lead ending in nothing.
The thing not worth building here is a per-cell foot height — sixteen numbers measured off the art to
spare two cells, when the other fourteen stand on a base, feet or castors and take the lead at a tenth
with nothing to say about it. So `FacilityStyle.UNIT_SKIP` deals them out, `STAND` derives the dealt
list off it exactly as `PICK` does off `SOCK_SKIP`, and a standing unit exists only because a run
stood it — so *cannot be wired* and *is never dealt* are the same sentence here. Verified by decoding
the emitted pack mesh's own UVs back to cell indices rather than by looking: the standing cells drawn
are **39, 42 and 47**.

**VERDICT: landed, and the upright half is a LOOK the user asked to see rather than a settled
number.** +0 draw calls, +0 tris, counts unchanged at 44 mounts / 11 runs / 3 units / 37 scatter.

## AN ACTOR POSE IS NOT WHERE THE THING IS DRAWN, and a fake cast shadow is the one reader that shows it

Reported from the game as *"the barrel tile looks like there is a contact shadow patch in the centre, but
the barrel is near the wall — probably all near-the-wall glb have this issue"*. Right about the symptom,
and the first pass chased the wrong subsystem: `ContactMask` is correct here and always was. Its rect for
that drum is `x -104.32..-103.12, z -94.60..-93.40`, centre `(-103.72, -94.00)`, which is the glb
instance position to the digit.

**WHAT IT ACTUALLY IS.** A raycast through the smudge pixel hits a mesh a clean floor pixel does not:
a single quad at `y = 0.06`, 3x3 base scaled `(0.72, 0.64)`, laid flat and turned `-0.785` about z,
`opacity 0.191`, `depthWrite false`, `renderOrder 3`. The `0.06` is literal — `LampShadows.actorShadow`
lays its fake cast shadows on `WorldCtx.floorY(...) + 0.06`. Proved by knockout: `LAMP_SHADOW.op = 0`
removes the smudge and nothing else; `renderer.shadowMap.enabled = false` moves **3** of 255 in the whole
crop; `ContactMask.uAmt` 0 <-> 0.9 moves only a band on the wall and under the barrel and **nothing** at
the smudge.

**THE BUG IS ONE LINE OLD AND STRUCTURAL.** `LampShadows` projects from `a.x, a.z` — the Actors-map
pose, which is the cell centre. Every facility fitting family is drawn OFF THE WALL FACE instead, and
the face is a whole unit inside the cell boundary, so the offsets are large: **2.28** of a 4-unit cell
for a drum, a bin, a rack or a cabinet (3.0 - (half-depth 0.6 + `STAND_GAP` 0.12)), 2.25 for a bookcase,
1.78 for a low machine, 1.48 for a full one. The contact pool, the wall halo and the glb placement are
all built off that same moved rect and all agree; the POSE was the one thing left on the cell centre.
It never showed as a misplaced icon because `FacilityDeco.draws` suppresses the icon — the fake shadow
is the only consumer of the pose that draws anything, which is why a structural mismatch surfaced as
one smudge beside one barrel.

**THE FIX PUTS THE OFFSET ON THE POSE, not on the frame.** `ActorOpts.offx/offz` already existed for a
fallen corpse, but it was applied at draw time only (`wx = a.x + o.offx`) and never reached the map —
so corpses had the same bug at smaller amplitude. `ActorAnim.Actor` now carries `offx/offz`,
`Actors.drawActor` writes them from the opts before anything reads the pose, and `LampShadows` projects
from `a.x + a.offx`. The facility supplies its offset through a new per-cell hook,
`WorldCtx.standOff`, the same shape and the same null-elsewhere contract as `wallMounts` —
`FacilityDeco.standOff` answers it off `rectOf` for the emitted family and off a new `roundAt` for the
two glb ones (pulled out of `placeRound` exactly as `rectOf` was pulled out of `unit`, so there is no
second hand-written copy of the slab arithmetic).

**VERIFIED IN GAME.** Poses now read `(-106, -94) + (2.28, 0) = (-103.72, -94)`, matching the instance
matrix; the low machine at (23,24) reads `+1.78`; a fitting with no wall on any hand reads `+0`. The
two drum shadow quads moved from `(-105.33, -94.67)` and `(-105.33, -85.33)` — mid-tile — to
`(-102.76, -94.61)` and `(-102.76, -85.39)`, anchored on the drums.

**AND THE SHADOWS ALL BUT VANISHED, WHICH IS THE CORRECT ANSWER AND WORTH KNOWING.** `LAMP_SHADOW` is
`rangeCells` 2 with a `fade` of 0.3 and a `distFade` of `1 - d/range`, so pushing a fitting 2.28 further
from its lamp drops those two from `op 0.191` to **0.003**. The mid-tile smudge was not a shadow in the
wrong place so much as a shadow that should never have been cast at that strength: the fitting was
being measured against the lamp from a spot it does not occupy. If wall-hugging props should read as
shadowed at all, that is a `rangeCells` / `lenMul` conversation and not this one.

**VERDICT: landed.** +0 draw calls, +0 programs, +0 meshes — two floats on a record that already
existed per actor, and one hook that is null in every area kind but the facility.

## THE BENCH FAMILY REPAINTED FLAT, and a sprite that leans back does not stand where it is anchored

**The ask was an art pass and the bug underneath it was geometry.** All four `facility/bench-pack`
sheets were repainted flatter by `edit_image` (gpt-image-2.5-sunburst, quality high,
`background:"transparent"`, **$0.064 a sheet**) — the prompt locks layout, positions, sizes and
colours and changes only the painting, with a named list of micro-detail to delete. Layout held on
all 64 cells; `pack16.py` found clean corridors on every sheet. It came back **+30% brighter and
+40% chroma** on all four, carried by per-sheet `lift`/`sat`. **The `lift` response is not the naive
gamma model**: the first fit undershot at 1.20x against a 1.30x target, and the second pass had to be
taken off the measured ln-gain per unit lift (~1.5–1.8). Budget two `make tex` passes and read
`built_linear` back.

**THEN EVERY DECORATION WAS REPORTED HANGING IN THE AIR, and the art was not the cause.** Content
boxes and bottom margins came back byte-identical to the old sheets, so the anchor had not moved —
but `Sprites.TILT` is 0.6 rad and the quad leans about its own CENTRE, so every point below that
centre swings toward the camera **and rises**. The content bottom — the part that reads as resting on
the worktop — came up by `d·(1−cos TILT)` = `3.0 × 0.81 × (0.5 − 0.031) × 0.1747` = **0.199 world
units**, a fifth of a tile of clear air, which is also why each group sat visibly behind its own
contact pool. `groundAnchor` already dropped them by the sprite's empty bottom margin; nothing took
the lean back out. Fixed with `ActorOpts.tiltSink`, applied inside that same drop and gated by
`FacilityDeco.spriteSinks`. **Opt-in on purpose**: every upright sprite has this rise, but an actor's
art is posed against the same lean and was tuned with it, so sinking those would bury their feet.

**AND "no shadow" IN A REPAINT PROMPT TAKES THE GROUNDING WITH IT.** The old sheets carried a painted
contact shadow. The runtime pool (`TABLE_POOL_*`) is a decal on the WORKTOP and the tilt carries the
drawn base off it, so the art was always the half that closed the gap. `pack16.py --shadow 0.35`
bakes it back deterministically instead of re-rolling sixteen cells and hoping — ellipse first, art
`alpha_composite`d over it (plain `paste` REPLACES alpha and punches the shadow back out). Pure
black, so `lift` and `sat` both leave it alone.

**THE CLUTTER THEN READ BRIGHTER THAN THE STANDING KIT, AND THE TEXTURE NUMBERS SAID THE OPPOSITE.**
`worktop-clutter` builds at 0.0796 linear against the packs' 0.128–0.144 — the art that is 1.7x
brighter lost on screen, because a flat decal takes the overhead term square-on while a leaning quad
takes ~`sin(56°)` of it. **The first knob was the wrong one**: `lift 1.12` moved the offenders by
nothing (mouse mat 112.2 → 112.6), because they sit pinned AT the `cells` cap and a gamma under it
cannot reach them. `cap` 0.105 → **0.08** (26/64 → 38/64 cells moved): mat 45.6 → 40.9, paper
43.6 → 39.4, standing rack **unchanged at 43.0** as the control. Which pixels were even clutter was
measured, not eyeballed — rebuilt at `lift 3.5` to black the family out and read off the frame, which
corrected a guess.

**THE SINK WAS LAST, AND `lift` COULD NOT TOUCH IT EITHER.** `facility/sink` is a flat basin and an
upright tap on one sheet, and its own note had already called this: lift is per LABEL and the two
cells want different moves. Tap p90 **132.7** against the sprites sharing its bench at 61.7–64.0.
Per-cell gamma at composite time — the `facility/placards` route, promoted to **`tools/cellgamma.py`**
now that a second sheet needs it. Tap 2.0 (srgb 157.0 → 98.8, screen 93.7 → 72.7); the rim was then
the brightest thing left, unchanged at 94.0 while the tap came down past it, so basin 1.27
(84.7 → 63.1, screen 94.0 → 66.0). Final: tap 71.7, rim 66.0, against scale 64.0 and rack 61.7
**unchanged in the same frame** — two still controls are what prove only two rects moved. Pristine
source parked at `textures-src/facility/Unused/sink.png`; a gamma stacks, so every retune starts there.

**VERDICT: landed.** +0 draw calls, +0 programs, +0 meshes — one bool on an opts record, one
null-elsewhere gate, and four texture constants.

**THE TRAP THAT COST THE MOST TIME HAS NOTHING TO DO WITH ANY OF IT: `make tex` runs `adopt` FIRST.**
A drop left in `textures-src/` as `edit-<ts>-<hash>-bench-pack1.png` is renamed in place over the
packed sheet and built, with a build line that reads exactly as it should. Delete the drop, or
generate outside the tree, before `make tex`.

## THE FACILITY GETS TWO MORE ROOM TEMPLATES — and the theme is the FLOOR TILE

**Every room in the compound was the same chem lab.** `FacilityAreaGenerator.generateRoomContents`
called `roomChemistryLab` on all of them, every room floor finalised to `TILE_FLOOR_TILE`, and the
3D layer bucketed every interior face into `wall-room` vs `wall-interior` and every interior floor
into three textures. `CorpAreaGenerator:292` has had four office THEMES all along — size, a quota and
dice, each theme painting its own floor tile and drawing from its own furniture set, with no enum, no
typedef and no persisted tag. That shape is what was copied.

**THE FLOOR TILE IS THE WHOLE RECORD, and it reuses ids that already exist.** A researcher's OFFICE
floors in corp's `TILE_FLOOR_WOOD1` and a WASHROOM in `TILE_FLOOR_MARBLE1`, both with the unwalkable
twin one tileset row below that the cells under furniture take. **No tile id, no `tiles.Default` row,
no `generatorInfo` field, no migration, no Saver work** — `FacilityModel.surfOf` maps the two ids to
new `Surf.OFFICE` / `Surf.WASH` before the row-8 catch-all, and `FacilityGeom.look`/`floorBuf` pick
wall and floor off the cell a face looks INTO, exactly as the room/corridor split already did. Old
saves hold neither id and come back all-lab. The facility has had no 2D view since `showFacility`,
so tile ART never entered it and a fitting's atlas frame is a KEY `Const.fittingOf` reads back.

**A DESK CELL IS A BENCH TILE, so the surface has to be SPREAD over the room's rect.** `surfOf`
resolves every table tile to `Surf.TILE` through the row-8 catch-all, so the floor under an office's
desks and the wall behind them stayed laboratory. `FacilityModel.themeRooms` walks `generatorInfo`'s
room rects after the grid is built and stamps every `TILE` cell of a rect that holds a themed one.
A pre-change save holds no themed cell in any rect, so it is a no-op there by construction.

**THE DESK IS THE LAB BENCH ONE TEXTURE FAMILY APART.** The generator lays both as the same runs off
the same table tiles, so the split is two more `MeshBuf`s in `FacilityTables.build` picked off the
cell's own `Surf` and no geometry at all; `FacilitySink` skips an OFFICE run, and `FacilityClutter`
picks its 8x8 sheet the same way. The washroom is `FacilityDeco`'s two new fitting kinds:
`FIT_STALL` (two partitions and a door leaf, a `facility/toilet` glb inside) and `FIT_BASIN` (a
counter, the lab sink's OWN sheet for bowl and tap, a mirror on the masonry above). Cubicles,
leaves and counter are one laminate and so **one buffer and one draw call**.

**A PARTITION IS A BOUNDARY AND NOT A SIDE.** Emitted per unit, two neighbouring cubicles both draw
the divider between them on the same plane and z-fight down its whole height. Each unit takes its
`head` side ALWAYS and its `head + 1` side only where the next cell is not another cubicle: n
cubicles, n + 1 partitions. It works only because `STALL_W` is exactly one cell, so every plane
lands on the grid the cells do.

**THE PAN'S VALUE COULD NOT BE FIXED WITH `--lift` AND THE MONITOR'S HAD TO BE.** The ceramic
reference came back at p50 **207**; the lift to 120 is a gamma of **3.588** and published the drop's
own warm cast — channel spread **26 -> 54**, a tan toilet. A lift moves VALUE and cannot fix hue, so
the pan ships the untouched reference and `baseColor` **0.22** flat, landing the 230/210/203 bake near
110 srgb, just over `facility/floor-wash` 100.5. The workstation went the other way: p50 **40**, which
propstat calls TOO DARK and bakes crushed, lifted to 73 (gamma 0.671) BEFORE TRELLIS saw it, then
`baseColor` 0.51 to the indoor 78 the trolley and the drums record. `tex` 256 and not 512 — at 1,200
tris the larger map reads 218 texels/tri against the 43-55 band.

**THE LAB'S CLUTTER SKIP LIST DOES NOT PORT.** `facility/office-clutter` is the same PACK64 shape as
`worktop-clutter` (sunburst, transparent, SEPARATION clause leading): **66.5% transparent, all 14 seam
lanes at ZERO opaque px**, so `pack16.py --cols 8 --rows 8 --cell 128 --valign center` packed it at
**tol 0** where the lab sheet needed `--tol 4`. But the dark-AND-solid test was measured against
`bench-top` **0.0401** and a desk top is **0.1168**, so the same relative threshold condemns half the
sheet — a dark object on a PALE desk is an object. `CLUTTER_OFFICE_SKIP` stays empty until something
reads as a hole in game.

**VERDICT: landed.** **+8 draw calls** on a pinned office pose (10 merged meshes, interleaved A/B,
median of 7 frames: **119 on / 111 off / 119 on**), plus 2 glb batches. On one generated compound:
**1 washroom + 2 offices** over 19 rooms, 2 cubicles, 2 basins, 7 workstations. Fitting cells
unwalkable (`MARBLE1 + 16`), room floors walkable, **0 console errors**.

## THE WASHROOM WAS A ROOM WITH NO PRIVACY AND THE WORKSTATION WAS A BOX — pass 2 on the room templates

Reported against the shipped templates, in the reporter's own order: the toilet took the lab's
ordinary ribbon glazing and its ordinary see-through door, it was one undivided room, its cubicle
laminate had no door line; and the office reused the lab bench whole — full depth, drawers on every
face, no sockets, no cables, no chairs, and a blocky glb computer facing the wall.

**THE LIGHT WELL IS A NEW `Wall` VALUE AND NOT A FLAG ON `WINDOW`, and that is what made it free.**
`render.world.VisionMask`'s blocker test reads `isWall && wall != WINDOW`, so a fourth enum value is
taken as solid by the render mask with no edit at all; `tiles.Default.TILE_SEETHROUGH` row 2 index 10
goes to 0 and the game's own `canSeeThrough` agrees. It took the DEAD `Const.TILE_XXX` slot — one
declaration, zero uses in the tree — so there is still no new tile id in this feature. `FacilityGlow`
skips `w.high` in both of its loops: no ground trapezoid and no fake shadow source, because a slot
1.2 tall with its head 0.9 under the deck throws light UP and out, not down onto the pavement.
Measured from outside: two lit slots high on the wall and the apron under them dark.

**THE ART CAME BACK OPAQUE TWICE AND THE FIX WAS A CROP.** `background:"transparent"` failed at
0.0% on a prompt that said "no wall, no masonry, no sill" — the NAMING A SURFACE trap — and failed
again at 0.0% on a re-roll that said only "the ONLY thing in the picture". This style prompt asks for
a dark moody field and the model paints one. So the unit was MEASURED instead: glass thresholds at
luma > 120 to x 146..876, and walking outward the aluminium (luma ~58) runs to x 130..892 / y 384..618
against a background of ~35. That rect is the `crop`, the file is opaque, `loadAlphaCropped` finds
nothing to trim, and `WINDOW_HIGH_ASPECT` 3.2405 comes off the 512x158 output exactly as the two
ribbons' aspects come off theirs.

**THE MALE/FEMALE SPLIT IS A LINE OF FITTINGS AND NOT MASONRY.** `state.rooms` is frozen at
`makeDoors` and the room ids are already stamped into the cell grid, so a wall written after that
leaves two halves sharing one `_Room`, one id, one ceiling light and one stale mark — and
`makeWindows` would `drawBlock` the whole stale rect back over it. `FIT_PARTITION` costs none of
that: `placeFitting` stamps each cell unwalkable exactly as a cubicle does, `FacilityDeco.partition`
stands a full-height slab on it in the cubicle laminate (**B_STALL, so zero new draw calls**), and the
cell left bare at each end of the line IS the passage. One room, one corridor door, and the men's and
women's plates flank that one opening.

**A THEMED ROOM'S DOOR WAS SWINGING INTO THE CORRIDOR, and pass 1 put it there.**
`FacilityModel.findDoors` picks the swing side with `m.surf[..] == Surf.TILE` on both hands, which was
"is this a room" until a room could be `OFFICE` or `WASH`. With those, neither hand read as a room,
the tie fell through to `+1`, and half of them opened the wrong way — the very doors that most need to
swing inward, being the only ones that shut. The test is now `!= Surf.LINO`.

**THE WASHROOM IS PICKED FOR ITS WALL.** Its light wells need one wall that is exterior masonry end to
end, and a room in the middle of a building has none, so a plain first-come roll put the compound's
only washroom in an interior core and it came out with no glazing at all — observed on the first
generated area. `assignRoomThemes` now gives the toilet first refusal on a perimeter candidate; the
lab and the office are indifferent. Over 8 regenerations of one compound: a toilet in 5 (the 60% roll,
per structure), and **every one of them got its light wells** — 2-3 cells, 24-35 marble, 4-8 cubicles,
3 basins, 2-3 partition cells.

**THE WORKSTATION WENT THE OTHER WAY DOWN THE TRIAGE: glb → GEOMETRY.** `facility/computer.glb` spent
1,200 triangles rounding the corners off three axis-aligned slabs — CLAUDE.md's own "a box is not a
prop" answered a build late. `render.facility.FacilityWork` emits the set as 22 quads, and **every
face samples ONE sheet by sub-rect** (the `facility/sink` idiom): four labels would be four materials,
four meshes and four draw calls to draw one desk toy. At `WORK_SCREEN_W` 1.7 the screen cell gives 150
texels per world unit against `floor-tile`'s 73. The CHAIR stayed a glb and that is the same rule
answered the other way — a shaped back over a five-star base on castors is an outline no quad states.

**THE TOWER'S LIGHTS AND THE DESK LEADS COST NOTHING, because both families already had a buffer.**
`FacilityDeco.build` and `FacilityCable.build` each take a borrowed `MeshBuf` now, filled by
`FacilityWork` before they merge: the status specks join the server racks' additive mesh (same shared
`uTime`, same `blink` patch, same draw call, no per-frame work), and the keyboard leads ride
`FacilityCable`'s ribbon through `strip`, which was already a general world-space function and needed
only `public`. The one ordering constraint in `FacilityArea.build` is that the borrower runs first.

**SOCKETS IN AN OFFICE COST ONE OPTIONAL ARG.** `FacilityPlacard.hangs` is shared by the signage and
by `FacilityCable.sockets`, and its `Surf.TILE` gate was keeping the electrical service out of a room
that plainly wants it. It takes an `office` flag that only the cable family passes — the eight plates
on the two placard sheets are laboratory hazard signage, and a biohazard trefoil over a desk is
exactly what that gate exists to prevent.

**THE ROOM SIGNS HANG OUTSIDE, WHICH IS THE OPPOSITE OF EVERY OTHER SIGN HERE.** The hazard placards
are gated on `Surf.TILE`, hang on the room's own side and are chosen by what stands under them; these
hang on the CORRIDOR face beside a themed room's door and are chosen by what the room IS. The two
nameplates are deliberately ILLEGIBLE smudge bars and the prompt spends four clauses on it: a legible
plate has to say a name and no researcher in this game has one. Asked that way the model drew bars,
not glyphs.

**VERDICT: landed.** **+3 draw calls** measured on a pinned office pose (interleaved A/B ×4, median
of 5 frames each: **114 on / 111 off**) for `desk-side`, `workstation` and `room-signs`; the light-well
pane and the chair batch are one call each where they appear, against the deleted computer batch's −1.
Live on one generated compound: light wells blocking sight (`canSeeThrough` false, `isVisible` false
through the wall AND through the shut private door, true the moment it opens), `closedCol` 12 on every
themed room's door, 3 workstations, 2 chairs, 3 WC pans, 3 signs, **0 console errors**. One thing seen
and NOT fixed, because it is pass-1 art and nobody asked: `facility/mirror` at 0.0335 linear reads as a
black rectangle against the wash wall in a close shot — the dark-AND-solid failure, from the other side.

## Pass 3 on the room templates: the T, one laminate per surface, and a `sat` for glbs (2026-09-12)

Nine things reported off the shipped pass 2, and they divide into three groups. **PLACEMENT**: server
racks standing unwired, clue documents spawning through basins and monitors, a desk decal hanging in
mid-air off a desk's front edge. **VALUE**: the gas rack, the hazard drums and the office chair
reading as toys, the mirror reading as a hole. **THE TEMPLATES THEMSELVES**: a washroom whose divider
divided nothing, one texture worn by four different surfaces, and an office with two machines and
four bare desks.

**A FED SOCKET IS JUSTIFIED BY ITS MACHINE AND NOT BY THE WALL'S RHYTHM.** `FacilityCable.sockets`
deals the machines first — the ordering that whole family turns on — but it tried only the cell either
side of the unit and then put the candidate through `SOCK_SPACING` 4. A rack in a run of fittings has
both neighbours taken, and two racks inside four cells wire only the first. **MEASURED on one compound
of 35 racks and machines: 11 wired.** The walk now reaches two cells on each hand and the only
thinning left is "not a cell some other mount already took" (`spaced` at 1): **25 of 35, every one of
them `used: true`**, with 30 of 35 having an eligible cell at all and the residue being two racks that
want the same one. The bare pass below still keeps its full spacing off these, so the wall does not
fill up behind it.

**A `sat` KEY FOR `art/models.json`, and it is the same instrument in the same space as the two that
already existed** — `textures.json`'s own `sat`, `tools/textures.py sat_mix`, and the `spriteSat`
uniform: mix every pixel toward its own Rec.709 luminance IN LINEAR LIGHT, `1.0` a byte-exact no-op.
There was no saturation knob in the glb pipeline at all, only `baseColor` (a per-channel factor) and
`lift` (a gamma), and neither can do this: the only way a factor flattens a 135/91/26 atlas is to
invent blue, which is the neutraliser `facility/gas-cylinders`' own note rejects. At 0.5, MEASURED
atlas chroma: **gas-cylinders 108.7 → 39.8, drum-bio 45.9 → 19.1, drum-rad 45.5 → 23.7, chair 69.5 →
21.6**. `facility/drum-steel` did NOT take the key — measured at 15.0 it is already a blue-grey steel
drum and halving that is a dead neutral. **THE TRAP: the atlas channel MEAN MOVES ANYWAY** (135/91/27
→ 121/97/81) because propstat prints an sRGB-byte average and the transfer curve is concave, so three
channels converging on one luminance average higher. Per-pixel luminance is untouched by construction.
Do not read the rise as a brightening and do not chase it with `baseColor`.

**AND 0.5 IS NOT ONE NUMBER FOR THE WHOLE FAMILY — THE GAS RACK CAME BACK REJECTED AT IT** ("there
were orange, now it's almost white") while the three drums and the chair were accepted at the same
key. Two things compound on that one prop and neither is in its chroma figure. Its albedo is a FLAT
`baseColor` 0.95 against the drums' gain-fitted ~78 luma, and **a desaturated BRIGHT surface is a pale
surface where a desaturated MID one is a grey one**; and the room's light is strongly blue (ambient
0x46536b, hemisphere 0x56668c, a 0x8294c0 moon), so it ADDS blue back to whatever chroma the albedo
has left and an amber loses twice. Re-fitted to **0.75: atlas chroma 63.2, sampled 46.9** (0.5 was
39.8/29.5, the raw bake 108.7/81.6), atlas 128/94/65. **READ THE LEVEL AND THE HUE TOGETHER when
picking this key: the sat that mutes a prop at luma 78 washes one out at luma 110.**

**THE WASHROOM'S DIVIDER IS A T NOW, AND THE SINGLE LINE NEVER DIVIDED ANYTHING.** Pass 2 ran one line
down the middle with the cell at EACH end left open, so the two halves were joined at both ends — you
walked in and could see and reach the whole room, which is the one thing a washroom may not do. The T
is the same fittings in a different shape: a BAR parallel to the entrance wall and **one cell in from
it** (the strip it leaves is the lobby) with its two end cells open, plus a STEM from the middle of the
bar to the far wall. Door → lobby → one gap into each half, and no path between them. Checked by
replicating the placement over **every room the generator can deal — 3x3 to 7x7 by four door walls,
100 cases — flood-filling each: two non-empty halves, both reached from the lobby, none reached from
the other**. `roomToilet` then furnishes each half on its own (its longest wall cubicles, its next
basins), because sorting all four walls together put every cubicle on one side of the T.

**A T JUNCTION NEEDS A SECOND ARM, WHICH `rectOf` CANNOT STATE.** A partition cell gets ONE rect,
spanning its cell on its own line's axis and `PART_T` across — so where a second line arrives on
another hand, that neighbour's slab reaches the shared cell boundary while this cell's reaches
`PART_T / 2` from its centre: **(CELL − PART_T) / 2 = 1.7 units of daylight straight through the
wall**. `FacilityDeco.partition` now patches exactly that gap per crossing hand, from its own arm's
SURFACE out to the boundary — not from the centre, which would overlap its own lid on a 0.6 x 0.3
square of coplanar quad and z-fight at the top of the wall. Verified on a synthetic T stamped into
`FacilityModel.demo()`: the partition mesh comes back with **6 patch quads (extent 1.7) and `ymax`
6.0**, three per crossing hand, and the neighbour's end face was already being skipped there.

**ONE LAMINATE IS NOT ONE SURFACE.** `facility/stall-panel` was re-rolled in pass 2 as a cubicle DOOR
— a leaf between two pilasters with a latch plate and a pull handle — and it was worn by the cubicle's
blank SIDE panels, by the basin counter's apron and by the full-height wall between the two halves, so
the compound grew a door on all three. The counter's LID wore `facility/desk-top`, the researcher's
office desk. Four labels off one packed 2x2 (`facility/wash-pack`, seams measured at x 511 / y 511,
crops inset 2 px): `wash-partition`, `wash-counter`, `stall-side` and `wash-counter-top`, built to
**0.1304 / 0.1227 / 0.0963 / 0.1543** linear — the side panel fitted to the leaf's own 0.0887 so the
two agree across the corner they meet at. **+3 draw calls, in the one room that has any of them**,
which is the rack's trade again: the call is what the read costs. And `PART_TILE`: the divider was
passing `STALL_TILE` 3.8 as its period on a 6.0-tall wall, so a bottom-up composition wrapped at 63%
of the height and drew a second skirting shadow across the middle of it.

**A MISTED MIRROR REFLECTS NOTHING BY DEFINITION, which is the way out of a problem the art could not
otherwise solve.** The pass-2 mirror was painted as dark glass — correct reasoning (a mirror in a dark
room reflects a dark room) and 0.0335 linear, a black rectangle over the basins. A reflection cannot
be painted here at all: the art is fixed and the room behind the player is not, so anything
recognisable in it is wrong from every angle but one. Condensation makes the blankness the subject.
Solo roll (a 0..1 square face cannot come off a shared sheet's wrap error), `lift` **2.05** → **0.2657
linear against `wall-wash`'s 0.1593**, i.e. 1.67x the wall it hangs on and the lightest thing in the
room, where it was 0.21x.

**`WORK_EVERY` 3 → 1 WAS THE LAB'S ARGUMENT IN THE WRONG ROOM.** "A workstation on every cell reads as
a computer lab" is true of a laboratory BENCH — a work surface with a screen every metre is a server
room — and false of a desk, which is somebody's PLACE. The compound's offices deal 4-9 desk cells, so
at 3 a room came back with two machines and four bare desks. Live: **`work` 10 on 10 office desk
cells**, each with the screen, the tower, the keyboard, the leads, the lights and a chair behind it.

**AND THE DESK'S OWN ITEM IS PLACED, NOT ROLLED.** `FacilityClutter` finds a spot by rejection
sampling, which works on a bench because a bench is 4 x 4 of free worktop; a workstation desk is 4 x
2.6 with a screen, a stand, a keyboard and a tower on it. **MEASURED: the sampler dressed 5 of the 10
desks and left the other five bare** — and that was with a keep-clear cut from `WORK_R` 1.6 (the
contact POOL's radius, which as a clearance leaves no desk at all) to `WORK_CLEAR` 1.05. There is
exactly ONE free area on such a desk and geometry knows where it is, so `FacilityWork.at` now hands
over the tower's hand (`WorkSpot.side`, rolled off the hash `set` already used) and the item goes at
the other END of the desk outright. **10 of 10 dressed, 12 decals.**

**A DECAL WANDERED THE WHOLE CELL WHERE THE DESK IS ONLY `DESK_D` 2.6 OF IT**, so it could land
`(CELL - DESK_D) / 2` = 0.7 past the front edge and lie at `BENCH_H` over bare floor — reported as a
table decoration floating in the air beside the desk. The wander is now per axis against the desk's
real rect, both numbers off `DESK_D` and `FacilityTables`' own hand search. **MEASURED after: 12 office
decals, 0 outside the worktop, worst overhang 0.000.**

**A CLUE SPOT IS A BENCH TILE WITH NO OBJECT ON IT, AND TWO FAMILIES DRESS SUCH CELLS WITHOUT BEING
OBJECTS.** `FacilitySink` takes a free edge cell of every bench block and `FacilityWork` stands a
workstation on an office desk; both are render-only by contract, so `AreaGame.initSpawnPoints` could
not see either and documents spawned through a basin and through a monitor. `FacilityClues.prune`
drops those cells from the area's own list on entry — a prune and not a re-derivation, because the
list is already a persisted array and both predicates are pure functions of the same saved grid.
**Live: 15 spots dropped against 22 sinks and 10 workstations**, and the generator now keeps
`TABLE_CLEAR_MIN` 3 bench cells per room bare (corners excluded — a decoration is forced onto those
precisely so a clue's activation cross cannot reach through the wall).

**PACK-24 AT 6x4x170 AND NOT A HALF-EMPTY PACK64.** The clue documents were the last family in the
compound drawn straight off `entities64`, i.e. 64 px over a 2.43-unit quad = 26 texels per unit. 24
subjects were wanted; 24 of a pack64's 64 cells would have left five eighths of the canvas unpainted
AND cut each object to 128 px, where 6x4 spends the whole 1024 and lands **170 px cells = 70 texels
per unit on the sprite route, against pack64's 52.7** (the pack36 band `3d-textures.md` measures as
the floor for a billboard). `tools/pack16.py --cols 6 --rows 4 --cell 170 --valign center`, seams
found at x 167/360/507/689/828 and y 270/490/698. `tools/atlaspaste.py` took `--cols`/`--cell` and
baked the 24 cells back into atlas rows 17 and 19, so the 2D view and the inventory still draw the
same object; `Const.CLUE_HD` is a sibling table to `FACILITY_DECO_HD` rather than more rows on it,
because `DECO_PACK_CELL` is inline at 256. The deal drops from 48 looks to 24: rows 18 and 20 hold the
old 2D-era art and mixing two families of art in one room is worse than fewer looks. **NO `sat` AND NO
`cells` CAP on this one sheet, deliberately** — every other pack here is dressing and takes 0.5, where
a clue is a story object the player has to notice on a bench.

**THREE OF THE 24 CLUE CELLS CAME BACK IN PERSPECTIVE AND ARE RETIRED BY REORDERING, not regenerated.**
The prompt said "ISOLATED CUT-OUT SEEN FROM DIRECTLY OVERHEAD, looking straight down at it" and 21
subjects honoured it; the three that did not are **exactly the subjects whose READ depends on their own
thickness** — a fanfold concertina, a photostat on a pile, a stack of three books — which an image
model draws by showing you the side of them. A pack cell's coordinates come from its INDEX in
`Const.CLUE_HD`, so a cell cannot be deleted from that table: the three are mapped to the TAIL frames
of their own atlas row instead, the good cells behind them shift down to close the gap, and the deal
stops short (`CHEM_LABS_DOCUMENTS` 12 → 10, `CHEM_LABS_BOOKS` 12 → 11). Verified from the live
registry: the 21 dealt frames resolve to cells `0-7,10,11` and `12-14,16-23`, **no retired cell, no
duplicate, no −1**. An `edit_image` pass over three cells was rejected for the drum livery's reason one
step up the pipeline — a model re-renders the whole canvas, so fixing 3 cells risks the 21 good ones.
**If a packed sheet ever needs a top-down subject with real depth, name the depth in the prompt.**

**A PLUG GOES ON ITS SOCKET, AND IT WAS HUNG ON THE CABLE'S EXIT POINT INSTEAD.** `plug` centred its
quad on `anchor(m, p, s)` — the one point in this file a cable leaves a mount from, which is
deliberately slid `SOCK_W * SOCK_LEAD` = **0.35** along the wall so the ribbon's CUT END is buried
well inside the plate's art. As a plug position that is simply the wrong point: the plate's half-width
is **0.7** and the plug's is `PLUG_W / 2` = **0.375**, so the body sat from 0.025 short of the plate's
centre to 0.025 PAST its far edge — covering exactly the far HALF of the socket and hanging the rest on
bare tile, which is how it was reported. Centred now (`anchor(m, p, 0)`), and the lead still leaves
from the offset point, which is **inside** the plug's own half-width, so the cable comes out from under
the plug body rather than out of thin air. The world basis still keys off `s`, so the gland collar goes
on turning to follow the run.

**AND THE TOWER STOOD AGAINST THE MONITOR.** `WORK_TOWER_OFF` was 1.25, which is
`WORK_SCREEN_W / 2 + WORK_TOWER_W / 2` **to the millimetre** — two slabs sharing a full-height edge
read as one object with a step in it, not as two machines. **1.5**, so 0.25 of worktop shows between
them; the tower's outer face lands 1.9 from the screen's centre, inside the cell's own 2.0 half-width,
and two towers on adjacent desks still clear each other by 0.2 (measured on this compound's 41/42 pair
at row 25). Nothing else moves — the LEDs and the lead are already taken off `WorkSpot.tx/tz`.

**A DROP NEVER WALKED THE CELLS BETWEEN ITS TWO ENDS, AND THE WIDENED SOCKET WALK MADE THAT MATTER.**
`drops` joins a machine's lid straight to its socket's plate — two anchors, one ribbon, no path — so
unlike `joins` and `run` it asks nothing of the ground in between. That was safe while the walk reached
ONE cell each way, because the cell in front of a doorway is already rejected (`FacilityPlacard.hangs`
wants the wall line to carry on past its own cell). At TWO it is not: the plate lands on good masonry
on the far side of a door and the cable is drawn across the open threshold — reported from the game
standing next to one. `walled` now tests unbroken `isSolidWall` from the machine's cell to the
candidate, at the point the socket is CHOSEN rather than in `drops`: a machine whose only legal plate
is over a doorway is a machine with no plate, and the walk moves to its next hand. **Measured on this
compound, 28 machines and racks standing against a wall: 22 could take a plate, 15 once door hops are
refused — i.e. SEVEN of the widened walk's wins were hops over a threshold.**

**AND THE SEVEN COME BACK, BECAUSE A BENCH IS NOT SOMETHING STANDING AGAINST A WALL.** `bare` excluded
`m.table`, which was this predicate reading its own comment too broadly: the exclusion is about
FITTINGS — a plate spans 0.25 to 0.95 and a cabinet or a rack is bolted TO the masonry, so it stands
through the plate whatever its height — and a bench touches no wall at all. It stands on its own cell a
clear unit off the slab face, the very fact `joins` has always used to let a run past one. So the strip
behind a bench is bare masonry, which is where a socket goes in a real laboratory: the plate's top
lands at `SOCK_Y + SOCK_W / 2` = **1.55** under a `BENCH_H` **2.0** worktop, 0.12 (`MOUNT_PROUD`) off
the wall with the bench body a unit further out. `run` takes the same widening as a two-question split
(`passes` vs `open`): **standing** on a cell still needs every clause of `open` — a unit on a bench cell
would be a cabinet standing in a worktop — while a lead may **pass** one. The hatch stays a hatch in
both. **Live: 22 of 28 machines fed and all 22 `used` (15 with bench cells still excluded), mounts 56 →
69, runs 22 → 35, units 5 → 7, and 0 of the 22 drops crosses a door cell.** Unit reach went 12 → 20
mounts, most of it latent — the built count is held down by `used` and `clearOf`, not by the walk.

**VERDICT: landed.** Live on the shipped compound: 25 of 35 racks and machines wired (from 11), `work`
10, 15 clue spots pruned, 12 office decals none of them off a desk, mirrors reading as the brightest
thing in the washroom, `sprites.tex('entities', 0, 17)` coming back a **170 px** canvas, **0 console
errors**. The T and its junction are verified on 100 synthetic rooms and on a stamped `demo()` model
rather than in the frame, because a partition is written at GENERATION time and the shipped save's
washroom keeps the single line it was built with — the first newly generated compound is where it
shows. This file is at the ~2600-line cap: roll it before the next entry.

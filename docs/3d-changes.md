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

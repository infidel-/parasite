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

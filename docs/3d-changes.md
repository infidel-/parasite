# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. When this file reaches ~2600
lines, `git mv` it to `3d-changes-<YYYY-MM>.md` and start a fresh one.

Older entries live in [`3d-changes-2026-09.md`](3d-changes-2026-09.md) (rolled at 2634 lines) and
`3d-changes-2026-08c.md` and its predecessors.

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

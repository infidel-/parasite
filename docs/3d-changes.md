# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-09b.md` and its predecessors.

## `unwrap` GOES DEGENERATE ON A CURVED FACE, and the poly probe found it (2026-09-13)

Reported from the game by clicking three faces with `P` and pasting the reports back. All three came
back with **three UVs landing on two points** — a zero-area UV triangle spanning the plastic rect's
full diagonal, i.e. the band smeared across the face:

```
face #32    local 0.521,0.173,0.01     uv  0.03,0.52 | 0.03,0.52 | 0.97,0.73
face #1302  local 0.341,1.05,-0.261    uv  0.97,0.73 | 0.97,0.73 | 0.03,0.52
face #1247  local -0.341,1.114,-0.234  uv  0.97,0.73 | 0.03,0.52 | 0.03,0.52
```

A wheel and the two armrests — **exactly the pieces that stopped being boxes in the previous pass.**

**THIS IS THE BENCH SLATS' TRAP IN ITS OTHER FORM.** `unwrap` maps a face over its own bounding box
in the two axes it measures WIDEST. On an axis-aligned box that guess is unambiguous and it has
served every prop here. On a CURVED piece it is not merely wrong, it is **degenerate**: a face on a
bar or a wheel can project to a LINE in the two axes the guess picks, and then every vertex lands on
one corner of the rect or the other. The bench found the wrong-90°-rotation half of this; this is the
zero-area half, and it only appears once a prop has faces that are not axis-aligned.

Three fixes, by what the piece is:

- **A lathe has `lathe_uv`** — u once around from the seam, v up the piece. Wheels and the hub.
- **A swept bar has nothing** (its rings share no axis), so it takes a rect **collapsed to one
  texel**, which no projection can degenerate. The band's pebble grain is sub-texel on a
  0.055-radius bar at this camera; it was never carrying anything the flat colour does not.
- **A pad takes `flat_uv` over its OWN two axes.** `lathe_uv` was tried here first and is wrong for a
  different reason: it runs u once around the whole perimeter, which **compressed the weave into a
  coarse mesh screen**. A pad's art is flat art on a flat face.

**The check is now a line in `propstat`, i.e. part of the acceptance gate**: count triangles whose UV
triangle has zero area, and report the ones spanning more than two texels. A one-texel rect is
degenerate *on purpose* — it is how a flat colour is stated here — so the area test alone over-reports
wildly and the bracketed count is printed only as context. Swept across every hand-modelled prop:
chair 14 zero-area / **0 smears**, bin 32 / 0, bench 136 / 0, cone 24 / 0, reel 30 / 0, fence 0 / 0,
basin, bookcase, cabinet, machine, drum and gas rack 0 / 0 — and it caught **8 real smears on the WC
pan's flush plate**, whose side faces are constant in x or y under the `(x, y)` map its top face
needs. Same fix: one texel for every face but the one the camera looks down on. `facility/desk-plant`
reports 144, spanning ≤3 texels on leaf stems, which is the threshold being tight rather than a fault
worth chasing.

**AND THE CHAIR STOOD IN THE WALKWAY, BECAUSE `CHAIR_OUT` WAS MEASURED OFF THE WRONG THING.**
Reported as the chair intersecting the player. `FacilityWork.chairs` placed it at `CELL/2 +
CHAIR_OUT` from the desk cell's centre — i.e. off the **CELL EDGE** — and an office desk does not
reach its cell edge: `DESK_D` is **2.6** in a 4.0 cell, thinned on the OPEN side alone so the run
hugs its wall, so the desk's face sits `DESK_D + BENCH_LIP − CELL/2` = **0.8** from the cell centre
and a full **1.2 INSIDE** the edge the placement measured from. Every chair stood 1.2 further out
than the constant said.

**THE FIRST FIX WAS A GUESS AND IT BARELY MOVED.** Cutting `CHAIR_OUT` 1.5 → 0.85 on the reasoning
above closed 0.65 and was reported back as no visible change — correctly, because the remaining gap
was still **1.35, wider than the chair is deep**. Two capture attempts then failed to prove anything
either way: `reload.mjs` lands the camera slightly differently each time, so a before/after pair of
screenshots is not the same view. **Raycasting is what settled it** — cast straight down across the
desk and the chair at 0.1 intervals and read the hit heights: worktop (y 2.0) from x −132.10 to
**−129.15**, bare floor to **−127.80**, then the chair. The gap is a measurement, not an impression.

Fixed at the source: `FacilityWork.chairs` now derives the desk's face from `DESK_D` rather than
carrying a number that can drift from it, and `CHAIR_OUT` **0.87** means what it says — how far the
chair's centre stands off **the desk's own open face**. Re-measured the same way: desk edge −129.15,
chair now starts **−128.90**, so the gap is **0.25 where it was 1.35** and the chair sits 1.77 clear
of the next cell's centre. **The floor on that number is the JITTER, not the chair**: the plan
footprint is 1.231 × 1.294, so a yaw of `CHAIR_YAW_JIT` 0.35 swings the reach along the desk axis to
`0.647·cos(0.35) + 0.616·sin(0.35)` = **0.819** — at 0.87 the front wheels just touch the desk at
full jitter and clear it by 0.22 when square. Every centimetre of yaw play is a centimetre the chair
has to stand back, and the casework is solid to `BENCH_H` 2.0 with no knee-hole to tuck into.

**AND THE CHAIR'S LOWER HALF WAS TOO BRIGHT UNDER AMBIENT**, reported from the game. That was me
chasing the indoor family's ~78 with a per-band lift: the mean was low because the prop gained dark
AREA (swept arms, wheels, a turned hub), not because the object was dark, and lifting the bands to
fix the mean made a black plastic base read as light grey. Pulled back — plastic ×0.517 to luma 52.4,
gunmetal ×0.584 to 59.7 — and the prop now samples **61** rather than 74. That is under the family
number on purpose: **a five-star base IS a dark object**, and the alternative lever (`baseColor`, a
flat scalar on the whole prop) would have taken the teal down with it. Split ratio also fell 3.34 →
2.47, the one-texel rects sharing more vertices than a per-face bbox map ever could.

## The litter bin gets a real hole, and the chair gets curves (2026-09-13)

Both props' second cut, and the same lesson twice: **a shape stated as boxes and flat art measures
well and reads wrong.** Bin **572 tris** (was 504), chair **1,344** (was 1,072), both still
`holes 0, coplanar 0` and both still hitting every locked number.

**THE BIN'S MOUTH WAS PAINTED AND IS NOW A HOLE.** The first cut stated the bin the way its art
does — one green can wearing a wrap with the litter aperture painted on it at u 0.311..0.644, the
mouth landing wherever the seam put that paint. It is the cheapest possible statement of the shape
and it is wrong, because **a painted mouth has no depth and the one thing a litter bin IS, is a
hole.** Rebuilt to the reference the generator itself worked from: a charcoal **hood** over the top
quarter instead of a domed lid the colour of the body, a real **letterbox slot** through that hood's
wall (four of sixteen sectors = 90°, centred on local +Z), and the green ribbed body below.

**THE SLOT GOES THROUGH THE WALL, SO IT IS MISSING FROM BOTH SURFACES.** Cutting it out of the outer
wall alone left the sill and the lintel meeting an inner wall that was still whole — **three faces on
one edge, ten non-manifold edges**, and a mouth sealed shut by a skin you cannot see. With both cut
the eye goes in and lands on the FAR inner wall, which is where the depth comes from. The hood is
built ring by ring rather than with `tube`, because a lathe cannot miss out four sectors of one band;
its winding is not reasoned about at all — **`recalc_face_normals` on a closed shell is one call
against sixteen chances to get a quad backwards.**

**AND THE HOOD'S GREY WAS MEASURED OFF THE REFERENCE, WHICH IS THE ENTRY.** I guessed it at luma
44.5 against the body green's 76.1 — ratio 0.58 — on the reasoning that the reference's hood "is
charcoal". It is not: `trash-bin-src.png` draws the hood at **75.4 against the body's 72.9, ratio
1.035**, the *same value*. It reads as dark because it is **NEUTRAL beside a green**, not because it
is darker. The guess cost the prop's sampled level 68 → **48**, against the generated bin's effective
78 (map 138 × `baseColor` 0.30). At the measured ratio it sits at 64 with the slot lining — which is
darker, at the reference's own 0.588 — doing the rest. Both swatches are painted into **the part of
the sheet nothing reads any more**: with the mouth in geometry the body wraps only the lower 60% of
the art, leaving the old painted mouth and the old rim band dead, so a neutral the sheet never had
costs no second file and no second bind. `SEAM` drops 0.7726 → **0.75**: it existed to land the
painted mouth on +Z, and with the mouth in the geometry its only job is to hide itself at the back.

**THE CHAIR: NOTHING ON A TASK CHAIR IS STRAIGHT.** The castors were the worst of it — boxes, on the
argument that a castor is three texels at this camera. True of ONE castor and false of five: the base
is the widest thing on the prop and its rim is the whole of what an overhead camera gets, so **five
square blobs read as a cross and five wheels read as a chair.** A wheel is a lathe lying on its side,
tipped a quarter turn about x so it turns about the TANGENT, with the tyre's crown in its profile.
The arms under them are **swept bars** on a path from hub to wheel (a star base's arms sweep down and
out; a box states neither half), the hub is **turned** (it sits dead centre of the star where the
camera looks straight down, and a square one showed its corners between the arms), the armrests are
**one bent bar** each rather than a pad on a post, and the seat and both back panels are **rounded
lathes** — `roundrect` carrying the plan, the profile rounding the two edges the eye crosses, which
is the WC pan's rim trick one prop over. +272 tris for all of it.

**A POLYGON STANDS ON ITS FLAT, NOT ON ITS RADIUS.** A 10-gon's lowest vertex is `R*cos(18°)` below
centre, so wheels hung at `WHEEL_R` left the whole chair floating **4.2 mm** off the floor — `z_min`
caught it. And the fabric/plastic split now takes its axis as an ARGUMENT: picking those faces by
area fixed the box version and cannot work on a lathe of fifty small quads, so it is by normal
against a given axis — guessing the axis is what upholstered the first backrest's *edges*.

Levels refitted after both rebuilds, because added dark area moves the mean: chair back to **74**
(plastic band ×1.45, gunmetal ×1.20 on top of the earlier per-band fit), bin left at **64** — its
green is untouched and only the new hood and lining moved it, where the generated bin's 78 includes
no real hole at all.

## The WC pan and the office chair: A REBUILD THAT FIXES A PLACEMENT BUG (2026-09-13)

The washroom and the workstation, step 5 of the rebuild order. **692 tris against 4,068** and
**1,072 against 2,930**, both `holes 0, coplanar 0`.

**THE PAN IS BUILT TO A NUMBER THE BAKE MISSED, and that is the whole argument for the fourth route
in one line.** `FacilityStyle.TOILET_D` **1.4** is what `FacilityDeco.toilets` stands the pan off the
cubicle wall by — `back = TOILET_D / 2 + STAND_GAP` — and its own comment says "0.7 m front to back".
The generated mesh is **0.954 deep** at `TOILET_H` 1.5, because `Models.instanced` scales by HEIGHT
alone and nothing ever checked the other axis: **the shipped pan floats 0.22 off the masonry it is
bolted to.** Built to 1.400 exactly, `TOILET_D` stops being nominal. Not a triangle count, a bug.

**The bowl is OPEN and that is the point** — the camera pitches 51° down, so what it sees of a WC is
the ring and the hole inside it, `roof-ac`'s fan-guard argument indoors. ONE `tube` states it:
`buildlib.tube`'s vessel rule runs the profile out to the rim, over the seat and back DOWN the inside
to the bowl floor, so pan, seat ring and bowl are one closed surface with **no ring to cap and no
hole to leave**. Two fits behind it: the `roundrect` corner radius at 0.55 of the half-width came back
a rounded RECTANGLE (a modern square pan), **0.9** is what makes it an oval at forty tiles; and the
flush plate is what MEASURES H, so the cistern lid drops by what the plate stands proud, or the prop
is 1.521 tall and `TOILET_H` is the number that scales everything else. **A white fixture takes a
white arris** — the chamfer strips are one texel of PORCELAIN, not the dark texel the bench uses,
because a pan outlined in black reads as a decal.

**THE CHAIR IS THE CLOSEST CALL OF THE ELEVEN AND THE GAME ARGUES THE OTHER SIDE.** `CHAIR_H`'s own
comment says the chair is the case FOR a mesh generator — "a real irregular silhouette (a shaped
back, arms, a five-star base on castors)". Right about the back, wrong about the base it names first:
**five arms at 72° is a loop index**, not a symmetry a generator has to find in a bake. And the bake
was a REJECT anyway (9 components at 61.8%, split 2.36×), so the silhouette it was supposed to buy
never arrived. **THE BACK IS SPLIT** because `CHAIR_H` 2.1 is 1.05 m to the top over a seat at 0.425
m: 0.6 m of backrest is geometrically right and, as one panel, reads as a **throne**. A lumbar panel,
a gap and a headrest is what a task chair looks like at that height, and the gap does the work.

**THE MATERIAL SPLIT DOES THE JOB A UV SPLIT WOULD** — the bench's lesson taken cheaply. Seat and
back panels wear FABRIC on their two BIGGEST faces and PLASTIC on the other four, which is truer to
the object (fabric really does stop at the moulded shell) and skips a three-way `flat_uv`. Choosing
those faces by NORMAL is the trap: it worked on the seat and silently upholstered the backrest's top
and bottom EDGES, because a raked panel's big faces are its ±y pair. **Area is the property that
means "the face a person meets", at any angle.**

**A PIECE IS COLLECTED BY IDENTITY, NEVER BY INDEX SLICE.** `bm.verts[n0:]` after an
`ensure_lookup_table` looks like "the piece I just built" and is not — `bmesh.ops.bevel` reallocates
and REORDERS the vert table. The slice came back holding part of the headrest, a second rotation was
applied to it, and the chair measured **3.510 against CHAIR_H 2.1** and 0.67 too deep with no error
raised anywhere: the `measure` print was the only thing that caught it. `[v for v in bm.verts if v
not in pre]` is the fix. **The bench's script had the same latent slice** and happened to survive it;
fixed there too, rebuild byte-identical at 1,660 tris and every locked number unchanged.

**`check` found two more numbers.** An arm of half-width 0.06 is clear of its 72° neighbour only
outside `r = 0.06 / tan(36°)` = 0.083 — started at 0.05, the five arms overlapped **each other** near
the hub and put five top faces on one plane, so `ARM_IN` 0.11. And `BACK_W` 0.58 rather than 0.62,
because the lumbar panel's foot sits INSIDE the seat pad (that is the join) and at 0.62 its ±x faces
ran 0.01 from the pad's own — a back narrower than its seat is also simply what a task chair is.

**ONE 1152×576 PACK2, CROPPED TO TWO NATIVE 512s.** A 2×2 would have wasted half the image on two
props; 2:1 at the pixel floor gives each a 576 cell for **$0.026**, cheaper than one 1k square.
Bands at v 0.497 and 0.743 on both halves: porcelain / charcoal seat / brushed steel, and teal
fabric / black plastic / gunmetal.

**AND THE CHAIR'S LEVEL IS PER-BAND, WHICH IS NEW.** `sheetlevel.py` scales a whole file, right when
a sheet is one object's art and wrong when it is a SWATCH CHART. The chair's teal already sat at
luma 75 where an indoor prop wants to be, while its black plastic sat at 37 — one factor fixing the
mean either leaves the plastic black or takes the fabric to a **157-chroma scream**. Per-band
(plastic ×2.55, gunmetal ×1.25, fabric untouched) still holds every ratio inside the band it touches,
which is all the linear rule protects. Sampled **72**, against the generated chair's `baseColor` 0.45
landing it ~74. The pan took a whole-sheet ×0.227 then ×0.844 to sampled **94** — the hand-made
basin's number exactly, and two white fixtures in one washroom have to agree.

**A LOGGED USER VERDICT ALMOST GOT OVERTURNED HERE.** The generated chair's own `models.json` note
records that its first teal was "reported back from the game as a chair that does not belong in the
room" and was cut from sampled chroma 37.4 to 11.7. That history was not in front of me when the
palette question was asked, and "push the teal" was answered against the *shipped* 11.7. The new
fabric is drawn at chroma 100 in its own band but the prop samples at **atlas 49.5** — between the
two, which is where it should be, and checked in game at the real camera before it shipped.

## The park bench: A BENCH IS ONE CURVE, and MAP BEFORE YOU CHAMFER (2026-09-13)

Last of the four kerbside props. **1,660 tris against the generated bench's 3,650**, measured
1.700 x 3.5568 x 2.340, `holes 0, coplanar 0`. Three numbers are locked and the mesh hits all three:
**aspect 1.5200** (`PARK_BENCH_H` 2.34 is fitted to it, and `Models.instanced` scales by height
alone), **3.557 long by 1.700 deep** (`BIN_SIDE` 1.45 / `BIN_BACK` 1.42 are fitted against those, so
a wrong depth walks the litter bin into the seat), and **length on local Z facing local +X**, which
is what `FacilityGround.facing`'s −π/2 exists for. Verified in game: the seat faces the path and the
bin still sits clear at the back corner.

It is the railing's argument one prop over — **a bench is SLATS, and a slat is a rhythm**. The
generated one reached 15 components at 35.3% and split **2.73x**, the worst-conditioned of the four,
and its whole regeneration story was about getting the gaps between the slats to come back as real
openings at all (the first bake filled them in: a grey subject on a grey backdrop gives a generator
nothing to segment holes against). Stated as boxes there is nothing to segment — **the gaps ARE
gaps**. Five seat slats and four back slats, the count that reference asked for in as many words.

**THE GRAIN HAS TO RUN ALONG THE SLAT, which rules `unwrap` out.** Its widest-two guess puts u on a
slat's SHORT axis and lays the art's horizontal grain ACROSS the slat. `flat_uv` with u forced onto
the length fixes it. Every mesh slat wears ONE band of the art (v 0.270..0.355, clear of the gaps the
sheet paints at 0.250 and 0.375) because they are the same slat — picking a band per slat only risks
landing one on a painted gap.

**AND A SLAT HAS THREE KINDS OF FACE, NOT ONE — one `flat_uv` over all six is not enough.** With v on
X for every face the map is right only for the two the sitter meets: on the long EDGES x is constant,
so it collapsed to a single texel ROW stretched down the face, and on the ENDS y is constant, so it
collapsed to a single COLUMN. Both read as fine stripes running the **wrong way round the arris** —
grain crossing the timber, which is not a thing wood does, and the first thing anyone notices about
the prop after the silhouette. Now split by face normal: ±z unchanged; **±x keeps u on the length and
takes v from the THICKNESS**, over a v-band of the art scaled by `SLAT_T / w` so a texel is the same
size on the edge as on the face, and the grain turns the corner and keeps going; **±y, the sawn ends,
take a flat two-texel patch** (`R_SLAT_END`, the bin lid's trick). End grain is the one place the art
cannot be turned to help — a cut end shows rings and pores, so whichever way stripes run there they
are wrong, and at 0.16 x 0.10 plain timber is exactly what a real end reads as.

**MAP FIRST, THEN CHAMFER, and the order is forced:** `bmesh.ops.bevel` REPLACES the faces it bevels,
so touching them afterwards raises `BMesh data of type BMFace has been removed`. It is also the
correct order — `chamfer` collects its edges *before* bevelling, and `flat_uv` is a LINEAR map over
explicit ranges, so the inset corners the bevel leaves interpolate to exactly the UVs they should
have. The new strips are re-tagged by `chamfer` and mapped by `unwrap`, so nothing carries a smear.

**THE FIRST CUT SHIPPED A CRATE AND THAT IS THE ENTRY.** It stood the back dead vertical over a flat
seat on three straight boxes per end, hit every locked number, measured `holes 0, coplanar 0` at
1,620 tris — and read **worse than the bake it replaced**, which is the only comparison that counts.
A generator carries a curve for free; boxes do not, and a 90-degree back is the one thing no amount
of slat rhythm survives. **A bench is ONE PROFILE, not a seat with a back bolted on.** The nine slats
are now placed by ARC LENGTH along a single curve whose tangent turns **-6 degrees at the seat front
(a dished seat), through 10 at the seat rear, to 31 degrees off vertical at the foot of the back and
6 at its top** — a lumbar S. **The curve costs ZERO triangles**: each slat is still one box, pitched
to the tangent where it sits, which is a rotation about Y and the one `buildlib.place` cannot state
(it pitches about X). The +40 tris are the frame: three straight boxes per end became **two SWEPT
BARS**, 8-sided and smooth-shaded, which is the only genuinely round thing on the prop.

**THE BAR MUST CLEAR THE TIMBER, AND THAT IS A FIT.** It rides at a constant offset along the
profile's NORMAL, which is what keeps it tangent to the slats the whole way round — but the first
build put it **0.075 behind a 0.10-thick slat with a 0.065 radius**, i.e. buried 40 mm in the wood,
and what that reads as in game is the slats disappearing INTO the frame instead of sitting on it.
Exactly tangent is `SLAT_T/2 + BAR_R`; shipped at **BAR_OFF 0.100 against a tangent 0.105**, 5 mm of
bite, which hides the contact behind the slat's own back face and leaves no hairline gap where the
curve falls away under a straight slat (the sag over half a back slat is 2.5 mm at that radius).
**BAR_R came down 0.065 → 0.055 to pay for it**, because the offset costs depth at the back of the
rake and there was nothing spare:

**DEPTH IS THE BINDING CONSTRAINT AND IT IS TIGHT.** A raked back travels backwards as it climbs, and
1.700 has to hold the seat run, the rake AND the bar's own radius. The shipped profile measures
**1.684 wide — 16 mm spare in the entire prop**, and the seat run had to come down from 1.45 to 1.008
to buy the rake. The front foot and the top rail are placed at ±(DEPTH/2 − BAR_R) *by hand* so the
measured depth is 1.700 by construction; the curve is centred between them by a build-time span scan
with an `assert` behind it, which is the check for the whole arc — rake harder and it fails loudly.

**`sweep` SQUARES EACH RING TO THE DIRECTION OF TRAVEL, so a leaning end lands a TILTED CAP.** The
rear leg leans 7.5 degrees at its foot and dug **8 mm under the floor**; the top rail put the mesh
**11 mm over H**, which is the aspect lock broken by a cap. Both feet and the rail now end on a short
vertical stub and `z_min` is 0.0 with `h` exactly 2.340. Also: the slats, not the frame, now measure
the 3.557 — a swept bar is 0.13 thick and would read as the end of the bench, so the slats run the
full length and the frames stand inside them.

**`check` EARNED ITS KEEP ON THE WAY: eight exactly coplanar pairs at gap 0.** In the straight
version all three boxes of an end frame shared one Y band, so the seat bearer's ±Y faces landed on
the SAME PLANE as the stile's and the leg's and overlapped where the boxes crossed — the server
rack's own logged z-fight in another shape, and the first thing the new separating-axis test caught
that was real. Moot in the shipped mesh (the boxes are gone), but it is what the test is for.

**AND NO, THE BAKE COULD NOT HAVE BEEN CLEANED UP INSTEAD.** Asked directly, and `propstat` answers
it: the generated bench is **15 components at 35.3% with split 2.73x**, which is the definition of
UNDECIMATABLE in this pipeline. Every slat is its own shell, and quadric decimation eats thin plates
first — it takes the slats before it takes the blocky ends, so the rhythm that IS the prop is the
first thing to go. The split ratio says the UV islands are already torn 2.7 ways per vertex, so
fewer triangles buys *worse* texels/tri, not better. "Fix the issues" on a 15-shell blob cloud means
welding it into one surface and re-cutting its UVs by hand, which is modelling it — at which point
the script is cheaper, holds the locked numbers by construction, and wears the game's own atlas.

**Level: linear x0.60, atlas luma 74.3 -> 57.4**, R:G 1.054 -> 1.056 so the timber-to-steel ratio is
untouched. 74 was well over the 46-52 outdoor family (the drum and gas rack sit at 66) and read as
the brightest thing in the park; the generated bench it replaces shipped at chroma **8**, i.e. the
timber and the steel had merged into one grey. 20.1 keeps them apart without shouting.

## The park railing: the one prop whose HEIGHT IS ITS WIDTH (2026-09-13)

Fourth kerbside prop and the only one with a hard geometric contract. `FacilityStyle.FENCE_H` is not
a chosen number, it is `CityConfig.CELL / FENCE_ASPECT` **2.83**, and `Models.instanced` scales by
HEIGHT alone — so a segment draws exactly one cell wide **only if the mesh's own width/height is
exactly that aspect**. Wrong by a percent and every run round every park gaps or overlaps at each
cell boundary. Built at LEN 4.0 by LEN / 2.83: measured **4.000 x 0.150 x 1.4134, `widest/height`
2.83**, so the batch's scale is 1 and neither `FENCE_H` nor the `CLIMB_ARC` 0.8 fitted against it
moves. **564 tris against the generated railing's 5,056**, `holes 0, coplanar 0`.

**WHAT EARNS IT A MESH IS THE OPPOSITE OF WHAT EARNED THE CONE ONE.** A railing is carried by
RHYTHM — not by silhouette, not by surface. The balusters ARE the object, and a mesh generator spent
5,056 triangles on them (4 components at 86.3%, split 2.65x, UNDECIMATABLE) to arrive at a blur,
where stating them as eleven boxes costs a tenth of that and comes out crisp. The art correspondingly
does almost nothing: one plain 16-texel swatch off `fence-sheet.png`, **shared with the cable reel**
— two props wanting the same material is the one case where sharing a sheet file is right, against
the per-prop rule the bin's entry sets.

**THE FLAT SQUARE ENDS ARE A CONTRACT, NOT A STYLE CALL.** Two segments abut at a cell boundary, so
A's +x post face and B's -x post face land on ONE PLANE; flat and square they meet invisibly and
FrontSide culls whichever faces away, the normals being opposed. A finial, a rounded cap or any
overhang shows the join at every boundary in the park. Verified by rendering two segments one CELL
apart before wiring anything: no gap, and the baluster pitch **0.308** is within a hair of the 0.30
two abutting posts make, so the rhythm carries across the join instead of stuttering at it. Confirmed
again in game on a real run of five plus a corner — continuous, and `endCut`'s shortening behaves.

**No chamfer on the balusters** — 0.06 across, an edge break there is under a texel at any camera
this game has, and it would double the triangle count of the part that is already eleven boxes. Posts
and rails get one (EDGE 0.012). `propstat` REJECTs it at 15 components / 17.9% and calls it
UNDECIMATABLE at 3.21x: fifteen components is fifteen boxes, and both lines are TRELLIS gates reading
a hand-made assembly — the rack's own 9-at-12.5% reading.

## The lot's cone and reel: a reel is ONE lathe, and a level fit must be LINEAR (2026-09-13)

Second and third kerbside props. **Cone 360 tris against the generated 4,798; reel 676 against
4,960.** Both `holes 0, coplanar 0`, both built at world size so `LOT_CONE_H` 1.5 and `LOT_REEL_H`
2.4 scale them by 1. Dropped junk takes a free yaw, so neither has an authored front and no constant
is fitted to their aspect. The **tyre stack stays generated**: it is the only glb in the compound
that PASSES its own gate (1 component / 100%), and three touching toroids with real holes is a
silhouette a lathe would have to fake.

**A CABLE REEL IS ONE LATHE, AND THE GATE ITSELF PROVES IT.** It *looks* like an assembly — two
flanges, a barrel, a hub each end — and the generated one came back as **6 components at 44.5%,
REJECT**, trying to be exactly that. Stated as a single (radius, z) table turned once, it comes back
**1 component at 100%, the first "ok" of the whole rebuild**. The profile runs out along the bottom
face, over the rim, in to the barrel, along it and out to the top flange, CCW throughout. It also
**stands axis-UP**, which is read off the old glb rather than chosen: bbox 0.999 x 0.901 x 0.999 —
two EQUAL horizontal extents and a shorter height — is a reel resting on a flange FACE. The first
build laid it on its rims and it read as a dumbbell. `REEL_R` 1.33 against 2.4 reproduces the old
aspect 1.109 to three places.

**A FLAT ANNULUS TAKES `disc_uv`, NEVER `lathe_uv`** — the latter puts the seam on a radius and
converges every wedge on the axis, which is the bin's lid wedge in another shape. So the reel's
bands are mapped separately: flats radially, turned surfaces by angle on one continuous v, and only
the turned ones shaded smooth. The top flange is what this camera looks at and was a featureless
2.66-wide disc, so it gained a stiffening rib and a raised hub — two rings, +80 tris.

**THE FINDING: A GAMMA IS THE WRONG TOOL FOR A LEVEL FIT ON A SATURATED COLOUR.** The cone came off
the gen at sampled luma **88** against the old prop's effective ~49, so it wanted darkening. A gamma
of 1.49 did that — and it is per-channel and concave, so it dragged the low channel down far harder
than the high one and took the cone's 222/72/4 orange to a **RED**, visibly a different hue from the
prop it replaces, seen side by side in game. Same mechanism `lift` is already logged for on the
hazard bands. **A multiply in LINEAR light** scales all three channels by one factor, so every ratio
between them — hue and saturation — is untouched and only the level moves: x0.47 put it on **59.3**
with R:G 0.472 -> **0.458**. This is the authored-sheet form of the standing "flat scalar, never
per-channel" rule, and the bin's own fit was redone the same way.

**`buildlib.check` grew a real overlap test, and this prop is why.** The reel reported **136 coplanar
pairs at gap 0** — every one a pair of wedges two to four sectors apart in the SAME flat annulus,
whose axis-aligned BOUNDING BOXES overlap while the wedges never touch. Adjacent wedges were already
skipped for sharing a vert; these are the ones that do not. `_overlaps` is a separating-axis test on
the two mapped axes now, with the cheap box test still in front of it. The danger was never the
noise: a real fault would have been invisible inside 136 false ones. It is strictly more
conservative, so every prop that read 0 before still does. `buildlib.selfcheck()` is the runnable
check behind it.

## The litter bin, and a pack4 is a GENERATION not a FILE (2026-09-13)

First of the kerbside props off the Blender route, and the widest-reaching prop in the compound: one
instanced batch serves the park (one bin per bench), the corridor dead ends and every `FIT_BIN`
fitting, so one mesh is three populations. **504 tris against the generated bin's 4,765**, 0.984 x
0.984 x 1.800, z_min 0, `holes 0, coplanar 0`. Built AT world size — aspect 0.547 against the old
0.540, radius 0.492 against the 0.49 that `BIN_SIDE` 1.45 / `BIN_BACK` 1.42 are fitted to, inside
their 0.08 spare — so the batch's scale stays 1 and **not one placement constant moved**.

**A PACK4 IS AN ARGUMENT ABOUT THE GENERATION, NOT ABOUT THE SHIPPED FILE, and this is where the two
come apart.** `drum-sheet.png` ships packed because the three drums share one MESH and differ only by
cell. Bin, bench, fence and cone share nothing and use one cell each, so shipping them packed would
hand every glb a 512 texture it uses a quarter of. They were **generated packed** (one 1k gen, four
cells drawn side by side — the coherence argument, unchanged) and **shipped cropped**, four native
512s. Same bytes, four times the texels. It also bought the level fit below, which a shared file
could not have taken.

**THE LEVEL IS PER PROP AND THE BIN IS THE ONE THAT GOES INDOORS.** 46-52 is a luma family fitted
OUTDOORS against asphalt; the crop came off the gen at **45.7** and read as a black cylinder in a
corridor, which is the generated bin's own logged failure reached from the other end. Measured
sampled luma on the rest of the hand-modelled family: basin **93**, drum **66**, gas rack **66**.
A **linear x2.18 in linear light** put it on **68.6**, chroma 23.8 -> **32.8** (over propstat's >25
line). No `baseColor`, no `lift`, no `sat` — the sheet is authored, so a knob would be a second
correction over a fitted one. Bench and fence never go indoors and keep the outdoor band.
(A gamma was the first answer here and is the wrong tool — see the cone entry above.)

**THE SEAM IS ARITHMETIC, NOT A GUESS.** The wrap PAINTS the aperture (u 0.311..0.644, centre
0.4774) so the mesh has no hole in it, and the game needs that paint on local **+Z** —
`FacilityGround.bins` yaws by `look + PI/2`. `export_yup` sends Blender **-Y** to glTF +Z, i.e.
theta = -pi/2, and `lathe_uv` reads `u = (theta/2pi + 0.5 - seam) % 1`, so the seam landing 0.4774
there is `0.25 - 0.4774` = **0.7726** — which also drops the seam itself at the back, the drum's own
0.75 one notch over.

**Two traps, both mine, both cheap to repeat.** A 0.015 gap under the lid to draw a shadow line left
a **SEE-THROUGH SLOT**: the two discs that close it are edge-on to a horizontal eye, so the
background showed through the bin. Seated on the rim it is covered, the coincident pair is harmless
(FrontSide culls whichever faces away, the dome occludes the other) and the 0.022 overhang draws the
shadow line anyway. And **a dome cannot take a swatch through `lathe_uv`**: u runs once across the
rect and the seam lays the swatch's left edge against its right, so a 16-texel patch with 2 counts of
gradient arrived as a hard line — and on a dome every sector converges at the apex, so it read as a
bright **WEDGE** across the whole lid. `R_LID` is the same green collapsed to ONE TEXEL: no width, no
seam to be across.

Sixteen sides, not the drum's twenty (0.97 across against 1.2, and smooth-shaded sides buy the
silhouette alone). No chamfer — a lathe's arrises ARE its profile. `FacilityStyle.BIN_BLENDER`
switches the pair and the generated bin stays. **No call A/B was available**: the sample area carries
one bin, and an instanced batch's `count` is the CULLED count rewritten per frame by `Models.cull`,
not its placement count — which is why it first read 0 and looked like a wiring fault.

## The detail pass: flat shading was the bug, not the side count (2026-09-13)

Reported on the twelve props of the two entries below: the round ones want curves, the drum's top is
off centre, the tray's texturing is wrong, the plant and the basin want triangles, the boxes want
edge smoothing. All of it is right and **the tri budget was never the constraint** — every number
below is still an order under what the generated glbs these replaced were spending.

| | first pass | now | what it bought |
|---|---|---|---|
| drum x3 | 44 | **636** | a rolled chime each end, two rolling hoops, 20 sides |
| gas rack | 284 | **1,772** | real cylinders: foot, body, domed shoulder, neck, valve |
| mug | 28 | **396** | a HANDLE, a rim, coffee in a recess |
| plant | 56 | **680** | nine cut leaves instead of a cone |
| lamp | 52 | **468** | turned foot, stem, and a shade with a rolled lip |
| tray | 24 | **564** | a tray: base, four walls, a sheaf in it |
| basin | 44 | **860** | a drop-in bowl and a gooseneck tap |
| rack / low | 156 / 96 | **1,404 / 864** | every arris broken |
| cabinet / machine / bookcase | 36 / 36 / 60 | **324 / 324 / 540** | same |

**THE FINDING IS THE FIRST PASS'S OWN ARGUMENT, INVERTED.** "Twelve sides is a measured floor: eight
show their flats and sixteen buys nothing" was sound reasoning off a false premise — `buildlib.finish`
was forcing **every polygon flat**, and flat shading spends every side on the SURFACE, so twelve was
simply where the facets stopped reading. Smooth-shaded, sides buy the **silhouette alone**, which is
cheap: sixteen is round at these diameters and twenty has margin. One deleted line moved every round
prop further than doubling its segment count would have.

**`buildlib` grew the five things that made it possible.** `tube` turns a **(radius, z) profile** —
a drum's hoops, a bottle's shoulder, a pot's rim and a basin's bowl are all a radius that CHANGES, and
`create_cone` cannot state one; it takes any cross-section too (`roundrect`), which is how a drop-in
sink is the same lathe as a barrel. `sweep` carries a ring along a path, which is a mug handle and a
tap's gooseneck. `lathe_uv` and `disc_uv` write UVs **by angle** instead of over a bounding box.
`flat_uv` maps a piece before it is moved. `chamfer` breaks arrises as geometry.

**THE PROFILE RUNS COUNTER-CLOCKWISE ROUND THE SECTION**, which for a can is bottom to top and for a
vessel is out to the rim, over it and back DOWN the inside. Run it the other way and the piece comes
back inside out.

**A PLAIN SWATCH IS A FITTED VALUE, AND BOTH WAYS PAST IT LOOK THE SAME FROM THE INSIDE.** The leaf's
0.014 edge took the face's own crop and every blade had a **pale rim**; corrected to the darkest
uniform patch in the cell (the shadow between two leaves, luma 23) and every blade came back with a
**black outline** drawn round it, reported from the game. The answer is neither end: leaf GREEN at
**82% of the face's own luma** (39/60/39 against 55/73/41), picked as the most uniform patch near
that target, and `LEAF_T` **0.014 → 0.005** with it — 0.014 was 3.3% of a blade's own length, which
is a lot of edge to light however it is coloured. **Fit the swatch to the face it borders, and fix
the geometry that made it visible at the same time.**

**Three mapping bugs, and every one of them was `unwrap`'s bounding-box guess.**

- **The drum's off-centre lid.** `unwrap` lays a cap into the whole of a rect, so the rim landed
  wherever the ART's disc sat in its cell — measured, that disc is 21 px high and 7 px left of centre
  in a 512 cell. `disc_uv` maps radially into the circle the art really occupies.
- **The tray.** `unwrap`'s widest-two-axes rule is right for a TALL box and wrong for a FLAT one: on a
  tray the widest two are x and y, so the paper-stack art went down in PLAN and its horizontal layers
  ran across the flats, where the only face that reads a sheaf is its EDGE.
- **The wrap mirrored round every barrel**, because a side face's widest two axes swap quadrant by
  quadrant. `lathe_uv` gives every vertex its own angle, so the seam is one line.

**A BEVEL MODIFIER WOULD HAVE SMEARED THE ATLAS and that is why `chamfer` is geometry.** The modifier
interpolates each new strip's UVs between the two faces it joins; on a packed sheet a strip between a
face on cell 0 and one on cell 1 sweeps diagonally across the whole image and samples every cell on
the way. The strips here are built before the unwrap and tagged with a plain swatch. **Only the strips
are shaded smooth** — shade the flats too and every large face picks up a corner gradient, because a
bevel's corner normal tilts by the same angle however narrow it is.

**Two faults `buildlib.check` caught that nothing else would have.** `sweep` built each ring's frame
from a fixed up-vector, which flips wherever the path crosses that vector's plane: the two rings
either side of the gooseneck's apex came back mirrored and bridged into **zero-area bowties**. The
frame is parallel-transported now. And a `turned` piece took its v range from its first and last ring
rather than its z EXTENT, so a mug — which goes up to the rim and back down inside — mapped every band
above the last ring past the top of its cell and the rim came back **wearing leaves**.

Verdict: **kept**. Every model `holes 0, coplanar 0`. `tex` stays 512 — the texturing complaints were
all mapping and none of them was resolution, and raising it doubles twelve embedded PNGs.

> The plant's "answer is an alpha cut or a generated glb, **not more triangles**" was wrong. More
> triangles was the answer: nine cut leaves, each a slab wearing one leaf off the art's own cell.

## Four things on the researcher's desk, and the plant is the honest failure (2026-09-13)

> SUPERSEDED IN ITS NUMBERS by "The detail pass: flat shading was the bug, not the side count" — the
> placement, the scale rule and the batch arithmetic stand; every tri count and the plant's verdict
> do not.

New objects rather than a conversion: nothing stood on those desks but the monitor, tower and
keyboard. `models-src/facility/desk_build.py` builds a mug (**28 tris**), a potted plant (**56**), a
lamp (**52**) and a paper tray (**24**), all off one pack4 (`desk-sheet.png`), all `holes 0,
coplanar 0`.

**THE SCALE IS THE KEYBOARD.** `WORK_KEY_W` is 1.5 for a 0.45 m board, about **3.3 units to the
metre**, and every trinket is a real desk object run through that — a mug 0.09 m across, a pot 0.12,
a lamp 0.42 tall, a tray 0.30 wide. Guessing a desk object's size off the CELL instead would have put
a coffee mug the size of a bin on it.

**Placement is a new pure function, `FacilityWork.trinket`, beside `at` and for the same reason** —
two passes need it and neither may run first. It gives a mug on every desk and one of the other three
rolled off the cell, both at the BACK on the hand the tower is not on: the tower takes one half of the
worktop and the keyboard the front of the other, so that strip is what is left. `FacilityWork.pools`
lays a `FacilityDetail.pool` under each off the same table the batches are sized by, and
`FacilityClutter` takes a `WORK_TRINKET_CLEAR` keep-clear off each, so a loose sheet of paperwork and
a mug can no longer land on one another.

**Cost: four batches, one texture.** On the office area measured: 14 mugs, 5 plants, 3 lamps, 6
trays. Four instanced batches is up to four draw calls when a room is in view, which is the price of
four KINDS and not of the count — the alternative was one glb holding all four in a fixed
arrangement, one call, and every desk in the compound dressed identically.

**THE PLANT IS THE WEAK ONE and the note says so rather than hiding it.** Blender is worse at foliage
than TRELLIS, and an opaque leaf mass is a blob where an alpha cut would be a plant. What shipped is
a tapered eight-sided cone wearing a leaf cell: it reads as a shrub in a pot at the game camera and
would not survive a close-up. If it is ever wanted closer the answer is a generated glb or an
alpha-cut sprite, not more triangles.

## The round props go hand-modelled, and here NO DRAW CALL IS AT STAKE (2026-09-13)

> SUPERSEDED IN ITS NUMBERS by "The detail pass: flat shading was the bug, not the side count" — the
> case for the route and the wrap-not-bake argument stand; the tri counts and "twelve sides is a
> measured floor" do not.

The three hazard drums and the four-bottle gas rack already shipped as glbs, generated through
TRELLIS, so both routes are one instanced batch per livery and the call line is flat. What is on
trial is the other two things the fourth route sells.

| | generated | hand-modelled |
|---|---|---|
| drum (x3 liveries) | 1,200 tris | **44** |
| gas rack | 5,710 tris | **284** |

`models-src/facility/drum_build.py` builds all four: a twelve-sided can and four eight-sided bottles
with valve necks of their own in a frame of three rails and two uprights. All four `holes 0,
coplanar 0`. **TWELVE SIDES is a measured floor** — at `DECO_ROUND_D` 1.2 read from eight metres up,
eight show their flats and sixteen costs 24 triangles for a silhouette nothing can tell from twelve.

**THE ART IS A WRAP AND NOT A BAKE, and that is the second half of the case.** Two pack4 drops
(`drum-sheet.png`, `gas-sheet.png`) whose cells are FLAT UNROLLED CYLINDER SKINS: u runs once around
the barrel, v up it, each side band taking its own 1/12 slice with `buildlib.sub`, and the seam
landing on one vertical line put at the back. A livery is then a CELL rather than a per-pixel
transform of somebody else's atlas — which is what the generated rack needed a `baseColor` fit, a
`sat` fit and two rounds of reported-from-the-game correction to reach. Neither entry ships a colour
knob.

**Prompted against `style_prop` and not `style`, deliberately and against the letter of the
surface/object rule.** These are tiling sheets by medium and objects by purpose: the three drums
exist to be told apart by COLOUR, and `style`'s "very dark and muted desaturated palette" clause is
the documented way nine props in this repo shipped grey. The rule's clause is what matters, not its
noun.

**Two more things the route buys, both found here.** The hand-modelled rack's back is at +y by
construction, so glTF's y-up export puts it at +z and `FacilityKit`'s `yaw0` is **0** where the bake
needed `Math.PI` — TRELLIS does not hold orientation across runs and an authored mesh does. And
`buildlib.check` reported **twenty** z-fighting pairs on the first frame, every rail plane carrying
an upright plane on it: welded flush is what a real frame does and what a renderer cannot draw. The
uprights now stand 0.02 proud, stop 0.02 under the head rail and are inset a whole `RAIL_T` at the
ends.

**VERDICT: landed behind `FacilityStyle.DECO_DRUM_BLENDER`, both sets shipping.** The generated four
are untouched, and the palette is the one thing to watch: these are brighter than the fitted bakes
they stand beside, which is the right direction to be wrong in — the same family was once rejected
for going the other way ("there were orange, now it's almost white").

## The last two fittings: the bookcase lands, and the SHELVING IS REFUSED ON TEXEL DENSITY (2026-09-13)

Fourth and fifth of the five families the rack's result put up for conversion, plus the one that
failed the test — and the failure is the entry's reason to exist.

**Bookcase — `deco-bookcase`, 60 tris (2.0213 x 3.360 x 1.290, `holes 0, coplanar 0`).** Four boards
standing proud of the spines (`BOARD_OUT` 0.03), running BETWEEN the stiles at `STILE` 0.06 of the
face — which is both what the art draws and what keeps their ends off the case's own flanks. A shelf
was a painted stripe before: it caught no light and cast nothing, which on a bookcase is the whole
read. A/B on a pinned frame: **quads 136 calls / 2,557,504 tris, glb 134 / 2,557,636 — −2 calls,
+132 tris.**

**Basin — `deco-basin`, 44 tris (4.000 x 2.900 x 2.200, `holes 0, coplanar 0`).** The strongest shape
claim of the set: **a basin is a HOLE**, and the quads laid it on the counter as a flat alpha-cut
quad with a second one standing up for the tap. The lid is inset, pulled to the bowl's own aspect and
dropped 0.34, so the bowl is a real tapered recess with a rim; the tap is two boxes. That retires the
family's ONLY alpha-cut mesh. A/B: **quads 112 / 2,302,728, glb 111 / 2,302,856 — −1 call, +128
tris** — one and not two because `B_BASIN_TOP` is shared with the benches and the partition cope and
does not go empty. **The mirror stays a quad on purpose**: it hangs on the WALL at `MIRROR_Y` 3.4,
not on the unit, and folding it in would have made the mesh 4.4 tall for `Models.instanced` to squash
to `BASIN_H`. The batch is sized by a new `BASIN_MESH_H` — the mesh's own height, so the scale is 1.

Two traps worth keeping. `bmesh.ops.inset_individual`'s `thickness` is **not** a flat per-edge
offset, so the inner rect has to be read back and scaled rather than derived — the first build came
out 2.96 deep on a 2.2 counter. And `buildlib.check` caught the tap's arm sharing four planes with
its column before the game ever saw it; the arm is 0.7 of the column's section and stops under its
head.

**THE SHELVING IS NOT CONVERTED, and the reason is a limit on the whole packed-sheet route.** The
frame spends only two labels, so the prize was one call — but its plates take `cap` at
`DECO_SHELF_TILE` **0.55** over a 2.6 x 1.666 plate, which is **4.7 x 3.0 repeats**. Baked into one
512 cell of a 2x2 sheet that is 108 px per repeat, and at `tex 512` the sheet's cells are 256 px, so
54 px per repeat — against a perforated plate whose holes sit on a 24 px pitch in the source. It
would have moired at every distance. **The pre-tiled cell has a DENSITY BUDGET: cell px / repeats,
against the art's own feature pitch.** It is why the cabinet's 2.86-repeat flank is fine (plain metal
with two rivets) and this is not. A family that tiles a FINE pattern at a period far under its own
size cannot go down this route without a texture bigger than the thing deserves.

## The machine is a glb, ONE mesh at both heights, and it came back cheaper in TRIANGLES too (2026-09-13)

Third fitting down the route. `models-src/facility/machine_build.py` builds `deco-machine` at **36
tris** (2.8 cube, `z_min` 0, `holes 0, coplanar 0`) against the four quads' 8.

**A/B, pinned free-cam frame, both arms in one session after a 4-second settle**
(`FacilityStyle.DECO_MACHINE_GLB`):

| | calls | tris |
|---|---|---|
| four quads | **101** | 56,461 |
| the glb | **99** | 56,437 |

**−2 calls AND −24 triangles**, which is the first arm here to win both, and the reason is worth more
than the numbers: **merged geometry cannot be culled per unit and an instanced batch can.** The quad
build puts all 12 machines of the compound into three buffers, so every one of their 96 triangles is
submitted whenever any part of a buffer is in frustum; the glb's batch culls per instance and this
frame drew **two**. The triangle line in these A/Bs has been reading "+n for the shape" on every
entry so far because the families were small and mostly visible — on a family that is scattered, the
sign flips.

**ONE MESH AT BOTH HEIGHTS, which is the rack's trap the other way up.** `DECO_MACHINE_LOW_SZ` is not
a COUNT of anything: the unit is a cube at either size, `machLights` reads fractions of h and of the
face's own width, and `Models.instanced` scaling by height is therefore exactly right — where for the
rack it was wrong, because `DECO_RACK_LOW_H` says *three chassis*. **Ask what the second size MEANS
before deciding whether it is a second mesh.** Two batches off one path, one program, one warm row.

**What the quads could not state**: the front art is three bands — bolted head panel, louvre panel,
control strip — and the louvre one is drawn RECESSED. Three stacked boxes with the middle pulled back
`GRILLE_IN` 0.035 give it a ledge at each end. **The control strip may not move**: `machLights` stands
five specks `DECO_LED_EPS` 0.03 proud of the front face at `DECO_MACH_LED_V` 0.088 of the height,
inside that strip, so only the middle band goes anywhere. Each box takes the v-slice of the front and
flank cells its own band occupies (`buildlib.sub`), so a three-box stack still lays each image once.

All three cells pack at **1x1**: every face of this family is `pane` or `localCap` at the unit's own
width, i.e. already 0..1. It is the only family here with no repeat to bake.

**VERDICT: landed, flag on.**

## The cabinet is a glb too, and THREE LABELS IN ONE FRAME IS TWO CALLS BACK (2026-09-13)

The rack's finding applied to the second fitting, and the first one whose case is ONLY the draw call.
`models-src/facility/cabinet_build.py` builds `deco-cabinet` at **36 tris** (`1.9611 x 3.432 x
1.225`, `z_min` 0, `holes 0, coplanar 0`) against the four quads' 8.

**A/B, pinned free-cam frame, both arms in one session after a 4-second settle**
(`FacilityStyle.DECO_CABINET_GLB`):

| | calls | tris |
|---|---|---|
| four quads | **151** | 2,003,859 |
| the glb | **149** | 2,003,943 |

**−2 calls and +84 triangles**, on three cabinets compound-wide (24 tris → 108). Two and not one
because the cabinet's three labels are three whole buffers that go empty at once: `pane` front,
`face` flanks, `cap` lid, no other fitting sharing any of them. The rack only won ONE because its
three labels collapse into **two** batches — the tall mesh and the low one. **The arithmetic is
`labels - meshes`, and it is worth knowing before building anything: a family with one texture and
one mesh breaks even at best, which is the booth and the barrier all over again.**

**A cabinet IS the slab the triage says to emit and nothing about its silhouette argues otherwise.**
That is the point of the entry. What it adds, given it is being built anyway, is that the two doors
are LEAVES: one proud box each (`DOOR_OUT` 0.025), so the edges cast a reveal and the plinth band
under them reads as a toe kick instead of paint. Each leaf's front takes the SUB-RECT of the front
cell its own art occupies — `buildlib.sub`, u 0.034-0.490 and 0.510-0.966, v 0.035-0.918, read off
the built image — and the carcass front behind it carries the WHOLE cell, so a sliver showing past a
leaf is still the right pixels in the right place. 24 triangles for both leaves.

**The pre-tiled cells are read off the emitter, one per call it makes.** `pane` is 0..1, so the front
cell is 1x1; `DECO_CABINET_TILE` is `DECO_CABINET_D`, so a flank is `CAB_D / 1.2` x `CAB_H / 1.2` =
1.0 x 2.86 and the lid `CAB_W / 1.2` x 1.0 = 1.635 x 1.0. The front source is **292x511**, which is
`DECO_CABINET_W / DECO_CABINET_H` — `modelsheet.py` stretches it into a square cell and the 0..1 face
puts it back, which is what an aspect-locked `pane` was already doing.

`FacilityDeco.racks` became `fittings`, a table of `{ kind, path, h, on }` rows so the next family is
one row. The rows stay present with the flag off (an empty batch is a count of 0) because
`FacilityArea.EXTRA` has to stay index-aligned with `green`.

**VERDICT: landed, flag on, both answers still ship.**

## The server rack is a glb, and it came back CHEAPER IN CALLS than the quads (2026-09-13)

First of the room fittings down the Blender route, and the first result that contradicts this file's
own standing verdict. `models-src/facility/rack_build.py` builds **two** objects: the full cabinet at
**156 tris** (`1.660 x 3.200 x 1.235`) and the one-tile one at **96** (`1.660 x 1.600 x 1.235`),
`z_min` 0 on both, one primitive each, against the four quads' 8.

**What the quads could not state.** A rack is not a slab: it is **six chassis** in a frame, each set
back behind its own bezel, on a skirted foot under an overhanging lid. Six is not a style count — it
is `DECO_RACK_H / (DECO_RACK_TILE / 3)`, the art holds three chassis per tile, and that lock already
has a bug in its history (2.9 put half a chassis at the lid). The art drew all six and the geometry
contradicted it by painting them on one flat plane.

**THE SKIRT AND THE LID TAKE NO HEIGHT, AND THAT IS LOAD-BEARING.** `FacilityDeco.lights` puts a
rack's status specks at `h * (r + 0.5) / rows` off the same chassis count. The first build spent
0.17 of the height on a base and a lid, which moved every chassis up to **a sixth of its own height**
off its own lights. They stand PROUD instead: total exactly `DECO_RACK_H`, rows exactly
`RACK_TILE / 3`, the LED pass untouched and outside the switch.

**FOUR FAULTS IN THE FIRST BUILDS, all reported from the game or found chasing what was.** Worth the
space because none of them is about this object:

- **A cube has six faces and an emitted fitting has four.** `FacilityDeco.unit` puts out a front, two
  flanks and a lid and NO bottom — `FacilityRoof.box`'s finding that this camera never sees under a
  fitting. An assembly of `create_cube` boxes brings every one of those back, and three pairs landed
  exactly coplanar: carcass bottom against the skirt's **and against the floor plane itself**,
  carcass top against the lid's, three backs together in the masonry. Reported as the top and bottom
  z-fighting.
- **DELETING the buried faces was the wrong fix, and it is the entry's best finding.** It cleared the
  fighting (156 → 130 tris) and left both cabinets **full of holes** — reported next, and correctly.
  A prop is a solid: the parts of it that never face the camera still bound it, and a hole is a fault
  a later pass (a shadow volume, a hull, an outline shell, anything that wants inside from outside)
  pays for. **Keep every face and pull the PLANES apart instead.** The boxes went back to closed and
  the offsets carry the whole job: the carcass gives up `CARC_IN` 0.02 at its head so the lid's top is
  the only face on that plane, and the skirt and lid are pulled `TRIM_IN` 0.05 INSIDE the carcass
  front and back — recessed and hidden rather than flush (which fights the carcass) or proud (which
  lands a hair in front of the chassis bezel over it). 0.05 and not 0.03 because the recess has to
  clear the top CHASSIS too, whose own lid sits 0.009 under the cap's. Floors are exempt and stay
  stacked on z = 0: nothing sees under a fitting. **130 → 156 and 76 → 96 tris**, paid knowingly.
- **So `buildlib.check` now runs on every object before it is exported**, and it is the reusable
  piece: holes (any edge not shared by exactly two faces) and CO-FACING faces closer than `near` 0.01
  with overlapping ground — near-coplanar and not just coplanar, because 0.005 shimmers as readily as
  0. Pairs sharing a vert are skipped (an inset ring is four coplanar faces that tile, not fight) and
  -z is skipped whole. Both racks report `holes 0, coplanar 0`. It caught the chassis/lid pair above
  before the game ever saw it, which is the point: this class of fault is arithmetic, not eyesight.
- **A packed cell cannot wrap, so the REPEAT has to go in the sheet.** `localFace` divides by
  `DECO_RACK_TILE` on both axes, so a flank carries **0.75 across its depth by 2.0 up its height** and
  the lid 1.05 x 0.75. `buildlib.unwrap` maps a cell 0..1 over the whole face, which stretched the
  square flank art **2.67x** — reported as the sides being stretched. Walking u past a cell edge is
  not available (it slides into the neighbouring image), so `tools/modelsheet.py` grew `--repeat`:
  each cell is tiled and cropped to `u x v` repeats BEFORE it is scaled in, values under 1 being a
  crop. Same density as the quads, no geometry and no UV change.
- **The low rack was the tall one squashed.** `DECO_RACK_LOW_H` is `DECO_RACK_TILE` — exactly three
  chassis — and `lights` deals `h / DECO_RACK_TILE * DECO_LED_PER_TILE` rows off that same
  arithmetic, so one mesh at two heights gave **six squashed units under three rows of lights**.
  `Models.instanced` scales by HEIGHT alone and there is no way around that: the low cabinet is a
  second object out of the same script, a second path, material, program and warm row.

**A/B, pinned free-cam frame, both arms measured in ONE session after a 3-second settle**
(`FacilityStyle.DECO_RACK_GLB`, which is a flag and not a deletion — both answers ship):

| | calls | tris |
|---|---|---|
| four quads | **100** | 398,897 |
| the two glbs | **99** | 399,013 |

**−1 call and +116 triangles.** Compound-wide, 5 tall + 12 low: **136 tris → 1,932**. GPU median read
6.36 / 7.60 / 8.39ms across builds and says nothing — the power-state rule. **SETTLE BEFORE
SAMPLING**: the first pass at this compared 473,704 against 473,880, both taken before the roof
reveal had eased out, and the pair only agreed by luck — the same camera reads 75k fewer triangles
once it has.

**WHY IT WINS THE CALL, and this is the transferable part: the per-face texture rule is what the glb
collapses.** `3d-geometry.md` says one texture per FACE, so a rack's front, flanks and lid are three
labels and therefore **three merged meshes and three draw calls** for the compound. The glb wears ONE
material — `tools/modelsheet.py` packs the three BUILT labels (each with its own fitted `lift`
already in the pixels) into `rack-sheet.png` — so 17 racks are **two** instanced batches, one per
height off one path, since `Models.instanced` scales by height alone. The booth and barrier verdicts
above are not contradicted: those were ONE-texture objects where a glb could only add triangles. **The
test this adds is: how many TEXTURES does the emitted version spend?** At three, a glb starts one
call ahead before any shape argument.

No `baseColor`, no `lift`, no `sat` — the art is the game's own and already fitted. `propstat` REJECTs
it at 9 components / 12.5% largest and calls it UNDECIMATABLE at 3.25x split; nine components is nine
boxes and both lines are TRELLIS gates.

**VERDICT: landed, and the flag stays.** `tex 512` puts the front at **113 texels per world unit**
against the ground's 57.

## Five reported faults, and four of them were a QUAD POINTED AT THE WRONG THING (2026-09-13)

One pass over five things seen in the running compound. Four share a shape worth naming: a quad was
in the right place wearing or reaching the wrong thing, and in every case the fix was an argument and
not new geometry. Total cost of the five: **zero new draw calls, zero new programs, one new quad per
workstation.**

**The lead stopped at its plug's rim.** `FacilityCable.anchor` slid every run `SOCK_W * SOCK_LEAD` =
**0.35** along the wall off the plate centre, so the ribbon's cut end landed **0.025 inside** the
plug's own half-width of `PLUG_W / 2 = 0.375` — at the rim, reported as the cable not going into the
plug. The slide exists to hide a cut end inside the drawn art, which is a FITTING's problem: a
junction box has only its own art, a socket has a plug drawn over it and 0.03 proud of the ribbon.
So the slide is now `p.fit`-only and a socket's runs end at the plate centre, under the plug.

**The washroom divider wore its own elevation on its lid.** `FacilityGeom.cap` maps a horizontal face
WORLD-ALIGNED (`u = x/t`, `v = z/t`) and `partition()` passes `PART_TILE = PART_H = 6.0`, which is
right for the four vertical faces (v runs exactly 0..1, skirting on the floor) and wrong for the top.
The **north-south** arm's lid spans z by a whole `CELL`, so **dv = 0.667** — two thirds of a
bottom-up elevation dragged across the wall head, and `facility/wash-partition` carries a dark
skirting band across its bottom 8% and a joint line two thirds up. Those are the reported black bars.
The east-west arm spans `PART_T` (**dv = 0.1**) and lands on one flat band, which is why one axis
showed it and the other did not. The lid now takes `facility/wash-counter-top`, the family's own
top-down art, in the buffer the basin counter's lid already fills — no new art, no new call.

**The glass was flush with the wall it is set into.** A glazed cell's masonry is `GLASS_T` 1.0 inside
a solid wall's `WALL_T` 2.0, so the pane already sat 0.5 behind the neighbouring wall FACE — but the
spandrel above and below an opening is emitted on that same glazing slab, and the panes stood
`WINDOW_EPS` **0.02 proud** of it. From inside a room a window therefore read as painted ON its own
wall. The standoff exists because `WINDOW_OVERLAP` grows the pane past the opening and a coplanar
overlay z-fights; the gap works in either direction, and **inward costs nothing else** — the head and
sill caps already span the slab's full 1.0 cross-section, so pulling the glass back **0.12**
(`WINDOW_INSET`) turns them into a visible soffit and sill with no new geometry. A `WINDOW_HIGH` cell
is not in `thick`'s test, keeps the full 2.0, and takes the same inset off the same code.

**The workstation had a contact pool and it was the wrong SHAPE.** One round `FacilityDetail.deck` of
radius `WORK_R` 1.6 centred on the monitor — the ramp `makeRectGlowGradient` collapses to a circle,
correct for a flask standing alone on a bench and a MAT under three rectangular machines spread
`WORK_TOWER_OFF` 1.5 apart. Now three square `FacilityDetail.pool` quads off each object's own W and
D (0.75x0.5, 0.8x1.5, 1.5x0.6), turned with the props, laid by a new pure `FacilityWork.pools` and
clamped to the worktop by `pooled`. `WORK_R` is deleted; `WORK_CLEAR` 1.05 was always the keep-clear
and is untouched.

**And the fifth is new: a screen that is ON.** A third pattern on the additive LED mesh — `vColor.b`
in 0..1 is a rack square wave, 2..3 a machine chase, **4..5 a SCREEN**: two sines at rates with no
common period summed 60/40, depth **0.12**, so it wobbles and never loops. A rack's blink reads as a
fault light on a monitor and a chase reads as a sequencer. Colour off the art, not taste — the glass
cell of `facility/workstation.png` measures **rgb 45/59/65, 88% of texels in hue 180-210**, so
`WORK_SCREEN_GLOW 0xb6e4f4`. **The level was fitted DOWN 0.35 -> 0.10 and the SHAPE is why**: that
mesh's alpha ramp is a soft round dot, right for a 0.12 speck and an OVAL on a 1.7x1.25 panel, and at
0.35 it read as a white card stuck on the monitor — the booth-glazing failure in `3d-models.md`,
where the fault is uniformity and not brightness. The quad is also pulled inside the glass (0.78/0.72
of the screen against the art's own 0.93/0.875 crop) so the whole ellipse lands on glass. Placing it
needed the shell's 8 degree lean, which lived only in `computer_build.py` — it is now
`WORK_SCREEN_TILT` and that file reads the same number.

**VERDICT: landed.** Live: `work` 14, three batches at 14, `elec.mounts` unchanged, 85 warm programs,
0 console errors. Office frame 93-94 calls, washroom 116-122.

## The workstation is hand-modelled in Blender, third answer to the same object (2026-09-13)

`facility/computer.glb` was GENERATED, came back blocky and was replaced by 22 emitted quads off the
`facility/workstation` sheet; the quads held the proportions and could state no silhouette at all —
five flat faces, a screen with no tilt and no bezel, a keyboard that is a 0.1-tall box. The fourth
route in [`3d-models.md`](3d-models.md) is what this entry opens here: **Blender over MCP, for a brief
that is a NUMBER.** Every dimension is read off `FacilityStyle` and the build is a script,
`models-src/facility/computer_build.py` (blend beside it) — re-run it, never hand-edit the glb.

**Built: 268 / 116 / 44 tris** (monitor / tower / keyboard), measured on the EVALUATED mesh at
`1.700 x 1.775 x 0.509`, `0.800 x 1.750 x 1.500` and `1.500 x 0.099 x 0.600`, `z_min` 0 on all three —
against the generated glb's **1,200 for the set**. What the triangles buy: the screen tilts **8°** back
on a bezel inset 0.075 and pushed 0.02 in, the neck tapers 20%, the tower's front panel is **recessed
0.014** behind a 0.03 bevel, the keyboard is a **wedge** 0.06 → 0.10.

**NO NEW ART.** The UVs land on the game's own built `facility/workstation.png` (cell 0 glass, 1
carcass, 2 tower front, 3 keyboard) and the exporter packs the 512 into each glb, so the sheet is now
consumed at BAKE time and bound by nobody at runtime. No `baseColor`, no `lift`, no `sat`: that sheet
already carries its own fitted `lift 0.853`.

**THE TRAP, AND IT IS THE ART'S NOT THE MAPPING'S: an authored cell is often an OBJECT ON A PLATE.**
`convex_hull` boxes came first and were the easy bug (triangulated faces, each mapped 0..1 over a whole
quadrant, diagonal seams everywhere — fixed with `create_cube`). The real one survived that: measured
per-row std inside the built sheet, cell 3's key field runs **rows 42..182 of 256**, so **29%** of the
cell is bare plastic and the wedge's top wore it as a front third — reported as "it's like it's a
keyboard inside a block". Cell 0 paints its own bezel (glass **9..233 / 9..247**), which the modelled
bezel doubled. Both fixed by cropping the UV to the measured content (`SUB`), never by re-rolling art.
The emitted quads lived with both because a flat slab's painted frame IS its frame.

**Three props and not one**: the tower stands on a hand rolled per desk (`WorkSpot.side`), so a fused
set could stand on one of them only. Cost, A/B in one free-cam office frame, batches visible vs hidden,
interleaved on/off/on: **calls 149 / 146 / 149, tris 2,466,933 / 2,462,697 (+4,236 for 10+10+9 drawn
instances), GPU median 8.19 / 7.79 / 8.28ms.** So **+2 calls** against the quads' single merged mesh and
**+5,376 tris** compound-wide (5,992 against 616 over 14 desks) — which is the shape [`3d-render.md`](
3d-render.md) predicts for a prop area, where the frame is triangle-bound and two instanced draws are
nothing to the CPU. `propstat` REJECTs the monitor on COMPONENTS (3 at 42.9%) and calls all three
UNDECIMATABLE; both gates are TRELLIS gates — three components is a foot, a neck and a shell, and
`tris: -1` is what "authored AT the budget" means.

**VERDICT: landed.** Live on the shipped compound: `work` 14, three batches at 14 placements each,
warm 85 programs, 0 console errors. The leads and the status lights did not move — they still go into
`FacilityCable`'s ribbon and `FacilityDeco`'s additive mesh and still cost no call.

## A hole is deep and water is the end of a profile (2026-09-14)

Two in-game reports on the pair that shipped yesterday. **The WC pan wants a water line with a water
texture.** **The litter bin's mouth "exposes bad polygon work — just flat surface that's not even
black + green parts coming up a little too high and are visible".** Both answers are geometry.

**The pan: the bowl ENDS at the water.** The obvious move is a disc at the water height inside the
lathe, and it is wrong twice — a free plane inside a closed vessel is twenty edges carrying ONE face
each (twenty holes on `buildlib.check`), and it can only sit clear of the porcelain it should meet.
Instead `PROFILE` stops at `WATER_Z` **0.60** and `tube` caps it, so the last ring's cap IS the
surface: no extra face, no hole, an exact meeting — and the prop got **smaller, 692 → 652 tris**,
because nothing below an opaque surface is worth keeping. `WATER_R` **0.180** is 0.75 of the bowl's
opening, so a ring of dry porcelain still shows inside the seat.

The swatch is **64×64 painted into the strip below the steel band**, where the sheet drew two bolt
heads no rect ever reached: mean luma **47.5 against the porcelain band's 108, ratio 0.44**, two
crossed swells, a fine cross-ripple, grain, and one soft off-centre sheen. **At a 51° pitch the sheen
is the only thing that says LIQUID rather than a dark hole.** Square on purpose — `disc_uv` puts x on
u and y on v linearly, so a 512×64 strip would arrive with ripples eight times wider than they are
tall; and it is passed the OVAL's long half-axis (`WATER_R * AY`), not the radius, or v runs past the
patch into the band above.

**The bin: the can is open now.** The lining texel was never the fault — 44.5 against the hood's 75.5
is ratio **0.59**, and `trash-bin-src.png` draws its slot interior at **38.1 against a hood side of
66.5 = 0.57**. The fault was that the body was CAPPED at the collar, which put a horizontal disc
**0.028 under the sill** filling the whole mouth: one plane, one normal, one value — and a +z face
takes more ambient than any wall around it, so the darkest texel on the sheet still rendered LIGHTER
than the charcoal framing it. The collar also stood **0.020 proud of `AP_Z0`**, so a strip of the
body's green ran along the bottom of the hole.

Fixed by carrying the profile OVER the lip and back down a throat to a floor 0.8 m below — the same
vessel rule the pan runs — and dropping `COLLAR_TOP` 1.440 → **1.412**, under the sill. **+96 tris,
572 → 668.** Two things the throat forces: its bands are UV'd separately, because one `lathe_uv` over
the whole profile puts v on z and the throat runs back down through the z the body already used (it
would wear the ribbed green a second time, mirrored, inside the hole); and it takes its OWN texel at
luma **23.4**, 0.31 of the hood, against the mouth's 44.5. The reference's 0.57 is a ratio measured
off art carrying its own ambient, where the game draws a shaft down a closed can with **no baked AO
anywhere on a hand-made prop**. Two values in one hole is what stops it reading as the painted
rectangle this rebuild exists to replace.

**One library fix underneath both.** `buildlib.material` loads the sheet with `check_existing=True`,
so a repainted PNG exports with the pixels the session first loaded and nothing errors —
`make models` hashes the glb and the sig, not the sheet. `tex.image.reload()` after the load.

**VERDICT: landed.** Both `holes 0, coplanar 0`, **0 uv smears**, every locked dimension unchanged
(bin 0.970 × 0.970 × 1.800 aspect 0.539, pan 0.760 × 1.400 × 1.500). Verified in a free-cam frame on
a corridor bin and a cubicle pan: the mouth reads as a black letterbox with no plate and no green in
it, and the water reads as a blue-green oval with its sheen inside the white bowl. The pan's sampled
luma moves 94 → **86** — the water is dark and it is a third of what the camera sees of this prop.

## Seven in-game reports, and the wide one is RENDER-ONLY FURNITURE IS STILL FURNITURE (2026-09-15)

**The washroom divider z-fought the roof.** `PART_H` was `WALL_H`, and `ROOF_Y` **is** `WALL_H`, so
`FacilityDeco.cope` laid the divider's lid exactly on the roof deck's cap — a coplanar pair running
the length of the wall at the one height a 51° camera looks straight down on. `WALL_H - 1.0`. It was
also simply too tall to read as a divider, which is the same fix and was the report's own first half.

**The divider came out + shaped instead of T.** `FacilityDeco.rectOf` picked a partition cell's axis
as "has a neighbour on x", which is right for every cell of a straight run and wrong for the one cell
that matters: the T's junction is the middle of the BAR with the stem arriving on one hand, so it has
ONE x neighbour and TWO in z. Called horizontal, the cell spanned the full CELL in x — reaching a
boundary the stem is not on — and then took BOTH z hands as crossing arms. Four arms out of three
neighbours. **Count the neighbours per axis and take the bigger**; every straight run and every stub
lands exactly where it did.

**A floor unit stood inside a corridor cabinet, and its lead went to a pipe.** `FacilityTables
.cabinets` stands corridor casework without writing a tile, a `deco` or an object — that is the whole
point of it, it is the one thing allowed to stand where the player walks — so `FacilityPaint
.freeFloor` reads those cells as bare lino and `FacilityCable.units` parked a distribution board in
the middle of one. `FacilityCable.fittings` already dodged the casework by claiming its FACES off the
same pure function; `casework(m)` now claims its CELLS, and `open` tests it, which fixes standing, the
lead's path and the loose scatter at once. The other half: `FIT_FEED` listed sheet cell **22, a run of
steel conduit held by saddle clips**. Conduit is CONTAINMENT — a cable inside it does not come out of
the middle — so it is off the list. A tray (23) stays: a cable lying loose in a tray can leave it
anywhere, which is what a tray is.

**The wall under a washroom light well had no grime.** `FacilityGrime` takes `Wall.SOLID` only, for a
reason that holds for a ribbon and not for a well: a ribbon's sill is **0.93** and a band to `GRIME_H`
3.0 would run across the glass, where a well's sill is `WINDOW_HIGH_SILL` **3.87** and the wall under
it is unbroken masonry the whole way. Reported as a clean strip under each opening and a dirty one
between.

**And the light wells had no jambs at all.** `FacilityGeom.thick` reads `Wall.WINDOW`, so a
`WINDOW_HIGH` cell is FULL wall thickness — which means both its neighbours take the equal-thickness
branch of the butt-cap test, emit nothing, and the opening's two sides were open straight through 2
units of masonry. A ribbon never needs this because glazing sits strictly INSIDE the wall that bounds
its run and the flanking cells cap it for free. `jamb` took its two heights and its tile as parameters
and the window loop calls it for `w.high`.

**The basin, four probed faces.** (1) The bowl's skirt started at r 0.94 **below** the counter lid and
flared to 1.25 × 0.775 by the lid plane, so the flange CROSSED the worktop instead of resting on it
and the laminate showed through its own edge; it starts at the flange underside 0.006 clear now, and
the shaft went from 1.07 × 0.62 × **0.78 deep** to 1.12 × 0.72 × **0.07** — at 51° you see
`depth × 0.81` of horizontal into a hole, which was 0.63 against an overhang of 0.155. (2) The
worktop ring is four long thin quads and `buildlib.unwrap` laid a whole cell of laminate over each,
i.e. one art at four densities; `flat_uv` over the counter's own plan reproduces exactly what
`FacilityGeom.cap` lays on a bench. (3) The end panel's column of apron was cropped by eye at 0.15 of
the cell and wanted **0.55** — the cell carries 2.222 repeats across, an end is 2.2 × 1.8 and so wants
1.222 of them. (4) The tap's plain swatch measured mean 91 at **sd 20.0** with texels down at 52, and
`tap`'s gooseneck is a sweep whose every little quad takes the WHOLE patch through `unwrap` — so those
dark texels drew as a black outline round each one. Rescanned the sheet for the most uniform steel on
it: mean 101 at **sd 1.1**. **A plain swatch is a FITTED VALUE and uniformity is the fit.**

**The red drum.** The hand-modelled trio wears a pack4 drop generated against `style_prop`, which
deliberately keeps its subject saturated, and none of the three carried a `sat` key: measured
**sampled 175/50/23, chroma 152.3** — seven times what its own TRELLIS-era predecessor
`facility/drum-rad` shipped at and eleven times `facility/deco-sofa`'s 13.4. `sat: 0.5` as asked:
**152.3 → 70.8**, red channel 175 → 143, luma held at 74.7 by the Rec.709 mix, which is what carried
the "too bright" half of the report. Still the most saturated thing in the compound, and the two
siblings are hotter (bio 196.5, steel 76.5) — recorded, not fixed.

**One thing added rather than fixed: CLUTTER SLOTS.** A worktop is not the only flat surface at hand
height, and a bookcase lid and the lounge table both read as a moulded block with nothing on them.
`FacilityClutter.slots` walks `m.deco` for the two kinds with a usable lid, takes the rect off
`FacilityDeco.rectOf` — the same pure function the electrical service asks — and runs the bench
sampler over it at the fitting's own height. No art, no new mesh, no draw call: the decals go into the
two buffers the benches already merge. **Size the item to the surface**: at `CLUTTER_SZ` 0.8 plus its
variance plus the inset there was no wander left on a 1.2-deep table and the sampler rejected every
roll, so the table shipped bare — `CLUTTER_SLOT_FILL` 0.62 of the lid's shorter side.

**And the desk trinkets.** A mug on EVERY desk at a fixed offset at the desk's own yaw is the rank
this family was added to break: both are rolled now (70/55), both jitter ±0.22 and take a free turn.
The reported bug underneath it — "the plant always stands on the decoration" — is that `trinket` never
tested `m.tableDeco`, and the far spot and a standing icon's own contact circle are both at the back
of the desk, so on a decorated cell they overlapped by construction rather than by luck.

**VERDICT: landed.** `make gen` 4000 seeds zero failures and 20000 seeds zero failures across the two
generator-side changes that rode with this (the lounge's table moved to the wall line, and a named
door lane). Basin rebuilt at 820 tris, `holes 0, coplanar 0`. Live on a fresh compound with WYSIWYG
lighting: the divider stops a clear metre under the deck and reads as a T, the light wells show three
panes in a real reveal with the damp band running unbroken beneath them, the basin's worktop is one
laminate at one density, the sofa and its table stand side by side against the wall with a folder on
the table, and a bookcase carries something on its lid.


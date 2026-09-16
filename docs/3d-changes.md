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

## A slot is one piece's, and a circle could never say so (2026-09-15)

> SUPERSEDES the "CLUTTER SLOTS" and "desk trinkets" halves of the entry above.

Reported twice more off the same desk: a lamp still standing on the desk's other decoration, and a
flat decoration lying under the tower. Both are the same defect and neither is a missing test in the
usual sense — **there was no occupancy model at all**. Four passes dress a worktop and each carried a
PRIVATE list of what to keep off: `FacilityClutter.cell` knew about all of them, `FacilityWork.place`
about the standing sprite alone, `FacilityWork.at` about nothing (fixed offsets, no test), and the
desk's placed clutter item was emitted outright with no test whatsoever.

So both faults were by construction rather than by luck, and the arithmetic says so:

- the placed item sat at `-side * 1.6` along the desk and the FAR trinket at `-side * 1.55`. **0.05
  apart on every desk in the game.** Neither tested the other.
- `WORK_CLEAR` was ONE 1.05 circle around the **monitor**, standing in for a screen, a tower and a
  keyboard together. The tower stands `WORK_TOWER_OFF` 1.5 away and is 1.5 deep, so 0.85 of its length
  lay outside the circle and a decal landed there legally.

**A CIRCLE CANNOT BE WIDENED INTO BEING RIGHT ON A 4.0 x 2.6 DESK.** One big enough to cover the
0.8 x 1.5 tower also swallows the 1.1 units of free worktop in FRONT of it — which is the exact
failure `WORK_CLEAR`'s own comment records from the other direction, a 1.6 radius that placed ZERO
items on ten desks. Every object here is an axis-aligned box on an axis-aligned desk.

**`ClutterSlot` is the model: one ORDERED CLAIM LIST per surface, boxes, shared.** What cannot be
moved goes in first (the decoration in the save, then the three machines, whose offsets are geometry);
everything rolled afterwards reads the same list and appends to it. `FacilityWork.claims` builds it
and `FacilityClutter` starts from it instead of guessing at each family. A worktop is still never
SPLIT into cells — the free positions are what keeps 139 worktops from reading as a grid.

Three numbers came out with it:

- **the gap was counted twice.** `r + s.r` with `CLUTTER_GAP` already inside both radii spends 0.24 of
  a 2.6-deep desk on nothing. `ClutterSlotTools.hits` adds it once per PAIR.
- **the yaw was reserved and not resolved.** A decal and a trinket turn freely, and reserving the
  half-DIAGONAL for every angle is 1.41x the object at a yaw of 0 — the difference between the desk's
  paperwork fitting and not. `turned` takes the box at the angle it is actually drawn at.
- **`WORK_CLEAR`, `WORK_TRINKET_CLEAR` and `WORK_R` are all gone.** Three fudge factors retired by one
  exact test that is two comparisons.

**And the two trinkets moved to two ROWS.** They were 0.95 and 1.55 along the back row, 0.6 apart,
where a 0.40 mug and a 1.00 document tray overlap however either rolls. A desk has 1.13 of clear
worktop down its far end and 1.7 of depth, so the room is on the other axis: the rolled kind at the
BACK (the back row has 1.5 clear beside the screen; the front has the keyboard across its middle, so a
tray at the front is rejected at half its yaws) and the mug at the FRONT, which is also where a mug is.

**The desk's paperwork is now offered the front SLOT, not a position** — and loses it to the mug 70%
of the time, decided by nothing but the claim test. That is the whole of the user's rule: a slot is
taken by one piece whether it is a 2D decal, a billboard or a glb.

**VERDICT: landed.** Render-only, no generator change. Audited on the live model over the measured
compound: **12 desks, 59 tested pairs, ZERO overlaps** (every trinket clear of the decoration, the
three machines and each other), 15 trinkets placed against the 15 the rolls ask for — none dropped —
and the front slot filled on **12 of 12 desks, 6 by a mug and 6 by paperwork**. Bench dressing did not
regress: 65 decals over 78 bench cells. Screenshots: plant at the back slot, mug at the front, the
neighbouring desk's paperwork beside its keyboard and nothing under either tower.


## A round alpha ramp is a speck's, and a monitor is not a speck (2026-09-15)

Reported from the game as "a bright spot on the monitor screen — it was a bad attempt of bloom". It
was not the bloom. `FacilityWork.screen` puts one additive quad on the glass and that quad rides
`FacilityDeco`'s LED mesh, whose alpha map is `Textures.makeRectGlowGradient(0.30)` — **a soft ROUND
dot**, which is exactly what a 0.12 status speck wants and what a 1.7 x 1.25 panel gets a hot OVAL
out of. The previous pass had already felt this and answered it with the wrong knob: `WORK_SCREEN_LEVEL`
was fitted DOWN 0.35 -> 0.10 and `WORK_SCREEN_GLOW_W/H` pulled in to 0.78/0.72 so the ellipse would
not touch the bezel. Both were treating the falloff as brightness.

**The fix is four numbers in the uv and nothing else: all four corners at (0.5, 0.5).** The ramp's
rounded-box SDF reads 255 across its whole interior, so a degenerate uv samples the flat centre and
the quad lights EVENLY, edge to edge, with the quad's own rectangle as the shape — which is what a
screen is. Zero derivative means the sample lands on mip 0; nothing else on the mesh is touched, and
the mesh stays one draw call for every blinking thing in the compound.

With no ellipse to keep off the bezel, `WORK_SCREEN_GLOW_W/H` went back out to the art's MEASURED
content, 0.93 / 0.875 (`computer_build.py`'s SUB crops, rows/cols 9..247 and 9..233 of 256). Level
stays 0.10: the peak is unchanged, only its distribution moved, and 0.10 is still well under the
~0.43 that crosses `BLOOM_THRESHOLD`.

**Verdict: landed.** Live at three offices — the glass reads as a lit panel to its bezel and the hot
core is gone. The general finding is the one to keep: **an alpha ramp is part of a quad's SHAPE, and a
shared additive mesh hands every tenant the same one.** A tenant whose shape is a rectangle opts out
by collapsing its uv, which costs nothing and needs no second material.

## A divided room is two rooms to a light fitting (2026-09-15)

Reported as "toilet lamp is right on top of the separator — should be two, one on each side", and the
two halves of that sentence are the diagnosis and the fix.

`FacilityLamps` hangs a `ROOM_SPACING` lattice over each room's rect, and a washroom is under 6 on
both axes, so `nx` and `ny` both fall to 1 and the single point lands on the rect's centre. That
centre is exactly where the divider is: `FacilityToilet.toiletPartition` puts the T's **stem** on
`room.y1 + h/2`, and the small-room fallback `toiletLine` puts its single line on the centre of its
own axis. So the one fitting in the room was always over the one cell in it that is a wall.

**`divider(m, r)` asks the finished grid, not the generator.** It takes the `FIT_PARTITION` cell
NEAREST the room centre — which is the stem, never the bar, since the bar sits one cell in from the
entrance wall — and reads its run direction by **counting** partition neighbours per axis, the rule
`FacilityDeco.rectOf` already uses and for the same reason (at the T's junction one x neighbour
stands against two in z, and "has an x neighbour" calls that a horizontal run). The lattice count is
then forced to 2 ACROSS that axis, and the existing `(j + 0.5) / n` spacing puts one fitting in each
half with no other change. A point that still lands on the divider is nudged to the nearest of its
four neighbours inside the room (`free`).

**Verdict: landed.** Two 4x4 washrooms measured, both now 2 bulbs where they had 1, at cells either
side of the stem; every other room's count unmoved, because `Math.max(n, 2)` is a no-op on a room
already over `ROOM_SPACING`. Standing note: **this is render-side and asks the grid, so it costs the
generator nothing and survives a room whose rect and whose furniture disagree** — which is the same
move `vent-cap` made when it stopped being a flag carried along a wall.

## Third pass on three hand-modelled props, and each fault was a number that was nearly right (2026-09-15)

Three reports in one turn, all against `models-src/facility/`, and none of them was a modelling
decision — each was an offset within a few hundredths of correct.

- **The basin's shaft cap cut across the bowl.** Reported with the poly probe: `deco-basin.glb`
  face #10 at local y **1.73**, which is `SHAFT_Z` exactly. The second pass sank a 0.07-deep shaft
  under the lid and CAPPED it at 1.73 — above the bowl's own floor at 1.200 — so that cap sat inside
  the sink. **The shaft is gone entirely now and the lid face is simply deleted**: the vessel is one
  closed lathe from flange to floor, so nothing under it needs closing, and the opening it leaves
  (1.12 x 0.72) is covered all round by the flange (1.25 x 0.775) with the bowl's widest sub-flange
  section (1.10 x 0.682) dropping through it. **And there was a SECOND polygon across the basin**,
  reported straight after off the .blend: the BOWL'S OWN low cap. `buildlib.tube` closes a ring with
  a full DISC, and this lathe's FIRST ring is the flange's outer edge — the widest point of the whole
  vessel at 1.25 x 0.775 — so capping it laid a 20-gon of that size at **z 1.806, which is 0.07 BELOW
  the rim at 1.876**. The largest horizontal face in the model (area 3.842 against the bowl floor's
  0.346), and the pass that removed the shaft *looked straight at it in a face dump and let it
  through*, because its normal points DOWN. The material is `doubleSided`, and a face nothing can be
  behind is not harmless either way. `turned` takes `cap_lo` now. `check` reports **holes 24** — 4
  from the counter's deleted lid face, 20 from the bowl's open flange edge — and that is the design.
  860 -> 792 tris. **The read to keep: on a profile that runs OUT and back IN over itself — every
  vessel in this repo, the mug's coffee and the pot's soil included — the lathe's first ring is NOT a
  bottom, and capping it by reflex puts a lid on the thing.** A drop-in sink is open at that edge by
  construction: the edge is where it meets the worktop, it sits 0.006 over a lid that overhangs it
  0.13 all round, and what a flange underside actually wants there is an ANNULUS, which a one-loop
  lathe cannot state and which nothing can see.
- **The plant's skirt grew through the pot.** Tier pitch was 78/50/22 degrees; a blade leaving the
  axis at 22, drooping by its own quadratic, reaches the rim's outer radius 0.21 at **z 0.358**
  against a rim top of **0.360**. 80/62/44 puts it at 0.470, 0.11 of daylight, and keeps a 36-degree
  crown-to-skirt spread. The plant stands up with it: 0.6164 x 0.7159 across -> 0.5146 x 0.5265, so
  `WORK_PLANT_W` followed 0.64 -> 0.53.
- **The mug's handle came back out through the glaze.** The arc spanned 192 degrees, putting each end
  at x 0.1067 against a wall standing at 0.1244 — buried by 0.018 where the **rod's own radius is
  0.022**, so the far side of the end cap re-emerged and read as a facet welded to the side. 216
  degrees buries them 0.040 and 0.055. Six sides went to eight at the same time (+28 tris): at this
  size the rod is the second-largest thing in the silhouette and six read as a hex bar.

**Verdict: all three landed.** The reusable line is the middle one's: **a piece buried in another
must be buried deeper than its own half-thickness, not merely past the surface** — the end cap is at
the centreline, and everything around it is not.

## A Rec.709 sat mix HOLDS luma by construction, so a bright prop needs a second knob (2026-09-15)

"Yellow drums is too bright too, desaturate (and check the third drum)" — and the entry above on the
radiation drum had already written down the wrong lesson for it: *"the brightness comes out with it
and needs no second knob."* That was true THERE and does not generalise. `tools/models.mjs`'s `sat`
mixes each texel toward its own Rec.709 luminance, so **luma is invariant under it**. Rad got dimmer
because its brightness sat in one dominant red channel that the mix pulled down; yellow is TWO
channels at 210 and 172, and desaturating it moves the luma by 0.1.

Measured on cell 1 of `drum-sheet.png`, through the real pipeline (`sat` on the map in linear light,
`baseColor` multiplying in linear light at render):

```
                     chroma   luma          sat 0.61 alone:  chroma 73.6  luma 174.6
drum-bio  as drawn    190.2   174.6         sat 0.85 + bc 0.33:  chroma 74.9  luma 103.6
drum-rad  sat 0.5      73.1    92.5
drum-steel untouched   72.8    60.1
```

So `sat` fits the HUE and `baseColor` fits the VALUE, and the pair has to be solved together because
each moves the other's metric. Verified on the **built glb**, not the source: 124.6/104.2/41.4,
chroma 75.1, luma 104.0. All three barrels now sit at one chroma and are told apart by hue, which is
what the trio was drawn against `style_prop` to do, and the yellow one is still the lightest, which
it should be.

Two more fitted the same way in the same turn, both reported as "desaturate plant and cup":
`facility/desk-mug` (the cream glaze was **linear 0.5548**, 4.4x the `desk-top` laminate it stands on
and the single brightest interior surface in the game) took `sat 0.5` + `baseColor 0.40` -> chroma
6.0, luma 125.8; `facility/desk-plant` took `sat 0.5` alone -> pot chroma 89.6 -> 44.3, leaf 53.8 ->
23.0, and **no** `baseColor`, because both its cells were already inside the value band and only the
pot's hue was out. That is the test for whether a prop needs one knob or two.

**Verdict: landed.** Standing rule: **`sat` is a hue knob and nothing else. If a prop reads BRIGHT,
measure its luma before reaching for it** — and measure both on the pipeline's own arithmetic, since
a chroma read off the sRGB source over-predicts what a linear-light mix will do to a channel already
near zero (0.38 was the first fit here and it landed at chroma 42, half the family).

## A slot's tenant should not always be the same object (2026-09-15)

Three small reports with one shape: "add clutter spot on top of the cabinet", "cup probability is too
high", "cup seems to appear way too often on the table — should be random clutter", "can we have
multiple cup textures for variety".

- **The cabinet joins the lid family.** `FacilityClutter.slots` took `FIT_BOOKCASE` and
  `FIT_TABLE_LOW` and excluded the cabinet on a premise that was simply wrong — the note called it
  "chest-high with a rounded top", and `cabinet_build.py` builds a plain box with a `buildlib.chamfer`
  down its edges. Its lid is as flat as a bookcase's and only taller. `CLUTTER_SLOT_INSET` 0.10
  already clears the chamfer and `CLUTTER_SLOT_FILL` caps the item against `DECO_CABINET_D` 1.2.
  Verified by scanning the merged clutter mesh's vertex levels: **y 3.447** appears, which is
  `DECO_CABINET_H` 3.432 + `CLUTTER_Y`.
- **`WORK_MUG_PCT` 70 -> 30.** 70 was chosen when the front slot had no other claimant. It has one
  now (`FacilityClutter` offers the same slot to the office sheet's paperwork the moment no mug takes
  it), so the slot is filled EITHER WAY and the number only decides how often the thing in it is the
  same object. At 70 a compound deals one mug model a dozen times and reads as issue kit.
- **Three glazes off one mesh**, the hazard barrels' own arrangement: `desk-mug-b` and `desk-mug-c`
  are the same `desk-mug.glb` re-entered in `art/models.json` with their own `baseColor` tint and
  `sat`. `render.Models.instanced` is keyed by PATH and carries no per-instance colour, so a glaze
  costs a batch whichever way it is produced — and produced this way it costs no art, no triangles
  and no Blender pass. All three land at luma ~116-126 and differ only in hue (chroma 6.0 neutral,
  12.3 cool, 23.0 warm). `FacilityWork.MUGS` is the list one roll picks from.

**Verdict: landed.** `FacilityWarm`'s four hand-written trinket rows became one comprehension over
`FacilityWork.TRINKETS` so a fourth glaze needs no edit there; `FacilityArea.EXTRA` stays literal and
index-aligned with `green`, which is the one list that cannot be derived.

## The mirror was blue because the room's own light is blue, third time (2026-09-15)

"Redo mirror — it's bright blue, which is ridiculous." The art was doing exactly what its prompt
asked: the previous roll's clause read *"a cool light blue-white sheet fogged with condensation"*.

**`FacilityStyle` already carries the warning and this is the third entry to pay for ignoring it:**
the compound's own installation is `LAMP_COLOR` 0x9db4d4, so a blue-white SURFACE under a blue-white
LIGHT is not cool, it is saturated. Re-rolled solo (a mirror maps 0..1 with a frame round it, so it
can never come off a shared sheet) with the fog specified as perfectly neutral grey. Measured on the
drop: **chroma 2.2**.

Value was refitted from scratch and inverted: the new art is drawn at **0.1141 linear**, which is
UNDER `facility/wall-wash`'s 0.1593 and would have hung the old black-rectangle fault back on the
wall — so the lift BRIGHTENS for the first time on this entry (**0.73**, where the old art needed
2.05 to come DOWN). Landed **0.1969**, 1.24x the wall it hangs on, where the old roll was 1.67x and
read as glowing. Left there rather than chased to the 0.698 the measured rate asks for
(d ln L / d lift = -2.02 across the two points): under the target is the safe side of this fit.

**Verdict: landed.** Standing note, now three deep: **a blue accent cannot be stated by hue in this
compound — state it by VALUE and leave the hue to the lighting.**

## A workstation nobody can sit at, and the corner desks that never met (2026-09-15)

Two faults on one reported pair of cells ("tables on 61,28 and 61,29 are only half done missing
polygons... if you remove the chair, then there should be not computer, only clutter").

**The seat test lived in the wrong pass.** `FacilityWork.chairs` has always refused a chair on a cell
that is not clear floor — a desk run facing another run, a desk in a room corner — and it was the
only pass that knew. `at()` went on returning a workstation, so the monitor, the tower and the
keyboard stood on a desk nobody could reach. Moved into `at()`, which is the pure function every
other pass in that family is built on (`spots`/`claims`/`trinket`/`pools`/`build`/`props`), so they
now agree by construction and the freed worktop falls back to `FacilityClutter`'s paperwork.
Measured on a fresh compound: **13 office desk cells, 10 workstations, every one of them with a
seat cell** (it was 10 and 10 before, with one of them seatless).

**The missing polygons are the DESK SHRINK.** `FacilityTables` thins an office cell by
`CELL - DESK_D` on the hand AWAY from the wall it backs onto, and `wallHand` takes the FIRST wall it
finds — so two desks meeting at a room corner back onto DIFFERENT walls and are thinned on DIFFERENT
axes. Their rects then stand `DESK_D` short of the boundary they share, while the face loop skipped
the panel there on the grounds that the neighbour `isTable`. A hole between two desks, open to the
casework inside.

`openHand` answers it in three lines: a face is closed by its neighbour only when NEITHER cell was
cut away from the boundary between them. A bench is never thinned, so the lab side is unchanged.

**Verdict: landed.** The rule generalises to any future per-cell shrink: *a run test may only skip a
face when both rects actually reach the line.*

## The divider stopped at its own cell boundary, and sight went straight through it (2026-09-15)

Reported twice over: "separator wall does not come all the way to the outer wall leaving a gap" and
"toilet separator wall SHOULD block los".

**The gap is `FacilityGeom.slab`'s inset, seen from the other side.** A wall cell's masonry is inset
by `(CELL - thick) / 2` on the hands its line does not carry into — 1.0 unit here — so the wall's
inner face stands a unit back inside its own cell and the room's floor carries on under the overhang.
Every wall-hugging family in this compound already measures off that face (the corridor casework, the
kit props, the litter bins); `rectOf`'s partition branch was the one that did not, and ended its run
on the cell boundary. Measured after the fix, over every partition end in a fresh compound that meets
masonry: **gap 0.000**. The test is `isWall && carries` and NOT `isSolidWall` — a washroom's light
wells are glazing and a divider meeting one meets the same masonry line, while a DOOR cell answers
`carries` and is not a wall, which is what keeps a divider out of an opening.

**And it blocked no sight at all.** `AreaGame.recalcTile` clears `canSeeThrough` from exactly two
sources: the tile id table, and an object on the cell that says no. A partition cell finalises to a
plain unwalkable floor id, `paintRoomFloor` rewrites that to marble+16, and **both are
`TILE_SEETHROUGH = 1`** — so a full-height opaque slab (`PART_H` = `WALL_H - 1`) divided nothing but
walking. `objects.Decoration.canSeeThrough` now returns false for `FIT_PARTITION` and nothing else.
Verified live: the cell reads `canSeeThrough false` and `isVisible` across it is false.

**Answered on the OBJECT and not in the tile table on purpose** — `TILE_FLOOR_TILE_UNWALKABLE` is
stamped by `placeFitting` for EVERY fitting, so the tile route would have made racks, cabinets and
machines opaque too. Old saves need no migration: `recalcTile` re-derives on load.

**Verdict: landed.** Standing note: **`canSeeThrough` is per OBJECT here, and the floor id under a
fitting says nothing about what you can see over.**

## A drain cell kept the laboratory's floor in a marble room (2026-09-15)

"47, 26 — drain is here but it looks like it has a different tile texture around it."

`FacilityGeom.floorBuf` routed `Surf.GRATE` to `default: floors[Surf.TILE]`, which is right in a lab
and wrong everywhere else. The generator writes a grate tile id under a floor drain BEFORE
`paintRoomFloor` runs, and that pass only rewrites `TEMP_BUILDING_ROOM` and the unwalkable floor id —
a final id survives it. So a washroom's drain cell stayed `GRATE` and drew one square of lab tile in
the middle of the marble.

The art was never the question: the drain's own grate is a separate centred decal
(`FacilityDeco.drain`, `facility/floor-grate`), which is why `floorBuf` deliberately refuses to paint
`GRATE` as a cell-wide surface at all — painted that way, a 2 m square of grating reads as a vehicle
pit. What belongs under the decal is simply the room's floor.

`surfUnder` inherits the surface of the first non-`GRATE` indoor neighbour, four cells, falling back
to `TILE` — a pure function of the saved grid, five lines, no new buffer and no new call. Verified
live on a compound whose washroom drain sits at (41, 40) with all four neighbours reading
`Surf.WASH`.

**Verdict: landed.** The general shape: **a cell whose id is a FITTING rather than a floor has to
borrow its floor, because the pass that would have painted it has already stepped over it.**

## Three glb faults: a handle above the coffee, a seam with a width, a front on a hidden face (2026-09-15)

**The mug handle was never poking through the GLAZE.** Reported a second time as going too far into
the cup; the previous pass had widened the arc 192 → 216 degrees so the end CAP stopped emerging, and
that part was right. Measured on the built mesh: the upper end sat at z 0.2815 and the rod's own
crown therefore reached **0.3035**, while the BREW cone over that end's radius stands at **0.2966** —
0.007 of an eight-sided rod lying in the coffee with both ends buried in the wall. The arc is lower
and slightly further out now (centre 0.126/0.165, radii 0.105/0.100): **crown 0.282 against the
brew's 0.297**, ends buried 0.046 and 0.031 against the rod's own 0.022, belly 0.081 clear of a 0.150
wall. *A swept handle has two clearances and the invisible one is vertical.*

**The basin's black seam was a swatch with a WIDTH.** `lathe_uv` runs u once around from the seam, so
the crop's left edge is laid against its right — and `R_CERAMIC` was a 15 x 20 px crop falling 15
counts of luma across those 15 px (89/86/83 at sd 4.2, down to 77 at its right edge, with BLACK
texels 3 px past it). At `tex` 512 with mips those black texels bleed straight into the seam quad.
Collapsed to **ONE TEXEL** at (309, 692), measured as the crop's own mean exactly — the litter bin's
finding, applied to the piece that needed it most. Bowl u now spans 0.30189–0.30288.

**And the low rack's carcass front wore the whole rack-front cell.** Reported as wanting the side
texture. The chassis stand over the full height of that face (`n * CHASSIS`), so what shows is the
slivers round their bezels — each a squeezed copy of the entire three-chassis image; on the TALL
cabinet it was wrong twice, since the cell maps 0..1 whatever the height and the art behind six
chassis ran at half the density of the art on them. It takes `I_PLAIN` now, a swatch of the side
cell, and a swatch cannot stretch. Verified by classifying every front-facing triangle of both
cabinets by the rect its UVs land in: the only FRONT-cell faces left are the chassis vent panels.

**Verdict: landed.** All three rebuilt, `buildlib.check` 0 holes / 0 near-coplanar (the basin's 24
holes are its open bowl, by construction), `propstat` **0 UV smears** on every one.

## The gas rack's amber, fitted where the drums are (2026-09-15)

"Gas rack — reduce saturation." The hand-modelled rack (`facility/gas-rack-hand`) was the only
coloured prop in the family carrying NEITHER knob: its amber is a cell of an authored sheet, so it
shipped raw at **chroma 152.1** against a drum family fitted to 72.8–74.9.

Its GENERATED predecessor records the whole argument at length and it does NOT transfer: that bake
sits on a flat `baseColor 0.95`, so `sat 0.5` was rejected there as "almost white" — a desaturated
BRIGHT surface is a pale one where a desaturated mid one is grey. This prop's level comes from the
pixels instead, so the fit is its own.

`sat 0.6`, and the measurement is on the BUILT atlas rather than on the prediction: bottle cell
**159.4/104.0/82.9, luma 114.2, chroma 76.5**, landing on the drums' own band. Luma is untouched by
construction — the Rec.709 mix in linear light is why `sat` is a hue knob and `baseColor` is the
value knob, and the user asked for one of those two.

**Verdict: landed.** `sat` alone; no `baseColor`, because nothing reported the rack as bright.

## The cleaner's kit, and a weighted bag instead of a uniform roll (2026-09-15)

Four reports in one pass: the desk lamp too common, "generate new blender model — uneven stack of
journals", "create blender broom and bucket and add them to corridors and toilets", and "trash cans
should spawn in the toilet too".

**THE LAMP WAS NEVER TUNED, it was a third of a uniform roll.** `1 + (g >>> 14) % 3` over
plant/lamp/tray under `WORK_TRINKET_PCT 55` puts a lamp on ~18% of every workstation desk in the
compound. Replaced with a weighted BAG of indices — `[1, 1, 3, 3, 6, 6, 2]` — which drops the lamp to
~8% and is also how the journals got in without moving anything else. *A bag is what a table of
rarities looks like when there are six of them and no weights field.*

**The journals are a TRINKET and the broom and bucket are NOT FITTINGS.** A fitting costs a
`_FittingKind`, a unique entities64 frame (three are free), a `_DecoPlace` row, a `Deco.selfCheck`
tag, `heightOf`/`rectOf`/`fittings` rows and a generator call site — and the generator places nothing
in a corridor at all, so a fitting could not have reached half of what was asked for. `FacilityJanitor`
is the compound's sixth render-only unstamped pass, built on `FacilityKit`'s shape and gated on
`Surf.LINO` + `Surf.WASH` where the lab kit takes `Surf.TILE`, so the interior divides by SURFACE
with no shared list and no ordering between builders. The washroom's bin came free: `indoorBins` only
needed `Surf.WASH` added and the fitting/worktop guards a washroom needs and a corridor does not.

**A stride lattice has to be COPRIME with its step** — `(col * 5 + row * 2) % 5` is `(row * 2) % 5`,
so the first cut selected whole ROWS of corridor and missed every cell between them (7 candidates
against 20). `(col * 3 + row * 2) % 5` walks it diagonally, which is `FacilityKit.place`'s own shape.

Art: **one 1k pack4** (`janitor-sheet.png`, seams measured at column 511 and row 511), four cells —
binding cloth, page edges, a split bristle/handle cell, galvanised sheet with a plain corner patch.
**Values fitted IN THE PIXELS, not with a knob**, because one sheet dresses three props and
`sat`/`baseColor` are per LABEL: the page edges came off the gen at luma **164** against a family
running 45.7–93 and went to **92.1**, just under the basin's ceramic; bristle and handle took a
Rec.709 desaturation (0.62 / 0.55) off chroma 88 and 95. Built: journals **48 tris**, broom **52**,
bucket **300**, all `holes 0 / coplanar 0 / 0 UV smears`, sampled luma 72 / 71 / 79.

**THE BUCKET'S BAIL IS A HALF TURN FROM RIM TO RIM** and the first cut swept 200 degrees about a
centre ON THE AXIS, which put both ends near the middle of the bucket and drew a hoop hanging down
one side. An arc over a vessel is centred on the vessel. **THE BROOM LEANS** — 11 degrees of pitch
built into the mesh, toward glTF -z, which is the hand `KitProp.yaw0` exists to name — and its shaft
is 0.10 across where a real handle is 0.048, because an honest member width reads as WIRE at this
camera for the third time in this repo.

**Verdict: landed.** Live on a fresh compound: 2 brooms, 3 buckets, 2 journal stacks, the washroom's
bin in its corner.

## A vessel wound the right way and built inside out

Reported as *"bucket got textures inverted for body — even on the outside, horizontal lines on the
inside"*, which is exactly what it was.

**Diagnosed off the BUILT glb, which is the only place it is visible.** Dumped every face of
`janitor-bucket.glb` by radius and local y against its uv:

```
y 0.050-0.545  r 0.245-0.285  u 0.5020-0.9980   <- wearing cell 3's galvanised bands
y 0.075-0.592  r 0.255-0.290  u 0.9083-0.9092   <- wearing the one-texel plain swatch
```

The return leg of the lathe profile sat at a **larger radius than the outward leg at every height**,
so the surface the script called the inside was the one the room sees. The vessel rule was followed
(out to the rim, over it, back down to a floor), every normal pointed the right way, and `bands=4`
put the banded cell on rings 0–3 exactly as intended — the fault was two numbers in the profile.

**WINDING SAYS WHICH WAY A FACE LOOKS; RADIUS SAYS WHICH SIDE OF THE SHEET IT IS.** `buildlib.check`
cannot see this (0 holes, 0 coplanar either way), `propstat` cannot see it (0 smears either way) and
the Blender viewport cannot either, because an inside-out vessel is still a closed solid that shades
correctly. The face dump is the check, and it belongs in the loop for any lathed vessel.

Return leg pulled inside the outward one — `(0.285, 0.592), (0.232, 0.070)` against `(0.245, 0.050),
(0.285, 0.545)`, a ~0.013 wall — and re-dumped: `r 0.245-0.285` carries the bands, `r 0.232-0.285`
the swatch. 300 tris unchanged, `holes 0 / coplanar 0 / 0 smears`.

**Verdict: landed.**

## A broom's head is a lathe, and `lathe_uv` has two fixed axes

*"make broom lower part more curvy, both hair and above"*. The bristle block and the head were
`bl.box` slabs — a crate on a stick — and both became `buildlib.roundrect` cross-sections carried up
a profile, the bristles bellying out toward the floor (1.00 / 1.06 / 1.00 / 0.92 over 0.26) under a
moulded head. 52 tris → 308, which is the bucket's own count and cheap for a prop that is 2 or 3 to a
compound.

**The shape was the easy half. `lathe_uv` puts one whole turn in u and the piece's whole height in v,
and that is not negotiable per face — so a wide short piece gets TWO faults at once.**

**ASPECT.** The bristle block is 1.46 round by 0.26 tall, so the cell's full height landed on a sixth
of the world height: straw drawn as vertical strands came out as horizontal mush. `vspan` =
height/perimeter (0.18 here) is the fix, and it is the same measurement the bench's own tiling uses —
art px over the size a thing is DRAWN at.

**DIRECTION.** The handle cell is grained VERTICALLY because it dresses a shaft; a broom's block is
grained ALONG its length. There is no argument to `lathe_uv` for that, so the head takes the same
cell TRANSPOSED (`janitor_build.transpose`, four lines) over a rect 0.30 wide and all of it tall —
0.30 because perimeter 1.60 against height 0.23 is 7:1 and the cell is square, so that is the ratio
that makes the quarter turn land isotropic.

bbox unmoved at 0.62 x 0.64 x 2.67, so no `FacilityStyle` dim changed. `holes 0 / coplanar 0 /
0 smears`.

**Verdict: landed.**

## The shelving stops being a DRAWING of a frame, and the trolley comes off TRELLIS

*"storage shelf with boxes stopped spawning or is too rare — firstly make it a blender model instead
of quad-based"*, and *"redo trolley as blender"*. Both in one `store_build.py` off one sheet.

**The shelving is the strongest silhouette claim in the fitting family and was the last one taken.**
What it replaces is two alpha-cut PANES standing in for end frames with zero-thickness quads between
them — a cut-out drawing of a frame, which is the one thing the silhouette-vs-surface test says a
texture cannot be. 204 tris buys four uprights, four cross rails and a brace to each end, three
perforated plates, and daylight through the middle that is real.

**NOT ONE PIXEL OF NEW ART.** `tools/modelsheet.py` packs the BUILT `deco-shelf-side` and
`deco-shelf-top` into `store-sheet.png`, so the unit standing in a lab is the same steel as the unit
that stood there before it and every fitted lift is already in the pixels — no `baseColor`, no
`lift`, no `sat` on either label.

**CELL 0 IS TILED 1.561x IN U, and that trick is the reusable part.** `modelsheet` stretches a
non-square source into its square cell and `deco-shelf-side` is 328 x 512, so a straight pack puts
OVAL slots on the uprights. Tiled 1.561 the first copy lands 1:1 at u 0..0.6406 and **one cell texel
is 0.005078 world units on both axes**, which is what lets every rect be read straight off the
pixels. Cells 1 and 2 are the same plate at two pre-tiled periods (4.22x2.51 and 3.60x1.64) because
a hand-modelled face maps 0..1 and cannot wrap — one period cannot serve two shelf sizes.

**THE GEOMETRY IS READ OFF THE ART.** Uprights are columns 4..31 (0.142 wide); the four rails are
rows 11-35 / 142-166 / 304-328 / 467-492, and their CENTRES land on 0.955, 0.699, 0.383 and 0.0635 of
the height — `DECO_SHELF_Y` plus `DECO_SHELF_TOP_Y` to three decimals.

**Two `buildlib.check` findings, both about pieces sharing a plane.** The plate flush with its rail's
top face is eight z-fights (`PLATE_UP` sinks it 0.02 in instead), and the brace at a rail's own 0.09
put its flanks on the rails' planes — it is 0.05 stock now, which is what a brace is anyway. Then a
third, from `propstat`: the brace is at 31 degrees by the time `finish` runs `unwrap`, so its END
faces project to a LINE — 8 zero-area tris. Stating one `flat_uv` window only moved the fault to the
top and bottom faces (16); **a 1-texel rect is the only rect that is safe on every face of a piece
that gets turned.** 0 smears.

The trolley is 268 tris against the bake's 5,915, and its own entry records why nothing was lost:
88.19% of that 2048 atlas sat in ONE 16-count luma band, so "bright tube frames against dark shelf
slabs" was never in the texture and `baseColor` could only move the level. Here the frame IS tube and
the trays ARE plate. `KIT_TROLLEY_W/D` re-fitted to the measured 0.988 / 0.453 of its height.

**Verdict: landed.** `holes 0 / coplanar 0 / 0 smears` on both.

## A crate is one of the things on a shelf, not the only thing

*"add clutter slots on all shelves and spawn boxes mixed with room clutter. note that box itself
should go into the generic storage clutter list"*, and *"add clutter slots to [the trolley]"*.

`FacilityDeco.boxes` stood `1 + g % 3` crates on every plate of every unit and nothing else, ever —
which is why a shelving unit was the same object every time and why the request is really one
sentence: a box should be an ITEM, dealt like the rest.

**The refactor is `slot()` → `lid()` + `ClutterLidOpts`.** The old function read its rect out of
`FacilityDeco.rectOf` and its height out of that rect, so it could only ever dress ONE lid per grid
cell, square to the world. None of that holds now: a shelving unit has three shelves, a trolley has
two, the trolley is **render-only and has no grid cell at all**, and it carries `KIT_YAW_JIT` so its
lid is not axis-aligned. Stating the surface instead of looking it up covers all three; items are
sampled in the lid's OWN frame and rotated out by `yaw`, so a fitting passes `yaw: 0` and reads
exactly as it did.

`FacilityKit.trolleys(m)` is a PURE re-run of the same placement with the side effects off (the
contact pool and the wall halo are laid once, by `props`) rather than a cached array — the placement
is a function of the saved grid and nothing else, which is the rule this family already keeps.

**`CLUTTER_BOX_PCT 55`** is what "mixed" means as a number: over half, because a storage shelf IS
boxes and the jars and paperwork are what say somebody uses it. `CLUTTER_STORE_MAX 4` against a
bookcase lid's 2, because a shelving plate is 2.32 x 1.38 where a cabinet's lid is 1.2 deep and it is
the surface things are MEANT to be on. The crates keep the AO ramp and the plate pool the old placer
had, in a third `MeshBuf` flushed through `FacilityDeco.solid` — the two clutter sheets are alpha-cut
and cardboard is opaque with vertex colour, so it was never the same material.

**`DECO_SHELF_PLATE_Y 0.0398`** exists because `DECO_SHELF_Y` is the RAIL: standing a box on that
sinks it a plate's thickness.

The bookcase's interior boards were left alone deliberately — at 51 degrees down you see the board
above, not the shelf under it.

**Verdict: landed.**

## The shelf was not rare, it had all but stopped

Measured end to end rather than estimated, by counting frames 8/9 and 8/10 in `ctx.spawns` over 2000
seeds: **0.12 shelving units per compound.** One per eight compounds, which is why it read as having
stopped. The per-cell arithmetic predicts 1.85 and is wrong by 15x — most `slot` cells are refused
before the roll ever happens (already-taken, beside a doorway, glazed-and-bare).

Two changes, both the user's call: `'cabinet'` joins its `blocks`, and a new optional `weight` on
`_DecoPlace` (`Deco.places` pushes an entry `weight` times, so `pick` stays one flat roll over a
five-long list). Shelving takes 3.

**Measured after: 4.08 per compound**, and the split is worth writing down — the office is 3.8 of it
and the lab only 0.26. The lab's floor-high roll is simply rare; what actually moved the number is
that `roomCabinet` places 1–3 fittings OUTRIGHT per office room, so an entry's share of that list is
worth 30x its share of the lab's dice.

`make gen seeds=20000` clean.

**Verdict: landed.**

# Facility pass 7 (2026-09-16)

## Baked AO everywhere it pays, and the two knobs are not the same knob

Pass 6's rim contour was rejected and baked AO replaced it. That raised the real question: the
pipeline has had `bakeAO` since the TRELLIS props and **only 4 of 76 models used it**, while the
engine's own screen-space AO costs what it costs. Measured in the facility on one pinned frame,
GTAO toggled A/B/A/B x4, median of 20 GPU samples each:

| | draw calls | GPU median |
|---|---|---|
| `GTAOPass` off | 126 | **1.87 ms** |
| `GTAOPass` on | 233 | **13.71 ms** |

+107 calls and 7.3x the frame; `Config.hx:85` ships `vidAO = false`, and `SewerStyle.hx:135` recorded
the same verdict from the tunnel side long ago. **Baked AO is not a cheap alternative to real AO —
it is the only AO this game can afford.**

Twenty labels took `ao`. Two findings came out of fitting them, and both are about the fact that
`ao`, `aoRes` and the new `aoReach` do three different jobs that the first pass conflated.

**1. AO NEEDS VERTICES WHERE THE OCCLUSION VARIES.** `bakeAO` samples per vertex and the rasterizer
interpolates, so a face with no vertex in the middle cannot darken in the middle. The trolley is the
proof and it is unambiguous: its lower tray sits 0.75 under the upper one and could not be more
occluded, but the lid is a `bl.box` — four corner vertices — and COLOR_0 came back **0.908 / 0.931,
identical to the UPPER tray's own corners**. The bake had nowhere to put the answer. One cut
(`grid_box`, `PLATE_CUTS 1`) puts a vertex at the centre and the lower lid reads **0.829 against the
upper's 0.959**. `flat_uv` projects per loop, so every sub-face maps correctly with no UV change.

**2. REACH IS THE PHYSICS, STRENGTH IS THE PRICE.** `reach = span * 0.35` was hardcoded, and it is
wrong in both directions. Too short: the janitor bucket's bore is 0.5 across a span of 0.84, so at
0.294 every cross-bore ray runs out of steps and the inside of a bucket bakes as open as the outside
— and the trolley's own tray gap is 0.75 against a reach of 0.70, which is why the tray fix above
needed `aoReach 0.6` as well as the extra vertex. Too long: a dense open frame sees itself
everywhere and saturates, and the first cut "fixed" that by CUTTING the reach, which merely blinded
the shelving to the shelf above it (gap 0.827, reach 0.39).

The separation that works: **set `aoReach` from the gap the prop must see across, then set `ao` so
the bake costs the prop a fixed share of its LEVEL.** Every one of these props was value-fitted —
`art/models.json` is full of "a prop at 49 renders as a hole" — so a term that drops the mean albedo
37% is a regression however good its variance is. Fitting each label to **mean COLOR_0 = 0.80** is
one step, because `ao` scales the occlusion linearly:

    ao_new = ao_old * (1 - 0.80) / (1 - mean_measured)

That lands 20 labels at mean 0.798-0.802 with sd 0.109-0.196 — the same band as the one prop already
known to read well (`gas-rack-hand`, mean 0.922, sd 0.107, measured on screen at +40% shading
variance). Strengths came out 0.26 (car) to 0.55, where a flat 0.55 had put the car at mean 0.667.

**The gate that does NOT work is `min(COLOR_0)`.** Every prop passes it — the floor is reached by
one crevice on anything. `%` of vertices pinned at the floor is better but still misleads (a pile of
bricks SHOULD have fully-occluded contact points, and they are the ones you cannot see). The mean is
the honest gate because it is the thing the viewer reads.

**Verdict: landed.** +0 draw calls, +0 uniforms, +0 texture memory; one `USE_COLOR` permutation per
prop, warm pass 85 -> 86 programs.

## A clearance stated as a SUM is a clearance in the wrong direction

> Already logged under pass 6's bail entries. Repeated here only because pass 7 found the same shape
> a second time in `aoReach`: a default that is one of the real answers cannot be told apart from a
> deliberate choice. `?role` below is the third instance in two passes.

## A machine in a washroom, and no check in the file had ever looked at a decoration

Reported: "we still have machine spawned in toilet". Traced: `RoomBlock.slot` dresses every room's
leftover bays, `FacilityToilet.zones` demands only the stall run and the basin run so a washroom's
other bays fall through to that shared filler, and `FacilityRooms.addFitting`'s **`?role` silently
defaulted to `BLOCK_LAB`** — so a caller that did not think about the room was handed the
laboratory's own furniture list, compiling correctly and reading correctly.

That hole was closed in the previous commit. **The finding is why nothing caught it for a whole
pass:** `grep 'deco\|fitting' src/gen/GenCheck.hx` returned nothing. `washroomSane` is about doors,
`spawnsSane` is about cells, and no check in the oracle had ever asked what a decoration IS.

New `GenCheck.decoBlocks`, and the shape of it is the point: **it reads the finished grid, not the
dealer** — frame -> `Const.placeOf` -> `blocks` -> the role of the room the cell falls in. There are
three arms that put fittings down (rolled through `Deco.pick`, outright by kind through
`placeFitting`, and raw row lists through `CHEM_LABS_DECO_FLOOR_HIGH` that consult no table at all),
and a check written against the dealer would have passed every one of them. Row 8 cols 4-8 of that
raw list IS the machine.

**One false-positive class, and it is worth recording because the table does not say it anywhere
else: `blocks` holds two kinds of string.** 'lab', 'cabinet' and 'toilet' are room ROLES; 'lounge' is
a ZONE, a corner of an office furnished outright, and no room is ever a lounge. The first cut
reported **6,096 faults over 2000 seeds**, every one of them a sofa or a low table standing in
correct furniture. An entry naming no room role at all is template-placed and `blocks` is not a claim
about rooms.

Measured after: **0 failures at 2000 and at 20000 seeds** — so the previous commit really did close
it and what was on screen was an area generated before the fix, decorations being persisted state.
`?role` is now required, so the compiler asks.

**Verdict: landed.**

## A cell is half the sheet, and `tex` halves it again

Reported against the trolley's tray: "this texture is too low-res (u,v problem)", with the probe UVs.
They resolved to exactly `C_TRAY`, and the arithmetic in pass 6's own note was wrong by 2x on each
axis: `--cell 512 --cols 2` makes a **1024** sheet, so one cell is 512 of 1024 — and `tex: 512` then
downsizes that atlas again, so a cell SHIPS at 256 px. 0.396 of it is 101 px over 1.98 world units.

| | texels over the piece | per world unit |
|---|---|---|
| tray, before (`bl.sub` of a 1x1 cell) | 101 x 46 | **51** |
| shelving plate (all of cell 1) | 256 x 256 | 110 |
| ground tiling | — | 57 |

**And `--repeat` already crops — the pass-6 note claiming it "cannot express a repeat below 1" was
simply wrong about a tool in this repo.** `modelsheet.tiled` sizes the tile to `round(w * ru)` and
pastes from the origin, which its own docstring says. Cell 2 goes in at `0.396x0.1804` and the tray
takes the WHOLE cell: 158 x 72 source pixels land on 251 shipped texels. Measured on the built glb,
u span 0.4911 x 512 = 251 texels over 1.98 world.

**The ceiling is the SOURCE and not the atlas**: `table-top.png` is 400 px over a 5-unit repeat, so
80 texels per world unit is all there is. 51 -> 80 is the real gain; the atlas now upsamples rather
than throwing information away, which is what the 101-from-158 downsample had been doing. `tex` 1024
was rejected for that reason — it cannot buy detail the source does not have, and costs 4x.

**Verdict: landed.**

## A vertical cylinder cannot be lit in this game, so its highlight is painted

Reported: "the grip is shiny, the poles aren't. make them shiny." Both wear the same one texel of
flat steel, so the difference was never the art. `FacilityStyle.PROP_ENV.keyDir` is
**[0.35, 1.0, 0.25]** — very nearly straight up, and its own comment records the trade ("dead-up it
lands the glint on the shelf tops alone"). The grip's crown is a HORIZONTAL run whose normals sweep
through +y and cross that key; a vertical pole's normals are all horizontal and never do. With
`IndoorMask`'s only directional term being `1 + bounce * dot(N, up)`, the hemisphere keying on
`normal.y` and no camera-side fill anywhere, **a standing cylinder shades identically on all sixteen
of its facets and renders as a flat bar.** This is the gas bottles' finding in a third place.

So the highlight is albedo. Columns 17..31 of the packed frame cell measured `62 82 84 83 83 77 99
103 102 100 98 102 77 72 50` — one peak, ends 12 counts apart, so `lathe_uv`'s whole turn in u wraps
it with no step worth seeing; rows 168..314 are the stretch with no bolt on it. Measured on the
shipped atlas along the leg's own UV ring: **luma 49..98, spread 48.8, sd 18.29**, against the grip's
flat 96..98 (spread 1.9, sd 0.79).

Wheels took the same free route in the other direction — cell 3 is the perforated plate and the
inside of a HOLE is the darkest thing on the sheet. Tread now samples **47.4** against the frame's
96. Not one pixel of new art.

**Verdict: landed.**

## A bevel strip is a zero-area triangle, so it takes ONE texel

Chamfering the trays regressed `propstat` to **8 smears on the trolley and 24 on the shelving**. The
cause is already written down one function away, in `brace`'s own docstring: a piece standing at an
angle projects to a LINE on the two axes `unwrap` measures it by, so a stated window is a zero-area
triangle spanning the whole rect. `bl.chamfer` was handed `I_PLAIN` (14 x 12 texels) where every
other build script's `I_PLAIN` happens to be a single texel. `I_STEEL` — 0 smears.

Also worth the line: subdividing a face makes its ARRISES longer to bevel. `PLATE_CUTS 2` plus
`segments 2` put the shelving at **948 tris against 324**; one cut and one segment land it at 528,
and the extra vertex the bake actually needs is the centre one either way.

**Verdict: landed.**

# Facility pass 6 (2026-09-15)

## The bucket's bail went through its own wall

> SUPERSEDED by "...and then it stood proud of the bucket on both sides" below — the radius stated
> here is the one that overshot.

Reported: "bucket handle intersects with body and is visible from outside." It did. The arc was an
ellipse of x-radius **0.268** about the axis with its ends at z 0.500, and the vessel's outer wall at
that height is ~0.283 against a rod 0.022 thick — so the rod spanned radius 0.246..0.290 and crossed
the sheet.

**It cannot be fixed by nudging the radius**, which is the part worth recording. A half-ellipse
starting at 0.268 hugs the taper all the way up: at z 0.545 the rod is at 0.294 against a wall at
0.285, still through it. The arc has to START AT RIM HEIGHT — above z 0.600 nothing on the vessel
stands wider than the return leg's 0.285 — and 0.322 is the rim's own 0.300 plus the rod's 0.022, so
the bail touches the roll and never enters it, which is what a bail hooked over a rim does anyway.

**The rise is 0.217 and not a half circle's 0.322**, and that is not taste: `Models.instanced` scales
a batch by HEIGHT ALONE. Swept as a half circle the prop measured 0.9491 tall against `JAN_BUCKET_H`
0.84, so the vessel would have come back 12% smaller to make room for its own handle. At 0.217 the
apex lands at 0.8361 and only `JAN_BUCKET_W` moves, 0.60 → 0.68 — the bucket is now wider than it is
deep, by its handle.

Verified by dumping the built glb: the closest bail vertex to the sheet is **+0.0064 outside** it.

**Verdict: superseded — right diagnosis, wrong sign on the fix.**

## ...and then it stood proud of the bucket on both sides

Reported next: "bucket still wrong — now bail goes outside on both sides." It was, and the arithmetic
is the same line read the other way. **0.322 was the rim's 0.300 PLUS the rod's 0.022**, so the rod's
OUTER skin reached 0.344 on a vessel 0.300 wide and the bail became the widest thing in the prop —
`JAN_BUCKET_W` going 0.60 → 0.68 was the measurement saying so, and it was recorded as a feature.

**The rod's radius belongs inside the rim's, not outside it.** `ARC = 0.300 - ROD` puts the rod's
outer skin flush with the widest point of the roll: exactly as wide as the bucket and no wider. The
ends then sink to z 0.592, where the roll is 0.298 outside and 0.285 in, so each end cap is buried in
the SOLID between the vessel's two legs rather than ending in mid air over the bore — the closed-shell
rule doing a second job. Measured on the built glb: the prop's max |x| is **0.300**, i.e. the bucket's
own radius to four places, and the lowest bail vertices sit at r 0.2974 between those two legs.

The rod also went **30% thinner**, 0.022 → 0.0154, which is a proportion question and not a fix: at
0.6 world units the old rod was a 0.044-wide bar on a 0.6-wide bucket.

Rise re-fitted to 0.231 about the new z0 so the apex holds the height the bucket already ships at —
0.8363 against 0.8361 — because `Models.instanced` still scales by HEIGHT ALONE. `JAN_BUCKET_W` goes
back to 0.60 and the prop is square in plan again.

**The transferable rule: a clearance that is stated as a SUM is a clearance in the wrong direction.**
Both failures were the same expression; only the sign of the rod's own radius differed, and each time
the measurement that would have caught it (the prop's bbox against the vessel's) was taken and then
explained away.

**Verdict: landed.**

## `lathe_uv` parametrises u by atan2, which is only linear for a circle

Reported as "broom - texture error on the back: gray part". Diagnosed off the BUILT glb by splitting
it into connected pieces and reading each one's uv range (glTF v is 1 − blender v):

```
head      156 tris   u 0.2599..0.4159   v_blender 0.0976..0.5937
bristles  124 tris   u 0.0495..0.2877   v_blender 0.2314..0.4980
shaft      28 tris   u 0.2599..0.4980   v_blender 0.5020..0.9980   <- exactly R_WOOD, correct
```

`bl.cell(2)` ends at **v 0.498** and `bl.cell(0)`, the bookbinding cloth, starts at 0.502. The head
ran to **0.5937**, so its back really was sampling a different cell, and the cloth is that exact
grey-blue. The bristles show the same fault in u: `R_BRISTLE` ends at 0.240 and they reach 0.2877.

The cause is not the transpose and not the cell layout. **`lathe_uv` takes u from `atan2`**, which
matches position round the section only for a circle. The broom's cross-sections are
`roundrect(0.29, 0.075, …)` and `roundrect(0.31, 0.090, …)` — nearly 4:1 — so several faces trip its
`max(a) - min(a) > 0.5` seam test, and the `t + 1.0` those get pushes u past the rect's edge. On a
lone cell that is invisible (the sampler wraps); on a PACKED SHEET it is the neighbouring cell. The
head then transposed that overshoot into v and walked it out of the row entirely. The shaft is clean
only because 8 uniform sides land t exactly on eighths.

**Fix: `buildlib.shell_uv`**, which takes u from ARC LENGTH round the section and reads the face
grid out of `tube`'s own construction — `side` is built `for k in bands: for i in n` and each face as
`(lo[i], lo[j], hi[j], hi[i])`, so a face index IS its (band, segment) and a LOOP index is its
corner. Nothing is recovered from a position, the seam is a real vertex boundary, u closes at exactly
1.0, and no vertex can land outside the rect. `swap=True` does the quarter turn INSIDE the rect and
replaces `janitor_build.transpose`, which is deleted. Corner stretch goes with it for free.

Re-dumped: all three pieces now inside u 0.002..0.498, v 0.002..0.498. 308 tris, unchanged.

> Latent and NOT fixed: `basin_build`, `chair_build` and `toilet_build` lathe roundrects through
> `lathe_uv` too. Their aspects are ~0.5-0.7 against the broom's 0.26 and all three ship reading
> correctly, so they stay on the old path.

**Verdict: landed.**

## The storage pair, second pass: thinner, holed underneath, braced, and on wheels

Five reports against the two props pass 5 built, and all five are the same class — a hand-modelled
prop that answers the silhouette question can still be a box assembly in every detail.

**Shelves too thick.** `PLATE 0.06 → 0.03`. Six texels of a 512 cell, still two rows of pixels over
the thinnest thing that reads. `DECO_SHELF_PLATE_Y` is DERIVED from it (`RAIL_T/2 + PLATE - 0.02`
over `SH_H`) and had to follow: **0.0398 → 0.0283**, or every box the clutter pass stands on a shelf
floats a plate's thickness.

**"use the same texture with holes for shelf bottoms."** A punched plate is punched from below too;
the underside was the plain swatch for no reason but that nothing asked. `plate()` grew an `under`
rect, mapped on the same axes and window so the holes line up through the plate.

**"thin side struts between vertical lines" — the long sides carried NOTHING.** Four uprights, two
end frames, and not one member spanning between them. They now take a tie at each of the four levels
and one diagonal, in lighter section (`TIE_T = RAIL_T * 0.62`).

> **The ties stop INSIDE the uprights and not at the end rails.** Run to the full width they cross
> the end rails at the four corners with both lids on ONE plane — sixteen z-fights. Ending on the
> upright's inner face and buried 0.02 past it leaves no coincident plane anywhere, and it is what a
> real bay does: welded to the post, not lapped over a rail. Their 0.09 thickness is also not free —
> it is what keeps the diagonal's flanks the 0.02 clear of theirs that `BRACE_D` was fitted for.

The long-side braces forced `brace()` out as a function, and the reason is a `place` trap:
**`bl.place` pitches about x BEFORE it translates**, so a bar already standing off-centre in y swings
instead of tilting. The end frames' version got away with being built in place because its y centre
was 0. Built at the origin and placed afterwards, both work.

204 → **324 tris**, dims unchanged, holes 0 / coplanar 0 / 0 smears.

**"trolley is garbage - no curves anywhere including the wheels, handle is not really connected,
shelves are too thick. reused same texture with holes? trolley has no holes."** All four:

- `N = 8 → 16`. At 0.05 radius an eight-sided leg is an octagonal post with four lit facets.
- **The castors were bollards** — a vertical cylinder r 0.105 x 0.14. A wheel is a lathe about the
  axis it ROLLS on, so it is turned flat, skinned, then pitched a quarter (`place`'s x-pitch maps the
  lathe's own z to −y), and hung off a stem NARROWER than the tread. A fork wide enough to straddle
  the wheel is a box with the wheel inside it, which at this camera is a block again.
- **The grip's axis sat on the posts' top FACE**, so half of it floated above them and the join was a
  T of two cylinders. It is now one bent tube swept up each rear post, round a 0.13 bend and across,
  with its ends buried 0.06 inside the legs at a SMALLER radius — equal radii would put two
  coincident cylinders in the overlap. The crown sits a radius under `TR_H` for the same
  height-scale reason the bucket's bail was flattened.
- **The tray came off the perforated cell.** It was given the shelving's holes because the sheet had
  them. `store-sheet.png` repacked: cell 2 is now `facility/table-top`, the LAB BENCH'S OWN WORKTOP,
  ring stains and all — the trolley in the room wears the same surface as the benches beside it.

268 → **740 tris** against the TRELLIS bake's 5,915. Dims 1.98 x 0.902 x 2.0, unchanged, so
`KIT_TROLLEY_W/D` hold. One `check` finding: at `WHEEL_W 0.07` the wheel's two discs sat 0.0075 off
the stem's flanks — eight near-coplanar pairs — so the wheel is 0.09 wide, which reads better anyway.

**The sub-rect, and why `--repeat` could not say it.** At `BENCH_TOP_TILE 5.0` a 1.98 x 0.902 tray
wants **0.396 x 0.18 of ONE repeat** — less than one, which `tools/modelsheet.py` cannot express. So
cell 2 goes in at 1x1 and `C_TRAY = bl.sub(bl.cell(2), 0, 0.396, 0, 0.18)`. That is 203 x 92 texels
over the tray, ~102 per world unit against the shelving plate's 121 — the same density, which is the
point.

**Verdict: landed.**

## The red drum, measured on the pixel that ships rather than on the source

Reported again ("desaturate red barrel, really pops out") after pass 5 already halved it. The place
to read this is the atlas EMBEDDED IN THE BUILT GLB, not `drum-sheet.png`: `sat` is applied by
`tools/models.mjs` at build time, per label, over a sheet three drums share.

| prop | its cell | rgb | chroma | luma |
|---|---|---|---|---|
| `drum-rad-hand` at sat 0.5 | 2 | 143.9 / 76.1 / 69.9 | **74.0** | 90.0 |
| `gas-rack-hand` (graded the same day) | 0 | 152.6 / 100.5 / 80.8 | 74.5 | 108.6 |
| `janitor-bucket` | 3 | 72.8 / 81.4 / 87.9 | 15.2 | 80.0 |
| `lab-trolley-hand` | 2 | 78.7 / 85.1 / 72.3 | 12.8 | 82.8 |

So it was not merely the loudest thing in the compound, it was **tied with** the loudest and hotter
in hue. `sat 0.5 → 0.3` lands it at **125.3 / 83.1 / 80.0, chroma 45.3**, luma 91.8 — the Rec.709 mix
holds luma by construction, so no second knob was needed and none was added.

**Verdict: landed.**

## A rim is a CONTOUR, and it is a different term from the edge wash beside it

> SUPERSEDED by "the contour was rejected on looks, and baked AO did the job instead" below. The
> diagnosis of WHY the bottles blend still stands and is not repeated there; the term shipped here
> does not.

Reported: "new gas cylinders really blend together because of the lack of rim effects... i don't want
MODEL changes, i want balloon edge thin lines done with something."

Why they blend, stated before anything was changed: four identical bottles 0.096 apart, and **nothing
in the indoor lighting can separate them**. `IndoorMask`'s only directional term is
`1 + bounce * dot(N, up)`, which leaves a VERTICAL face untouched at any value; the hemisphere light
keys on `normal.y` alone; there is no camera-side fill anywhere in the rig. Two cylinders side by
side get identical shading on their facing flanks by construction.

**And raising the existing wash would have made it worse.** `PropEnv` already injects a Schlick edge
term at pow 5 with a 0.08 floor — a fill over the whole prop, fitted so a flat panel does not go
black. A broad edge term lifts BOTH flanks of a seam evenly and welds the pair harder. What reads as
two objects is each bottle carrying its OWN line with the dark gap between them: bright, dark, bright.

So the contour is a second term on the same dot product at a completely different exponent —
`propEnvRim * pow(1 - dot(N,V), propEnvRimPow)` added beside the wash, three new uniforms, three
instructions, and the `customProgramCacheKey` string unchanged.

**Fitted live on the gas rack over its own 45,225 pixels** against the same frame with the term off,
cam pinned by the rig itself. The two knobs turn out to be INDEPENDENT and that is the useful part:

| rimStrength / rimPow | pixels lifted > 25/255 | peak lift |
|---|---|---|
| 0.35 / 24 | 1.44% | +165 |
| 0.70 / 24 | 1.79% | +199 |
| 1.20 / 32 | 1.57% | +215 |
| 2.00 / 40 | 1.48% | +224 |

The lifted FRACTION never leaves 1.4-1.8% — the same line — while the peak climbs. `rimPow` sets the
line's WIDTH and `rimStrength` its BRIGHTNESS. Past pow 24 the line goes SUB-PIXEL at the rig's
distance and breaks into a dotted crawl, which looks like noise rather than a contour. **Shipped
0.9 / 18**: the widest setting that is still a line and not a wash, at the strength where four
bottles read as four objects. +0 draw calls, +0 programs, uniforms only.

`PropEnv.apply` reaches `FacilityKit` and `FacilityJanitor` only, so this lands on the gas rack, the
trolley, the broom and the bucket. `FacilityDeco`'s prop batch (the drums, the shelving) is one call
away and deliberately left off — it is a visible change to every deco prop and wants its own look.

**Verdict: rejected on looks — "too bright and too pixelated". Removed.** See below.

## The contour was rejected on looks, and baked AO did the job instead

The fit above is sound and the term still went out. Reported on seeing it: *"rim looks too bright and
too pixelated, remove it. lets try baked ao instead."* Both halves of that are visible in the sweep
table itself, read the other way round — a line whose lifted fraction is **1.4-1.8% of the prop** is
by construction a line one to two pixels wide, so at the rig's distance it is a chain of lit pixels
rather than a contour, and the only knob that widens it (`rimPow` down) turns it back into the wash it
was built not to be. **A screen-space contour on a prop this small has no width to spend.** That is
the finding, and it applies to any future edge term at this camera.

**AO is the other answer to the same question, and it is a better one here.** The wash, the glint and
the contour are all view-dependent terms standing in for an environment; AO is the only term in the
pipeline that darkens a place because of the SHAPE around it, which is exactly what the gap between
two bottles is. `tools/models.mjs` has baked it into `COLOR_0` since the TRELLIS props (`ao` in
`art/models.json`), so this is a manifest key and not a shader: **zero draw calls, zero uniforms, zero
texture memory**, one `USE_COLOR` program permutation that the warm chain already covers.

`facility/gas-rack-hand` takes **ao 0.55, aoRes 128**. The resolution is not a default worth taking:
the voxel cell is `span / res`, so at res 72 over this prop's 3.0-unit span a cell is 0.042 and the
0.096 gap between two bottles is TWO CELLS — the crevice the term exists for would be inside the
grid's own error. 128 puts four cells in it. Bake cost 121 ms.

Measured on the built glb, 1822 vertices: COLOR_0 runs **0.45 .. 1.00**, median 0.977, and round one
bottle's shoulder ring it swings 1.00 on the exposed side to **0.45** in the gap.

Measured live, A/B on the same pinned frame by toggling `material.vertexColors`, over the two racks'
own **36,150 amber pixels**:

| | mean | sd |
|---|---|---|
| AO off | 88.24 | 7.82 |
| AO on | 82.74 | **10.95** |

+40% shading variance over the prop. Read along one scanline across a single bottle, AO off falls
`95 91 90 91 85 85 84 84 83 82` — a 13-count roll over the whole cylinder — against AO on's
`95 91 90 91 84 83 80 76 71 63 60`, a 35-count falloff with its darkest point ON the seam. **The
contour lit 1.8% of the prop; AO modulates all of it**, which is why one reads as four cylinders and
the other read as four cylinders with wires round them.

`facility/lab-trolley-hand` takes the same 0.55/128, restoring what the TRELLIS `facility/lab-trolley`
it replaced had shipped with — an open frame is the case the bake was added for, since no light in the
game reaches the inside of one.

**Verdict: landed. The rim term and its three `PropEnvOpts` fields are reverted out.**

## The hangar stops being a shed with nothing in it

The compound's third structure was a wall ring, a run of fake bay doors and a flat field of concrete.
Four things changed at once: it is the size it used to be, it walks a tree of its own, it has a set
piece in the middle of it, and the floor round that set piece is dressed.

**IT WAS TAKING ITS WHOLE PLOT.** `gen.Subdivide` hands out 16..34 on each axis and
`FacilityGen.fill` gave the hangar all of it minus a 1-cell inset, so the shed came out anywhere from
14x14 to **32x32** — at the top of that range larger than either lab building. The retired arithmetic
in `game.FacilityAreaGenerator` sized it `Std.int(area.width * 0.2)` = 13..15 wide. New
`HangarBlock.HANGAR_W/H` = **16 x 14**, centred in the plot, and the slack stays the open lot the
grid was blanked to — which is the apron the hangar has never had one of its own. Interior floor
14 x 12.

**THE ZONES SPLIT INTO CARVED AND DEALT, and that split is the washroom's.** `gen.Quota` can say
"this bay is a server bay"; it cannot say "arrange four machine banks around the thing the cables run
to", because that is a statement about the floor's CENTRE and no `must` over a bay can express it. So
`study-pad` and the four `hangar-machine` banks are carved before the deal — exactly as
`FacilityToilet` puts its divider in before it measures the wall runs, so they remove cells rather
than fight them — and only the perimeter ring goes to `HangarZones.demands`.

**BOTH RACK BAYS LANDED ON THE SAME WALL, every compound.** All four corner bays are three cells, so
they tie on area, and `Quota.best` breaks a tie by taking the first — which is whichever wall
`walls()` emitted first, i.e. always the top. Fixed with a `fit` that is a hash of the bay's own
corner rather than a roll, so it does not depend on how often `fit` is called.

**THE COMPUTERS ARE THE OFFICE'S OWN WORKSTATION PASS, not a second one.** `hangar-console` writes the
laboratory's worktop tiles and `FacilityWork.at` — already a pure function of those tiles and the wall
behind them — was widened by one clause. It is let in BY NAME (`FacilityModel.inHangar`) and not by
surface: the console reads back as `Surf.TILE`, and widening the gate to TILE would stand a
workstation on every lab bench in the compound. `FacilitySink` needed the same exclusion for the
mirror-image reason, and did not get it first time round: a plumbed basin appeared in the middle of a
shed floor.

**THE PODIUM IS DERIVED, NOT SPAWNED.** Nothing new is stamped on the tiles: the pad is
`TILE_FLOOR_CONCRETE_UNWALKABLE`, which three separate arms of the generator also write, and
`FacilityModel.findPads` tells them apart by the one property only the pad has — it is the only
SQUARE of it. So the podium needs no Const tile, no `entities64` frame and nothing in the save,
and every compound already generated grows one the moment it is drawn again.

`facility/hangar-podium`, hand-modelled, **540 tris**, 17.2 x 17.2 x 3.07, `z_min` 0,
`buildlib.check` 0 holes / 0 coplanar. ONE lathe for both steps and the tread between them — a lower
step with a lid and an upper step with a floor is two discs in one plane, which is what shipped both
server racks full of holes. Three of the sheet's four cells are on the one piece, per the per-face
rule: port band on the lower riser where the cables go in, tread plate on the tread and the upper lid,
bolted panel on the upper riser.

**THE CABLE FAN COSTS NO DRAW CALL.** `FacilityCable` already owns a ribbon emitter and a mesh to put
ribbons in, so this borrows the buffer the way `FacilityWork`'s desk leads do. What it adds over a
floor lead to a standing unit is the SPAN — a lab lead crosses a metre and these cross four — which
is two constants and not a second emitter. The runs stop at the dais RIM rather than its centre, so
the last span arrives at the port band instead of climbing over the tread.

Measured in a built compound: **60 FPS, 104-127 draw calls, 55-85k triangles**, the podium one batch
of one. `make gen seeds=3000` clean with a new `GenCheck.hangarSane`.

**Verdict: landed.**

## An emissive band on a hand-modelled prop is PAINTED, not raycast

`tools/emissive.py` selects triangles by a bounding box and rasterises their UVs, and it exists
because a TRELLIS atlas is a mosaic nobody can read by eye. A hand-modelled prop is the opposite
case and the tool is the wrong instrument for it.

Three boxes were tried on the podium's eight emitter columns — the band (`y 1.9..2.4`), the caps
(`2.8..3.1`), the whole column (`1.2..3.1`) — 64, 112 and 240 triangles selected, `bleed 0` every
time, and all three came back as the SAME **238 lit texels: a 256 x 1 hairline on the cell seam**,
0.091% of the map in each case. A number that does not move when the input quadruples is not
measuring the input.

The fix is that it never needed measuring. `buildlib` put the columns on a KNOWN cell of a known
sheet and `unwrap` maps each column's height up that cell's v, so the band is a rectangle that can
simply be stated — `models-src/facility/podium_emissive.py`, 20 lines of PIL, `v 0.08..0.26` down
`cell(2)`, `emissiveStrength` 2.0 against the guard booth's glazing at 1.4.

**TWO TRAPS COST MOST OF THE TIME AND NEITHER WAS THE PROP.** A glb accessor can be INTERLEAVED, and
an ad-hoc reader that ignores `byteStride` reads POSITION where it asked for TEXCOORD_0 — which
reported the podium's UVs as raw world coordinates spanning -8.6..8.6 and sent the whole diagnosis
after a mapping bug that did not exist (`tools/emissive.py`'s own `acc` handles it; the throwaway
script did not). And glTF's v origin is the image TOP where Blender's is the bottom, so sampling the
base texture at `(1-v)*H` put every face in the opposite quadrant and made four correct mappings
look like four swapped ones.

**AND A PROP WITH A WORKING EMISSIVE LOOKS BROKEN OVER CDP.** `playerArea.moveTo` does not rebuild
the player's FOV, so a teleport leaves the shed unlit and the brightest thing in the scene renders
black. `Game.turn()` is what lights it. Four screenshots were read as "the glow does not work"
before that.

Also measured on the way past, and not acted on: **every hand-modelled prop in the repo ships at
`roughnessFactor` 0.72** — `buildlib.material`'s own default — so `Models.toLambert`'s `rough < 1`
test keeps all of them on `MeshStandardMaterial`. The 31.4 -> 20.3 ms Lambert win is being left on
the table by the whole Blender route, not just by this prop.

**Verdict: landed. `tools/emissive.py` is for generated atlases; a packed-sheet prop states its own rect.**

## The register nobody kept: a prop's shipped albedo, and the chair that sat in its own bench

Four reports at once, three of them one bug: a cup and a paper tray reading bright, the barrels
and the newest fitting "looking like they have albedo issues", chairs standing inside the hangar's
consoles, and the shed's cables stopping short of its server racks.

**`tools/propstat.py` WAS MEASURING THE WRONG PIXEL, AND THAT IS WHY THE SAME PROPS KEEP COMING
BACK.** `sat` and `lift` bake into the built map, but `baseColor` is a **linear multiply applied at
render**, and nine props carry one. The tool printed the bare atlas, so every value note in
`art/models.json` had to redo the arithmetic by hand — `facility/desk-mug` read **185 in the atlas
while shipping 122** — and three of them then drifted apart unseen. It folds the factor in now, in
linear light, and `--audit` prints the whole register sorted by shipped luma. The mug trio measured
**95.2 / 104.9 / 114.9** on three objects whose entire design is that they differ in HUE and not in
level; levelled to 99.4 / 99.6 / 100.1, chroma 6.4 / 11.8 / 24.4.

**THE CUP WAS DEFENDED WITH THE WRONG RATIO.** Its second pass fitted luma 125.8 and argued "still
comfortably the lightest thing on the desk (the laminate reads ~98)". The laminate is srgb 94.7 /
**linear 0.1168**, so 125.8 was 1.33x in bytes and **2.1x in light**. 100 is one notch over it.

**A SHEET SHARED BETWEEN ONE PROP'S OWN SURFACES NEEDS A RECT, NOT A KNOB** — new `gradeRect` in
`models.json`, `tools/cellgamma.py`'s job for models. `facility/desk-tray` carries a paper sheaf at
**165.6** in a tray body at **59.6** off one map, while its own sheetmate `facility/desk-journals`
had had its page edges graded to 92.1 in the pixels: the gamma that brings the paper to 95 takes the
body to **10**. `scale` is LINEAR on purpose — the gamma that reached the same level took the
paper's chroma from **53 to 65** and left an ochre card. Graded 0.30 / sat 0.50 -> 97/91/83.

**THE "STEEL" BARREL WAS A BLUE BARREL, AND ITS OWN NOTE CERTIFIED IT AS THE NEUTRAL** the other two
were being brought to. Cell 0 of `drum-sheet.png` is rgb 23.7/66.2/108.1, **chroma 84.4** — after
both siblings were graded it was the loudest surface of the three (84.4 vs bio 74.9, rad 45.3). It
was the one drum nobody had put a knob on. `sat` 0.25 -> chroma 20.9, luma held at 66.9 by
construction. Levels: rad 98.7 -> 80.8, bio 89.6 -> 79.9, `deco-shelving` 93 -> 83.7.

**A CELL MEAN IS NOT WHAT A PROP WEARS.** `store-sheet.png`'s three cells measure 54.7 / 73.5 / 77.5
and the shelving off them sampled **93**: a hand-modelled prop maps narrow WINDOWS (its uprights are
columns 4..31 of cell 0). Only the UV-sampled number is honest.

**THE CHAIR BACKED OFF A DESK DEPTH THAT ONLY OFFICES HAVE.** `FacilityTables` cuts `CELL - DESK_D`
off the open side for `office` cells *and nothing else*, so a laboratory worktop — and the hangar
console, which is laid in those same tiles — fills its cell edge to edge. `FacilityWork.chairs`
derived its face from `DESK_D` unconditionally: face 0.8 against a real 2.2, putting the chair
**0.53 inside the worktop**. Derived per surface now; the gap is 0.22 either way, which is the point.

**AND THE CABLE FAN LEFT THE MIDDLE OF A CELL, NOT THE UNIT IN IT.** `FacilityDeco` slides every
fitting back onto its wall FACE, so a `DECO_RACK_D` 1.2 rack in a 4.0 cell ends **0.8 short of that
cell's centre** — the run started in open air in front of the rack. It starts at the rect's own
centre now, which is inside the box, so the first span is hidden by the thing it comes out of. The
machine banks never showed it: at 2.8 square their rect swallows the cell centre already.

**Verdict: landed. The atlas is not the shipped pixel, and a cell mean is not what a prop wears.**

## The shed's second machine, and a sheet cut to the faces rather than faces cut to the sheet

`HangarBlock` carves four machine banks at the study pad's compass points and `FIT_MACHINE` is a 2.8
CUBE, so a shed read as one object repeated four times. Reported as "we have only one machine".

**A REPAINT COULD NOT FIX IT, AND THE DRUMS ARE WHY.** Three hazard barrels ship as three labels off
ONE mesh because a drum's read IS its colour; a machine's read is its silhouette, and a recoloured
cube is still a cube at forty screen pixels. So `facility/deco-analyser` is a second SHAPE —
**648 tris, 2.060 x 1.680 x 3.3134**, holes 0, coplanar 0 — breaking at four courses (plinth, body
with a proud port plate, recessed vent band, cap) under a sloped operator face, which nothing else in
the compound has.

**NOT THE 4.0 IT WAS DRAWN AS.** `PLACARD_W`'s note fixes `DECO_CABINET_H` 3.43 as the tallest thing
that can share a room cell — the placard band runs 3.85 to 5.65 and is meant to need no check against
any other builder's placements. 3.31 keeps that and is still the tallest thing in the shed after the
podium's 3.07.

**THE FACES ARE CUT TO THE ART'S ASPECT, NOT THE OTHER WAY ROUND**, and that is the finding worth
keeping from this one. Every face here maps its cell 0..1 and cannot wrap, so an aspect mismatch is a
stretch with nowhere to go: the console face is **1.75 x 1.15 (1.52)** because that cell's content is
about square and a 2.06-wide strip turns its dials into ovals, and the port plate is **1.40 x 1.05
(1.33)** for the same reason. The vent band is the one face allowed to stretch — its art is
horizontal slats, so a horizontal stretch is invisible. `tools/modelsheet.py --repeat` is the other
answer to the same problem and it is the wrong one here: it tiles the cell, and three copies of a
gland row is not a port panel.

**THE PITCH SIGN COST A RENDER.** `buildlib.place` turns about +X, so a front face's `(0,-1,0)` goes
to `(0, -cos a, -sin a)` — at **a = +45 the instrument art looks at the FLOOR** and the plain back of
the slab is what the camera gets. Measured off the exported UVs, not guessed: the big face came back
with normal `(0,-0.71,-0.71)` on the right cell. `-55` gives a plane 35 degrees off horizontal.

**AND `chamfer` REPLACES THE FACES IT IS HANDED**, so a face found before it is dead by the time
`flat_uv` writes UVs (`ReferenceError: BMesh data of type BMFace has been removed`). The console is
built FIRST, into the empty bmesh, so the big face can be found again afterwards by normal.

Wiring: `FIT_ANALYSER = 16`, and **row 8 col 5 MOVES onto it** rather than being copied — that frame
is the analyser console the machine's own five frames already listed, and two kinds claiming one
frame is a coin toss in `FacilityModel`. New `DecoLedOpts` replaces `machLights`' nine positional
args, because the two machines' runs differ in exactly four values: this one's lamps are the PAINTED
LENSES of its port cell, at u 0.0898/0.2324/0.3818/0.5273/0.6670/0.7939/0.9131 and v 0.4766,
measured off the built sheet's darkest 8% and carried onto the face through the plate's 0.68 of it.
Dealt **per BANK and not per cell** at 50%: rolled per cell a bank is a cube beside a console, which
is what a compass point should not read as. Measured over 40 oracle seeds: 148 analyser cells against
172 machine, 8 per compound.

**Verdict: landed. A machine is told apart by silhouette, so a second one is a second mesh.**

# 3D render changes — running log

Append-only. One entry per experiment, ~25 lines: what changed, the measured numbers, the trap, the
verdict. Settled outcomes only. Every entry needs a matching row in
[`3d-render.md`](3d-render.md)'s verdict table, or it is invisible. Earlier entries are in
`3d-changes-2026-10.md` and its predecessors.

## Lab vats and lift: hand-modelled frames, TRELLIS clones, drain and descent as render state

**Changed:** `render.lab.LabVats` draws each 2x3 `CloneVat` group as FIVE batches over one placement
per group: the opaque frame (`vat_build.py`), the clone floating in it and the clone heaped on its
floor (TRELLIS, organic, `decimation_target` at budget + `tris: -1`), the growth medium and the glass
(both transparent). Not an `ObjModels` row: six objects make one vat and a row places a prop per object.
`render.lab.LabLift` stands the shaft and the car (`lift_build.py`) over the model's `Surf.LIFT` cells.

**Measured:** vat frame 1,076 tris, shaft 812, deck 428, all 0 holes / 0 coplanar / 1 island.

**The drain is render state.** `isFlushed` flips on the purge turn; the medium eases out over
`BASE_MS * VAT_DRAIN_MULT` by scaling its height. The eased value is in a map the AREA owns
(`LabArea.drain`, keyed on the root object), so a `refreshObjects` rebuild mid-drain picks it up where it
was, and a fresh build seeds it from the saved flag so a drained vat never replays.

**The car comes down on arrival:** built `LIFT_DROP` up the shaft, lowered over `BASE_MS * LIFT_MULT`;
`WorldCtx.ground` answers the deck for the lift cells so the player rides it. `held` keeps it at the
top while the entry's message boxes are up, or the descent plays behind them unseen.

**The trap:** the mission stands the vats on its FIRST TURN, after the area is built. Anything that
reads the vat set at build (the drain map, the sounds' cells) has to take the rebuilt set, not hold
the empty one.

**Verdict:** landed.

## Lab furniture and box machines: one two-cell sheet per glb, not one shared sheet

**Changed:** `labkit_build.py` (twelve furniture pieces) and `boxkit_build.py` (nine box machines and
the sealed storage container) build the lab's slab-shaped pieces in Blender from scripts, per
docs/3d-models.md's fourth route. Each box machine wears its OWN two-cell sheet (its authored front
plus the shared carcass cell, packed by `tools/modelsheet.py` at 1024 x 512). A wide face is split into
modules that each wear the face whole, so square art never stretches. `LabInterior` backs each piece
onto its wall; facility workstations stand on the lab desks (the one permitted reuse).

**The trap:** a glb EMBEDS whatever sheet it wears. One shared nine-face sheet would have shipped nine
copies of all nine faces. And a SQUARE wall machine on a side wall failed the backing test, which only
probed the long axis: check both axes when w == d.

**Verdict:** landed.

## Lab machinery generated: 60 TRELLIS glbs off the 2D sprites, dropMR on all of them

> SUPERSEDED (all but the clones, plants 2/3/5 and the suits) by Lab machines rebuilt by hand: 46 Blender pieces off their references, ten agents in parallel

**Changed:** 66 kinds were briefed. Each 2D sprite crop went through `edit_image` (gpt-image-25
sunburst, `style_prop`, flat black, isometric) and then TRELLIS at decimation 6000. 60 shipped as
`lab/<kind>`, value-fitted to indoor luma ~78 (sheeted pieces ~100, hazmat suits ~95). Fronts are
turned into the room per kind (`turn`).

**Measured:** most glbs got a propstat `largest under 90%` REJECT and were accepted by eye at four sides:
the split pieces are a machine's own parts (a lid, a cable, a tank), not a blob cloud. Programs held at
82 only after `dropMR` went on every entry.

**The traps:**
- ONE glb (plant6) kept `MeshStandardMaterial` (roughness 0.996) through the build and compiled a
  program of its own. `dropMR: true` on the whole family is cheaper than finding which one did it.
- **A raw 2D sprite fed straight to TRELLIS comes back as a FLAT CARD**: bbox depth 0.002 on three of
  six, the rest blob clouds (largest component 43-52%). The `edit_image` step is what makes it an object.
- A kind dealt with no glb draws nothing and still BLOCKS its cells. The two lobby kinds whose refs the
  OpenAI credit ran out on (incinerator bin, scanner frame) are taken out of the deal, not left in.

**Quality notes:** ambertanks lost its amber, press came with a bench, probe came back a disc on legs,
the suits read yellow rather than orange.

**Verdict:** landed, 6 kinds (incbin, scanframe, bin, plant1, plant4, suittorn) unbuilt.

## Lab floors and bench tops dressed off packed sheets; vat slurry outside the plinth

**Changed:** `render.lab.LabDecals` deals floor grime (80 per 1000 cells) and painted marks (40 per 1000)
per room role off two pack16 sheets, and 2-4 cut-outs on each bench top off two pack36 sheets
(workshop/research). ONE MERGED MESH PER SHEET: four calls for the whole lab. `LabVats` adds a slurry
quad per vat that grows with its drain.

**Measured:** grime 39, marks 18, tops 30 on slot 1. +0 programs after warm.

**The traps:**
- The two floor sheets came back UNCUT. The prompt named a floor and the model painted one under the
  items, which is the documented trap. One `edit_image` transparent pass re-cut each sheet.
- The first slurry quad was centred under the vat and the 8x12 plinth hid all of it. It now pools
  `SPILL_OUT` 7.0 in front of the footprint's centre, out past the plinth's front edge (6 units).

**Verdict:** landed.

## Lab rooms wired with the facility's electrical, the one permitted reuse

**Changed:** `FacilityCable.build` runs in `LabArea` and `LabWarm` over the lab model. That needed two
pieces of plumbing. Lab furniture and machine cells are marked taken (`m.deco = FIT_LAB + 1`,
`_FittingKind.FIT_LAB` 21). `FacilityModel.isLabRoom` lets `FacilityPaint.freeFloor` and
`FacilityPlacard.hangs` accept lab room floors. `LabStyle.shell` borrows `FacilityStyle.CABLE_TEX` and
`ELEC_TEX`.

**Measured:** 29 mounts, 10 runs, 7 floor units, 22 scatter on slot 1; +0 calls of note, +0 programs.

**The trap:** the cable's helpers are pure functions over the model and return EMPTY on surfs they do
not know. That shows up as a lab with no sockets, not as an error. Without the `FIT_LAB` marks a socket
hangs behind a machine. Lab machines do not feed off the sockets (`feeds` false).

**Verdict:** landed.

## Lab lit: sparse role-tinted pools, an alarm strobe and a dying vat chamber; no shaft cone

**Changed:** `render.lab.LabLamps` hangs a fixture lattice per room (`LAMP_SPACING` 5 cells, the 2D
lab's role tints) and corridor strips (greedy spacing). By cell hash, 8% are dead and 10% sputter, so a
lab breaks the same bulbs every reload. A cold spotlight comes down the lift. Two live states are read
every frame and neither is saved. The ALARM (`leadTriggerDone`) turns every post red with a swell over
`BASE_MS * 2`. The LAB DIES when every vat is purged: the vat chamber's posts sputter out over
`BASE_MS * 4` and the rest drop to 0.4. Eight machine kinds glow through emissive maps, dimmed 85% on
death (`LabInterior.dim`).

**Measured:**
- Fill swept live at the gameplay camera, AMBIENT_I 2.4 / 3.6 / 5.5 / 9. At 2.4 a room is black between
  its pools; at 9 the pools flatten into the fill; 5.5 shipped (hemi 1.4 → 1.8).
- `calls=` medians: 43 on the lift, 52 lobby, 58 storage, 69 research, 73 workshop, 78 vat chamber.
- 85 programs, entry diff 0 after `warmKind`.

**The traps:**
- A shaft CONE was tried twice, as a splayed bell and as a column tube above the walls. From the
  gameplay camera, a shaft starting over the wall head reads as a ghost tube stood on the lobby, with
  its brightest end above the rock. Removed; the pool is the whole of it.
- `tools/emissive.py`'s centroid box cannot pick a screen out of a mosaic atlas without one box per
  chart. An ALBEDO COLOUR KEY (`models-src/lab/_emikey.py`: hue band, then the brightest ~20% of the
  matches) kept 8 of 24 candidates cleanly. On tubes, racks and consoles it also lit the cyan steel, and
  those ship with no map.

**Verdict:** landed. The fixture glbs and the LOCKDOWN wall screens wait on texture credits.

## Lab's last six machines generated; the room props finally dealt

> SUPERSEDED (all but the clones, plants 2/3/5 and the suits) by Lab machines rebuilt by hand: 46 Blender pieces off their references, ten agents in parallel

**Changed:** incbin, scanframe, bin, plant1, plant4 and suittorn went through the same pipeline as the
other sixty (sprite → `edit_image` gpt-image-25 sunburst `style_prop` → TRELLIS 6000, `dropMR`,
baseColor = linear 78 / atlas Ylin). incbin and scanframe are back in `LabRooms.LOBBY_FLOOR`; the bin
stands on `TILE_LAB_BIN`; the plants join the hashed pot list; one hung suit in `SUIT_TORN` 5 is the
torn one. plant1 glows off its leaves (`_emikey.py plant1 c,g 0.5 0.55 25`).

**Measured:** 5507-5990 tris each, real depth on all six (bbox depth 0.18-0.85, against 0.002 for the
raw-sprite cards). Seed 9 live: incbin 1, scanframe 1, bin 4 of 4, plants 2 of 2; 85 programs, entry
diff 0.

**The traps:**
- plant1's first roll put every leaf in ONE PLANE facing the reference camera: four-side renders showed
  bare stalks from the flanks, and from the gameplay camera, looking down, a vertical card is nothing.
  A prompt asking for leaves spreading toward and away from the viewer fixed it in one re-roll.
- The bin's orange slot and the incinerator bin's flame window did not survive the bake; the colour key
  lit the trefoil instead. Both ship with no glow.
- `TILE_LAB_BIN` was dealt in 0 of 300 levels: only a LEFTOVER bay stood props, and the quota zones
  leave one a level. `LabRooms.props` now runs per room after its zones. Its first cut used `walled()`,
  which also passes a cell out on the floor, so 3 of 4 bins stood mid-room and drew nothing; the
  oracle now fails any plant or bin with no wall beside it.

**Verdict:** landed.

## Lab walls dressed: signs, fittings, monitors with alarm twins, wall lamps off three pack16 sheets

**Changed:** `render.lab.LabWall` hangs quads on every stretch of plain masonry (CorpSigns' run walk and
its carries-both-ways rule) off `lab/wall-signs` (16 square plates, `pack16 --fill`), `lab/wall-fittings`
(16 cut-outs at one scale, alphaTest) and `lab/wall-screens` (8 monitors, 4 lamps, 4 alarm screens,
`--fill`, aspects in code, emissive off its own map). Per run: a sign per 6 cells off the room role's
list, then 70% a fitting, 60% a monitor in the vat chamber and research rooms, 45% a lamp. Every
monitor has a twin on the same quad wearing an alarm cell (LOCKDOWN, CONTAINMENT BREACH, ALERT,
SEALED) in a second mesh; `tick` swaps the two on `leadTriggerDone` and dims every glow with the death.

**Measured:** seed 9: 25 signs, 14 fittings, 3 monitors, 6 lamps; 85 → 87 programs (an alphaTest
Lambert and an emissive-mapped one), both warmed, entry diff 0. Alarm live: the DNA monitor turned
SEALED and the north wall's ALERT, programs unchanged.

**The traps:**
- Only the north, east and west walls take anything: a south wall's face looks away from the gameplay
  camera, which sees its back (the generator's wall zones avoid it for the same reason).
- A wall cell with a piece standing in front of it is skipped: a 4.4-5.4 machine backed onto the wall
  hides a sign hung at 4.6 completely from the gameplay camera.
- Fittings hang at 2.9, over the borrowed electrical's 1.7 m panels on the same walls.

**Verdict:** landed.

## Lab bench tops: standing kit at the lid's back ends, the flat clutter kept round it

> SUPERSEDED (the art, not the placement) by Lab bench-top kit rebuilt by hand: 21 Blender pieces on their own PACK4 sheets

**Changed:** `LabInterior.kit` stands one piece off `art().tops` (research list or workshop list, by
the lid's room) at a hashed end of every bench lid's back edge, and a second at the other end on 45
in a hundred. Each piece's circle (half its larger footprint side) goes into the lid's `keeps`, which
replaced `LabLid.keep`: `LabDecals.lid` starts its rejection sampling from those circles, so the
2D cut-outs lie round the glbs instead of under them. 19 TRELLIS glbs (`models-src/lab/top-*.glb`, refs
on flat black, decimation 5000) as the first set; `baseColor` per glb to the indoor ~78.

**Measured:** seed 9: 18 pieces on 11 lids (6 benches, 5 workbenches), 32 cut-outs still dealt round
them. Programs 87 → 87 (every glb a plain Lambert the lab already compiles), warmed, entry diff 0.
At the gameplay camera a 0.95 microscope reads as a white upright on the epoxy; a 0.4 mortar is a
dot.

**The traps:**
- All 19 are `propstat` REJECTs on components (largest 12-84%): a bottle cluster or a pipette stand is
  many pieces by nature. Judged by eye off `_preview.py` sheets, as the machines were.
- TRELLIS keeps the reference's yaw, so a piece's front is wherever it came back; the hashed ±0.32 rad
  turn is all the placement does about it.
- ~4,800 tris each at the 5000 floor, for objects 0.4-1.5 tall: this route costs ten times what a
  hand-modelled tabletop piece does.

**Verdict:** landed.

## Lab bench-top kit rebuilt by hand: 21 Blender pieces on their own PACK4 sheets

**Changed:** the 19 TRELLIS bench-top glbs (`LabInterior.kit`'s first set) are replaced by 21 pieces
hand-modelled through `models-src/lab/top_build.py`, ONE MODULE PER PIECE in `models-src/lab/tops/`.
Each wears its own sheet `textures-src/lab/tops-<name>.png`: a gpt-image-2.5 `edit_image` taking the
piece's own TRELLIS reference as input, four 512 cells painted for that piece's faces (a dead-on panel,
a wrap, a disc from above, a swatch), `style_prop` appended. `top_build.py -- compare <name>` renders
the TRELLIS glb beside the piece from the preview's isometric and from the game's steep camera; seven
sub-agents iterated on that render, two to four pieces each, with no paid tools. Extras on the game side:
- the bunsen's flame is FX, not geometry: `LabFlames`, the burning barrel's two frontal flame layers
  and glow, burning blue (the barrel's sprite as an ALPHA MAP under a flat blue, since its own colour
  is orange and a tint only darkens it), VisionMask-patched;
- the label printer and the centrifuge each carry a status light in `FacilityDeco.lamps`' blinking mesh
  (one speck, the compound's clock and material);
- the embryo jar and the specimen box split into a body and a `-glass` shell, drawn as its own batch,
  transparent, double-sided and depth-free (the vat glass's recipe), so the embryo and the specimen show;
- screen glow on six pieces off an emissive map cut from the piece's own sheet by rect
  (`models-src/lab/_topemi.py`), dimmed with the lab's death by `LabInterior.dim`.

**Measured:** 68-2,498 tris a piece (TRELLIS: ~4,800 each), every one holes 0 / coplanar 0 /
islands 1. Seed 9: 14 kinds on 11 lids, 2 jars behind glass; with the research list stacked in-page, 3
burners (9 flame quads) and 3 status lights. Programs 87 -> 90 warmed, entry diff 0. 21 sheets, ~$1.32.

**The traps:**
- A model sheet painted from the TRELLIS reference is what makes a hand-built piece read as that
  object; the first pass in flat colours was rejected as simpler and different.
- The steep camera decides the pose: a microscope facing it hides its arm behind the stage, an arm kit
  reaching at it foreshortens to one bar, a lamp built in one plane reads as a column. Each is turned.
- A jar's label at mid height hides what is in it: the camera sees the embryo ~0.12 above where it
  sits, so the label band moved to the foot.
- `Models.normalize` centres a glb on its bbox, so every anchor (flame, LED) and every glass shell is
  stated from the bbox centre, and a shell's base offset is restored by the row's `y`.

**Verdict:** landed.

## Lab machines rebuilt by hand: 46 Blender pieces off their references, ten agents in parallel

**Changed:** every TRELLIS machine the user rejected on sight (all of the vat room's, the research
bay's, the store's, the workshop's and the lobby's, plants 1/4/6) is a hand-modelled Blender piece:
`models-src/lab/mach/<name>.py` through `top_build.py kit=mach`, one module per piece, each wearing its
OWN PACK4 sheet (an `edit_image` off its own `-src.png`), and 27 of 46 a second sheet laid beside it
as one atlas. Ten sub-agents built them in parallel off one brief, each generating its own sheets
under a cap (2 a piece, one re-roll) and iterating on `turn` / `compare` renders against the src.
Fourteen kinds stop being dealt (`LabKinds` rooms `[]`): half the research bay's (a second empty
tube, the trolley, four consoles of one look, the scanner, clamp, probe, capsule, robot chair, booth,
analysis station) and the lobby's incinerator bin. Machines now carry glass shells and status lights
as the bench kit does (`LabInterior.dress`); a shell's own offset comes off the two glbs (`shell`).

**Measured:** 928-4,068 tris a body (TRELLIS: ~5,800 each), every object holes 0 / coplanar 0 /
islands 1 and no inside-out shell. 10 glass shells, 41 emissive maps cut off their own sheets, 28
status lights. 73 image gens, ~$3.9. Programs 90 warmed, entry diff 0. Oracle 3,000 seeds clean.

**The traps:**
- The full 2048 x 1024 atlases baked at 3.5-4.5 MB a glb, and every glass shell carried a copy of
  its body's. At the closest zoom the lab shows ~37 px a world unit; half size (1024 / 512 / 256 a
  shell) still gives ~51, at ~0.5-1.3 MB and below the TRELLIS set's VRAM.
- A lathe profile run top-down is inside out and `check` still reads 0/0/1 (the press's ram): the
  winding check sums each closed shell's signed volume after merging the export's seam-split verts.
- The workbench previews draw glass opaque: a tube's creature and a pod's embryo only show in game.
- A 2x1 footprint does not make a 2:1 thing: the first cryopod filled 6.5 as a low slab with a small
  dome, and the src is a fat rounded pod; rebuilt at 5.4 x 3.4 with the canopy over half its lid.

**Verdict:** landed.

## Lab fixes: lamps over free floor, no dark room, rock corner caps, the container's door to the camera

**Changed:** `LabLamps` ring-searches each lattice post to the nearest room cell with `m.deco == 0`
(free floor), and forces one post lit in any room whose posts all rolled dead. `LabGeom` fills the
bedrock cap's outer-corner notch where both orthogonal neighbours are wall and the diagonal is rock.
The container is rebuilt 10.6 long (castings inside the 3-cell bay's 11.2), both long sides wear the
panel, and `machine()` turns it end for end on a side wall when `away(d)` aimed its door end up it.

**Measured:** seed 768512642: the 10x6 research room (two posts, both dead before) lit; the storage
post that sat on a shelf row moved to the aisle; the rock cap covers (24,20)'s NE notch (raycast hit
at four points); the container's door end faces +z, clear of the wall. Entry diff 0.

**The traps:**
- A small room has two lattice posts and LAMP_DEAD_PCT 8 can kill both: a guarantee, not a lower
  rate, is what keeps a room from going black.
- The notch is cut on purpose (`FacilityGeom.capTop`) and filled only when the diagonal is floor;
  rock behind it left a square hole the size of the slab's arm.

**Verdict:** landed.

## Lab status lights on 27 machines and the workstations, anchors the camera can see

> SUPERSEDED by Lab machines' painted lamps blink in place, the added specks gone

**Changed:** a headless Blender pass ray-casts each emissive machine's front, keeps flat unlit faces
beside a lit texel that a ray toward the game camera clears, and writes 1-3 anchors a machine
(`lit(...)` rows). The workstation's monitor and tower go through `dress()` with FacilityWork's own
light spots. `LabInterior.leds` keeps each speck in its machine's face plane, like the compound's rack
lights, sized `max(TOP_LED_SZ, h * LED_PER_H)` and proud of the face by 0.6 of its half size.

**Measured:** 91 lights in the lab on seed 768512642; a camera-to-speck raycast finds 10/14 (vat),
24/26 (research), 3/11 (workshop) visible, every hidden one behind a wall, another piece, or on the
front of a machine standing side-on. LED_PER_H 0.02 (0.09 a speck) read as nothing; 0.03 reads. Entry diff 0.

**The traps:**
- Turning the specks FRONTAL (the world-FX rule) was tried and REJECTED by the user: a status light
  is part of the machine's face, not an effect; it never faced the camera. Frontal also saw fewer
  (9/21 vs 10/24). A light on a side-on machine's front is hidden, and that is right.
- The first anchors sat in recesses whose top lip hides them from the 51-degree camera: the anchor
  pass casts toward the lens and drops those.
- Frame-diffing the depth-tested vs untested render to count hidden specks counts BLINKS too (the
  square wave moves between screenshots). Raycast from the camera instead.

**Verdict:** landed.

## Lab frost: rime round the cold machines, on the floor and the wall behind

**Changed:** one new PACK16 `lab/frost` (transparent mode, gpt-image-25 sunburst high, `style`):
eight top-down floor cells and eight flat-on wall cells. `machine()` records cryobank, coldbank,
cryopod, stasis and sr203 footprints (`LabInteriorPlan.frosts`); `LabDecals.frost` lays patches every
FROST_STEP round each footprint (none past its wall), and on any wall the footprint touches a crust
standing on the floor at each hand and an icicled fringe over the top. One extra mesh, Lambert with
the map as a faint emissive (FROST_GLOW) so it reads in the dark rooms.

**Measured:** 73 quads on seed 768512642; +1 program, warmed (90 -> 91), entry diff 0. $0.056.

**The traps:**
- Without the emissive the frost was a grey smudge in an unlit corner; sizes 1.3 -> 1.9 too.
- The hollow ring cell stacked into a row of loops along a footprint edge: it is out of the list.
- sr203 stands a step off its wall (`k.wall` false), so wall frost keys on any touched wall, not
  only the one a piece backs onto.

**Verdict:** landed.

## Lab amber tanks: fluid ripples and bubbles on the glass, an amber lamp on the floor

**Changed:** `LabWater.patch` folds into the ambertanks glass shell (cache key `labWater`): two
crossed sine bands crawling up the pane and procedural bubbles (columns WATER_COL apart, hashed rise
and wobble) in the piece's own frame, both into the emissive at WATER_TINT and lifting the pane's
alpha. Clock is SewerWater's; `level` dims it with the lab's death. An amber `LampPost` (noCast) at
the tank front joins `posts`, dimmed the same way.

**Measured:** +2 programs warmed (91 -> 93), entry diff 0; frames 1.2 s apart differ on the pane.

**The traps:**
- Haxe prints a whole Float as an int, so a `1.0` spliced into GLSL is `1` and fails to compile:
  every constant goes in as `const float X = float(...)`.
- Amber bubbles vanish on the bright amber fluid behind the pane: they burn paler than it.

**Verdict:** landed.

## Lab shelves stocked bay by bay: eight hand-modelled stock pieces, clutter on the tops

**Changed:** the shelving's baked stocked boxes are gone (`labkit_build.py`, 204 -> 108 tris a
unit). Eight shelf-stock pieces (`models-src/lab/stock`, `top_build.py kit=stock`, one sub-agent,
one PACK4 sheet each): archive box, binders, lever-arch files, jar tray, jerrycan, document trays,
crate, bottle carton. `LabInterior.stock` deals per plate, per bay, per face (rows both aisles): an
empty bay on STOCK_GAP %, else one piece or two side by side when they fit. Each top board is a
`LabLid` (new `count`) and on STOCK_TOP % carries a standing piece. The workbench's lower shelf is a
second lid (count 2) with a short workshop piece on 40%.

**Measured:** 365-860 tris a piece, gates 0/0/1, $0.44 for 8 sheets, 0 re-rolls. 197 pieces in the
store on seed 768512642. Programs unchanged, entry diff 0.

**The traps:**
- From the 51-degree camera a tall unit shows its top board and the plate edges: what reads is the
  colour between plates on the side facing the lens, and the top. Hence clutter up there.
- `LabDecals.lid`'s hash ignored height, so a workbench's lower shelf would have dealt its top's
  clutter: `y` is in the hash now.

**Verdict:** landed.

## Lab machines' painted lamps blink in place, the added specks gone

**Changed:** the 91 specks from the entry above were REJECTED by the user ("you just added two to all in
random places"): a fixed count per machine on whatever unlit flat a ray found, against art that
already paints its own lamps. Every `lit(...)` anchor came off the 35 machine rows (the workstations'
FacilityWork spots and the two bench gadgets keep theirs). Instead `models-src/lab/_ledmask.py` finds
the lamps ON each machine's emissive map and writes a code into its ALPHA (255 not a lamp, 250 a
steady lamp, 16-239 a blinking one, the code its phase), and `render.lab.LabBlink` patches every lab
piece with an emissive map: lamps burn BLINK_GAIN 2.5 over their paint, blinking ones on a square
wave of one of two rates and a hashed duty, offset per instance by its place.

**Measured:** 233 lamps on 27 machines, 127 blinking; machines with no painted lamp get none (rack6,
rack8, processor, upw, robotarm, incubator, kiosk, generator). Switchrack from a still camera: 300 px
swing by up to 166 levels over eight frames. Programs 93 warmed, entry diff 0 — the patched pieces
share one `labBlink` key.

**The traps:**
- A lamp is a SMALL, COMPACT blob on BLACK. Screen text, fluid bubbles, fire embers and specimen specks
  are small blobs too: rejected by fill (< 0.55, a glyph), by a faint field round them (> 3x the blob
  at lum 12: a screen's ground, a fire's glow), by sitting inside a big blob's box (a monitor frame),
  and by a 14 px clearance from any big blob. Four rects per machine `EXCLUDE` the rest (incinerator
  fire, generator lettering, holo frame chips, tentacle streak, bioprinter tissue).
- The resize to `tex` rings across a hard alpha step, so each code covers its lamp plus an 8 px ring,
  and lamp texels are written last so a neighbour's ring never takes them.
- Big round lenses (the terminal's four) fail the size cap; past 700 px a lamp must fill 0.7 of its box.

**Verdict:** landed.

## Lab freight lift rebuilt by hand off its own reference: car and shaft, the beacon blinking

**Changed:** `lab/lift-deck` and `lab/lift-shaft` now point at `lab-mach-liftdeck.glb` /
`lab-mach-liftshaft.glb`, built by `models-src/lab/mach/liftdeck.py` and `liftshaft.py` (`top_build.py
kit=mach`) off one gpt-image-2.5 reference of the whole lift, each on sheets painted off it with
edit_image. They replace `lift_build.py`'s boxes on one generic sheet. The car has a diamond-plate tread,
hazard kick curbs on the open sides and a guard rail on the wall sides (posts, panel bays, toe boards,
balusters). It also carries a MAX LOAD plate, a call post with modelled buttons and a key switch,
rope clamps and a raised gate bar. The shaft has four I-beam columns on the wall sides only, with
base plates, brackets, knee braces, conduit, junction boxes and a caged amber lamp. Its head frame of
hazard box girders above the 6.0 walls carries a finned motor, a gearbox, the rope drum with
pillow blocks and brake, a cable tray, and the beacon. `_ledmask.py` gained `WHOLE`, so the beacon
dome blinks as one lamp; the caged lamp is excluded (its panes blinked apart) and the green call
button blinks.

**Measured:** deck 2,092 tris, 7.8 x 7.8 x 2.95, tread top z 0.250; shaft 4,104 tris, 9.8 x 9.8 x
10.33; both bboxes symmetric about the 2x2's centre, gates 0/0/1. LIFT_SHAFT_H 9.87 -> 10.33 and
LIFT_DECK_GLB_H 2.74 -> 2.95 (their heights); LIFT_DECK_H 0.25 unchanged. 3 image gens + the reference,
~$0.22. Live on seed 768512642: the car comes down with the player on it and lands at y 0; programs
94 warmed, entry diff 0.

**The traps:**
- Models.normalize recentres a glb on its bbox, so a lift standing in a CORNER must still be
  symmetric in plan: the head girders run the full 9.8 along both walls, and nothing on the car
  passes the plate's +-3.9.
- Nothing of the shaft may stand on the lobby sides below the head frame, or a column stands in a
  walkable cell.

**Verdict:** landed.


## Lab round 2: every box wears its own body, the container clears its wall, a seamless lift tread

**Changed:** every lab box machine (sr203, vault, drawer cabinet and chest, rad locker, cold bank,
power, lever and control boxes), the locker bank and the fridge wore `lab/kit-carcass`, one blue-grey,
on every face but the front. Each now wears its own `lab/body-<name>`, from three PACK4 edit_image gens
whose inputs are the four pieces' BUILT fronts; their wraps were closed with `seamfix.py tone`. The
locker moved to its own two-cell `lockerbank-sheet`, shows all four painted doors (three had been
stretched 1.34x) and gained a crown band, since its doors ran off the top. The drum lid wears a
drawn `lab/drum-lid`. The container's castings are 0.36 (were 0.56) and wear `lab/container-casting`.
Its corrugated BIO panel is now a flat placard, because the panel's ribs ran at another pitch than
the side's. The rad locker is 3.6 high, so its door is square. The lift car's tread is a solo regular
lug grid cropped to whole periods, and the call box's sides map whole at the front's density. The
storage wall is solo poured concrete. Frost blends at 0.5 without depth writes.
`LabInterior.machine` reads the wall face off the footprint's EDGE cell. A floor kind takes the turn
with an open front and, failing that, a walled back.

**Measured:** wraps after seamfix 3.0-9.1 (packed crops 7-43). Paint mode front vs body is within
~10 sRGB except the lever box, 102 vs 76, which got lift 1.32. Tread wrap 20.4 -> 5.7/4.5 at a
measured lug period of 99.25 x 96.65 px (10 periods, 993 x 966 -> 512). Live on seed 768512642: the
east container went from x -59.56..-53 (2 units into the masonry) to -61.56..-55 at the face; the
SR-203 faces the room with its back to the north wall; entry diff 0. 5 gens, ~$0.38 (edits with
four inputs cost $0.088).

**The traps:**
- `faceOff(col, row)` off a footprint's ORIGIN finds the footprint's own floor cell for an east or
  south wall wider than one cell: it read -1, not thick/2, and pushed the piece two units further.
- An opaque alphaTest decal set overlapping on one plane z-fights itself. The fix is blending without
  depth writes, and alphaTest then compares AFTER opacity, so the old 0.5 cut discarded every texel
  at opacity 0.5 (`FROST_CUT` 0.02).
- A "seamless" diamond plate is a lattice: no blend closes it. Only an exact whole-period crop does.

**Verdict:** landed.


## Lab round 3: fittings at their own size, a salad-green vat, chairs, a turning beacon and a fan

**Changed:** each wall fitting is cropped to its own art (`LabWall.FIT_BOX`, measured alpha bbox)
and drawn at its own height (`LabStyle.WALL_FIT_H`, 1.2 keypad to 2.8 coat hooks). One 1.4 square for
all of them drew a keypad as big as a notice board. The vat hall and store floors tile at 8.0, two
cells (`ShellTex.floorTile`), because their drain channels and painted squares walked off the walls
at the shared 7.0. Lab sockets are 0.8 of the compound's size (`ShellTex.elecScale`). The plug and its
lead go to the socket's OUTLET (`FacilityStyle.SOCK_OUTLET`, compound sheet only). On the plate centre
the plug sat between a double socket's two outlets. Frost cell 15 is out (it is an L-shaped corner).
The locker bank is 3.4 tall with a 0.1 crown, and a `board` lid on its top. Shelf plates tile their
perforation every 1.2 units. Plant5's purple glows (hue-cut emissive off its bake). Floor glows for
the tube, stasis pod, specimen case and embryonic bank come from `LabStyle.TANK_GLOW`, and the
clone vat's lamp moved out in front of its glass. The vat medium wears the 2D sprite's salad green
through `LabWater.patchVat` (swirl, warp of its own lookup, bubbles), is double-sided, and lights the
clone, which sways (`patchClone`). A task chair stands at every computer desk. The workshop gets a
ceiling fan whose rotor turns under a work lamp, and the lift's beacon swings its beam round the lobby
(`LabSpin`).

**Measured:** 4 gens, ~$0.23. Chair 872 tris, fan 316 + rotor 508 tris, 0 holes and 0 coplanar
after two fixes. Seed 768512642: 73 frost quads, none on cell 15. The vat frame diff over 2 s is 20.5
against 0.06 on the floor. FPS 75 (cap) at the vats, fan and lift with `lastShadowRenders` 1 per
moving post in range. Entry diff: 1 program, the NON-instanced depth variant (shell outer wall
faces under the beacon). The warm's caster render covers the instanced one and not this.

**The traps:**
- The lab matches the sewer's light counts to share programs (LabScene), so a light of its own
  recompiles every shared material. The moving lights are POSTS in the pool with `LampPost.moving`:
  the caster slot serving one re-renders its map every frame.
- A fan lamp straight over the axis: the housing's shadow, ten times its size at the floor, swallowed
  the whole pool. Only the rotor casts.
- A beacon circling its own spot put half its sweep on the bedrock over the walls. It circles a point
  out in the lobby.
- The clone went unlit once its lamp left the glass, and a single-sided medium has no lit back for it
  to stand against. The fix is a double-sided medium plus a clone emissive off its own map.
- Warmup's render compiles shadow depth programs only if a caster slot is dirtied. `LabWarm` dirties
  one and turns every batch to casting.

**Verdict:** landed. One depth program still compiles on entry.


## Lab round 4: vat console lamps, vat floor glow, lamps that cast, swaying fetuses, reactor seams

**Changed:** the vat console's screens and nine of its twelve grid buttons glow off
`lab-vat-frame-emissive.png` (`models-src/lab/_vatemi.py`), the buttons coded for `LabBlink`. The
frame is patched in `LabVats.dress`. Each vat lays a radial additive glow on the floor
(`LabVats.pool`, one mesh for all vats, FacilityGlow's route): the pool's real lights only serve the
vats nearest the player. The glow fades with the vat's drain and is clipped only at walled room
sides. Room and corridor lamps cast now (`noCast` false), and so do the vat lamps, which sit between
the glass and the console. All opaque lab furniture and the vat frame cast. `LabSpin`'s per-light
caster list is gone. The amber tanks' fetuses sway (`LabWater.patchEmbryo`, chained over the blink
hook). The medium stands `VAT_FLUID_LIFT` 0.03 over the ring. The reactor's drum wraps keep 8 atlas px
off the sheet edge, and its glass collar stands on the rim's flat top, 32-sided like the drum.

**Measured:** seed 768512642, FPS 75 (cap) in the vat hall and the store. Entry diff unchanged: the one
non-instanced depth program. Pool glow 0.4 blew out where four vats meet, 0.11 reads as spill. The
console shadow falls ~2 units before each console. 0 gens.

**The traps:**
- The fetuses are part of the tanks' body glb, so the sway picks them by UV rect (skin, eyes). The
  eyes' rect also holds two plinth corners, which a foot gate (y > 1.12) keeps still. A rebuild that
  moves them on the sheet must re-measure `EMBRYO_SKIN`/`EMBRYO_EYE`.
- A pool clipped to its room's whole rect drew a hard edge where the room opens on the next one with
  no wall between.
- Desks stand on the walls and the room lamps pool the aisles (`LabLamps.free`). Casting room lamps
  alone threw no desk shadow. The visible one is the vat lamp's.

**Verdict:** landed.


## Lab round 5: vat glow over the plinth, fake tank glows, a seamless vat floor

**Changed:** each vat's floor glow (`LabVats.pool`) has a second quad on the plinth's top (`VAT_SLAB_Y`
0.31, the slab's 7.8 x 11.8 rect). The floor quad ran under the 0.3 slab, and its edge cut the glow
off. The tube and the stasis pod lost their pool lamps (`LabTankGlow.fake`). Each now lays a fanned
trapezoid on the floor before its front, all of them in one additive mesh (`LabInterior.spill`,
FacilityGlow's spill shape, vertex rgb per glow, dimmed with the lab). Each also gives a light at its
front that only the actors' fake shadows read (`LabArea.shadowLamps`, the facility windows' contract).
The vat-hall floor's wrap was closed by `tools/seamfix.py cross`. That is tone's blend off a rolled copy
whose two drain channels are first filled with the field mirrored in, with the original channels then
stamped back whole.

**Measured:** vat floor wrap |diff| 9.8 / 8.9 to 2.1 / 2.6. 5 fake tank lights on seed 768512642,
entry diff unchanged (the one depth program; the spill shares the vat pool's program), 73-75 fps.

**The traps:**
- An additive glow is added in LINEAR light: colour 0.12 still landed at sRGB 73/95 over a floor at
  11/17 and read as a torch beam. 0.05 reads as spill.
- A plain `tone` on a crossed field doubles the grid: the rolled copy carries the channels to the
  edges. The fill has to read the already-filled copy for the second band, or the first band comes
  back at the crossing.

**Verdict:** landed.


## Lab glows fainter, and the lamp pool's lit count in the top bar

**Changed:** `VAT_POOL_GLOW` 0.11 to 0.06 and `TANK_SPILL_GLOW` 0.05 to 0.03, which the user asked for as
"more transparent". The top bar's debug readout gains `lit/pool lights`
(`LampLights.lastLit`/`lastPool`, set each `update`). It counts the spotlight pool's slots lit this
frame. Flame and muzzle lights are their own pools and are not in it.

**Measured:** in the lab's vat hall the pool reads 12/12 lit, at 75 fps.

**Verdict:** landed.


## Lab signs and the borrowed electrical kit at half albedo

**Changed:** the lab's wall signs (`LabStyle.WALL_SIGN_TINT` 0.5 on the signs sheet's material) and the
compound's electrical kit in the lab (`ShellTex.elecTint`, lab `ELEC_TINT` 0.5, through
`FacilityCable.add`'s colour). They were reported as too bright for the dark rooms: their white and red
grounds at full albedo read as lit panels against walls painted near black. `MeshLambertMaterial.color`
was added to the three extern.

**Measured:** both are colour uniforms, so no program changes. The facility keeps 1.0 (null).

**Verdict:** landed.


## Lab round 6: beacon on the girder face, every tank glow fake, vat hall four fixtures, slower fan and doors

**Changed:**
- **Lift beacon.** It now lies on its side, bolted to the back girder's front face (`liftshaft.py`, x 4.4,
  the girder's 8.7 middle). The bulb (`SPIN_BEACON_*`) sits just past the dome's tip. On the girder's
  top, the girder cut the beam's cone and its hard edge swept the lobby as a shadow. x 4.4 keeps the
  dome clear of the car's ±3.9 deck, whose corner post rides down past it.
- **Tank glows.** The amber tanks and the specimen case go fake like the tube and stasis pod, so no
  tank takes a pool lamp now (only the embryonic bank still does). The specimen case's colour is its
  glass's teal (`0x6ae8d8`) instead of the green it had been throwing. The tube takes `ring`: a square
  of the rect glow centred under it, with a half-side of radius + `TANK_RING_OUT` 1.3. Its fake light
  stands over the axis, aimed down, so the actors' fake shadows fall away on every side.
- **Vat hall lamps.** The vat hall takes a 2x2 lattice with none dead. That is one fixture per
  quadrant, down from about seven, all of which went red together under the alarm.
- **Timing.** `FAN_RATE` 0.6 to 0.08 turns per BASE_MS: about 4 rps strobed the blades' shadows, and
  it is now 0.53 rps. `DOOR_MULT` 0.6 to 3.0: a slide took 90 ms and now takes about 450 ms.
- **Torn suit.** Its colour now comes from a `texSrc` override (`models-src/lab/_suittorn.py`). Only
  the fabric's hue turns from 36 to the suit's 52, and `baseColor` 0.39 matches its luma to lab/suit.

**Measured:** the entry diff is still the one known depth program, and the frame rate holds at
73–75 fps. Live: the door eased 0 to 1 in 442 ms, and the fan turned at 6.6 BASE_MS a second ×
0.08. The vat hall reads `lamps.vat` 4.

**Trap:** a per-channel `baseColor` (0.34/0.56/0.15) did match the fabric, but it tinted every grey
(visor, boots, seams) green. A hue fix belongs in the map, not the factor.

**Verdict:** landed.


## Lab round 7: beacon casts down its beam, plant halos, wider amber spill, screens cut out, no shaft light

**Changed:**
- **Beacon actor shadows.** `LampPost.beam` (reach, world units) makes `LampShadows` cast only inside
  the cone round x/z → tx/tz (`CastShadows.cone`, ground half-angle `LAMP_LIGHT.angle`, eased over
  the rim `fade`). Down a beam there is no distance fade, because its light is brightest where it lands.
  The length runs with reach over height. The beacon carries `SPIN_BEACON_REACH` 20.
  The old round pool round x/z was 5.2 (8 × refY/8.7) and never reached the lobby floor the beam lit.
- **Plant halos.** `PLANT_GLOW` covers plant5 purple, plant1 and plant6 teal. Each colour is its
  emissive map's lit mean. A square under each plant, with a half-side of half-width + 1.0, goes into
  its own additive mesh (`LabInterior.halos`). The material is the spill's but the map is a disc
  (`makeRectGlowGradient(0.3, 0.3, 0.2)`), so the program is the same. The halos are not dimmed with
  the lab, since the plants are alive. plant4 is skipped: its glow is 0.7% of its map.
- **Amber spill.** `LabTankGlow.w`: the ambertanks' near edge goes from 3.0 to 5.6, the glass's width.
- **Wall screens.** The user cut the sheet's ground to alpha by hand. Without `alphaTest` the
  quad drew that ground's RGB, which read as a panel behind the caged lamps. Screens now take
  `DECAL_CUT` like the fittings (warm goes through the same `add`).
- **Pipe capsule window.** The two halves met at sheet columns 330/180: mid-panel against a divider
  and the frame's notch. A column scan picked 470/358, both mid-panel, at a 98th-percentile column
  difference of 13.6/255 against 83.4 before. The window is now 3.5 long instead of 3.7.
- **Power box.** An emissive map (`_powerbox_emi.py`) lights the 16 breaker indicator strips per face
  steady red, and two of them blink through LabBlink's alpha code.
- **Lift shaft light.** The steady cold `LAMP_SHAFT` post down the lift is gone, along with its
  constants and `LabLampSet.shaft`.

**Measured:** the entry diff is still only the known depth program, at 73–75 fps. Live, with the
beacon frozen on the host at 14.7 out, a long shadow lies away from the shaft. At 4× the first
strength the plant5 halo read as a soft round purple disc, so the strengths shipped at that.
The amber spill quad's near edge is 5.6. The powerbox material is RGBA emissive with the blink patch.

**Trap:** the halo at the tanks' 0.9 strength was invisible. A disc a plant wide has a fraction of a
trapezoid's area under the same additive 0.03.

**Verdict:** landed.


## Amber tanks: fluid block ends mapped, glass bubbles front panes only

**Changed:** two picks in the amber tanks read as broken, and both were the fluid seen through the
glass. The big tank's fluid is an opaque back block behind the fetuses (`ambertanks.py`). Its two
ends were fitted to the whole amber rect like every other face, so each end took a 41 px sliver of
the art stretched over its 0.99 depth. Seen through the corner panes it was a smeared strip. A new
`sides` rect on `prism` gives each end a slice as wide against the art as the end is against the
front (u 0.37..0.63 of BL), at the front's v, so the sediment line carries round the corner. The
cylinder's pick was the glass over its fluid column. `LabWater` lays its bubbles out at
q.x = x + z, so on the cylinder's flanks and the big tank's corner panes a bubble's disc smeared
into a diagonal white streak. The bubbles are now weighted by
`smoothstep(0.6, 0.9, |objectNormal.z|)` (a vertex varying), which keeps them on panes facing
the front.

**Measured:** live at zoom 0.05, the end strips read as plain amber and the cylinder has no streaks.
The entry diff is still only the known depth program (the shader keeps its `labWater` key; warm
compiles the new source).

**Verdict:** landed.


## Amber tank bubbles: neighbour columns looked up

**Changed:** `LabWater` looked each fragment's bubble up in its own column only. A bubble sways up to
0.3 of a `WATER_COL` (0.32) off the column's centre and is up to 0.39 of one wide (radius
`WATER_BUBBLE` × 1.4), so near the end of its sway its disc crossed the column line and was cut flat
there. Reported as "cut off by something on the left and right when they're swaying". The fragment
now takes the max of its own column and its two neighbours, which covers the disc's reach of
[-0.19, 1.19] columns.

**Measured:** a NumPy copy of the shader at t 37 drew several half-discs with the old lookup and only
whole ones with the new. Live, the program compiles with no error and the entry diff is still only
the known depth program. Three loop passes on the tank glass alone.

**Verdict:** landed.


## Lab bubbles see-through: rim and highlight, clear middle

**Changed:** both of `LabWater`'s bubble passes, the amber tank glass and the clone vat medium, drew
a bubble as a filled pale disc and lifted the alpha across it, so each one read as an opaque white
pill. A shared `labBubble(d, r)` now draws a rim from 0.68r to r plus a highlight fleck up and left
of the centre, and the middle stays the fluid behind. The rim's edges are at least a screen pixel
soft (`max(fwidth(l), 0.08r)`), because a far bubble's rim is thinner than a pixel and a hard one
broke into dotted specks. The alpha lift drops to 0.3 (amber) and 0.25 (vat) on the rim only. The
vat pass takes the amber pass's neighbour-column lookup too, with its column index wrapped round
the turn (`mod(c, LV_N)`) for the hashes, so the seam behind the axis has no edge.

**Measured:** live at zoom 0.05, the vat bubbles read as rings with a highlight and the clone shows
through them. On the bright amber the rings are faint by construction. No shader errors, and the
entry diff is still only the known depth program.

**Trap:** the first hard-edged rim (0.62..0.82 / 0.88..1.0 r) aliased into dots at game zoom.

**Verdict:** landed.


## Lab bubbles: rim AA off a continuous footprint, tank bubbles laid out on x

**Changed:** the see-through rings softened their rim by `fwidth(l)`, where l is the distance to the
bubble's centre. That centre is relative to the bubble's column and cell, so across a column or cell
line `d` jumps and fwidth spiked. The rim's smoothsteps collapsed there, and the bubble went clear
along a one-pixel line, reported as "thin vertical lines that make bubbles completely transparent".
`labBubble` now takes `px`, one pixel's footprint in the fluid's own frame (`length(fwidth(q))` on
the tank, `length(fwidth(vLabVat))` in the vat), and both are continuous everywhere. The tank's
bubbles also leave the ripple's x + z for plain x. They only show on front-facing panes, and round
the cylinder x + z ran 0.37 of the arc on one side of its front and 1.37 on the other, which drew
every bubble there as an oval.

**Measured:** both were checked with an off-rig camera rendered into the canvas: one 5 units
in front of the amber tank at fov 25, and one 5.5 in front of a clone vat at fov 30. Every ring is
whole with no line through it, and the cylinder's bubbles are round. The entry diff is still only
the known depth program.

**Trap:** fwidth of anything built off a floor()ed cell index is not a pixel size. Take it off the
continuous coordinate the cells are cut from.

**Verdict:** landed.


## Lab: hatchbox chart off the lamp mask, purged clone crossfades into its heap, lift carries the player out

**Changed:** three picks. The hatchbox screen's bar chart was being taken for lamps. Its three short
bars passed `_ledmask.py`'s small, compact, on-black tests, so each one blinked at `BLINK_GAIN`
over the screen art. A hatchbox `EXCLUDE` rect (140, 690, 300, 810) now leaves one lamp, the lens.
The purge used to swap the floating clone for the heap on one frame. Now the clone fades out over
`CLONE_FADE` 1.5 either side of its knees, and the heap fades in over `HEAP_FADE` 1.0 as the surface
falls below its top. The fade is the instance colour's grey, read as alpha by `LabVats.fade` (both
materials are now transparent). The lift: `objects.Elevator` in the lab hands its leave to
`View.liftDepart`. The car climbs `LIFT_DROP` over `LIFT_MULT` with the player on it, and the leave,
its 5 energy and its turn run at the top. `View.departing` makes `UI.onKey`, `Mouse.onClick` and
`ActionsHud.doAction` drop input meanwhile.

**Measured:** in the built glb the bars read alpha code 255 and the lens still blinks. On the purge,
an off-rig camera 9 units before a vat caught the clone fading through 0.19..0.97 and the heap
coming up 0.17..1.0 with them overlapping, with no silhouette and no pop. The departure took 2.4 s
from t 1 to 0, then went to the region. Turns and energy moved once, and a key press and a second
click mid-climb did nothing. The entry diff is still only the known depth program, and walking into
the vat room adds none.

**Traps:** three's fragment prefix carries instance colour as `USE_COLOR`, never `USE_INSTANCING_COLOR`
(that one is the vertex's), so a guard on it never ran. A half-faded clone still writing depth cut
the fluid's far wall out behind it into a dark silhouette, so fading clones draw from a twin batch
with `depthWrite` false (`ghost`, sharing the clone's hooks and key, so it uses the same program). The
heap can't use that twin: under the medium nothing behind it is drawn yet, so a depth-free heap
vanished and then popped. Hence it waits for the surface instead. A chained key must call three's
prototype `customProgramCacheKey` with the material as receiver, or it throws on every draw.
Rendering off-rig straight into the canvas turns on tone mapping, and that compiled 21 test-only
programs.

**Verdict:** landed.


## Fake shadows pinned to the sprite's feet, a turning lift beacon hung under its girder, gurneys askew

**Changed:** the fake cast shadow (`Sprites.paintShadow`) used to be a rectangle rotated to face away
from the light, centred on the feet. Its near edge swung with the light, so its corners poked out past
the sprite's own bottom edge. The slot quad's four corners are now written directly. The near two sit
on the sprite's bottom corners, which run along world x because the billboard is frontal. The far two
are where the rectangle's were, square across the away direction at the length, so a side light still
lays out a body's width and not a line. The far -x corner takes the image's left, or the quad crosses
itself. `slot()` puts a bent quad back square (`unbend`) before any other paint uses it.
The beacon now hangs under the back girder's lip, tip down (`liftshaft.py` BX/BY/BZ), and its light
moved to 7.55, just under the dome's tip. Two new objects come off the same script: `lift-beacon`, seven mirror panels round a bulb on a centred
turntable, and `lift-dome`, glass via `LabInterior.glass` with an amber emissive. `LabSpin` turns the
reflector a full turn at `SPIN_BEACON_RATE`, and the beam lands `SPIN_BEACON_OUT` 9.0 out where it
faces. It goes dark while it faces the back wall, 0.45 behind it (`SPIN_BEACON_DARK`/`FADE`), and its
fake shadows fade with `mul`. Gurneys turn 0.4..1 of `MACHINE_JITTER` 0.2 rad off square. The vat's
purge is listed once (`HUD.hasAction`).

**Measured:** with the beam frozen on the player, the shadow leaves the shirt's bottom edge and fans
away. Close renders over a turn show the dark back plates, the side, then the lit bulb and mirror.
Gurneys stand 11.1 and 9.4 degrees off square. One purge shows from each of 14 cells in front of the
four vats. The entry diff is still only the known depth program.

**Trap:** the old beam aimed at a circle out in the lobby, so seen from the beacon it only swung
+-37 degrees. A reflector following it rocked instead of turning. A beacon that turns has to throw its
beam round the full turn, and the wall it backs onto is what decides where that beam goes dark.

**Verdict:** landed.


## Player x-ray under the south wall, badges drawn after the bloom, camera fly mode

**Changed:** `Badges.drawXray` never x-rayed the player's own host, because the city fades the
buildings in front of it (`Occlusion`). Nothing fades an underground or compound wall, so a player
standing under a corridor's south wall, camera close, disappeared. `drawPlayerXray` paints the free
parasite or the host in `XRAY.player` (the ring's 0xb46bff) everywhere `View.fadesOccluders()` is
false, i.e. everywhere but `CityArea`. Not while attaching: the head it rides carries its own.
AI badges are white self-lit glyphs and crossed the bloom threshold. `Sprites.paint` now moves every
`depthTest:false` quad into `Sprites.overlay`, its own scene with no lights and no fog, and `slot()`
moves it back on reuse. A `RenderPass(overlay)` with `clear = false` runs between the bloom and the
`OutputPass`. Its one program (lights 0, fog off) is warmed at boot by `Warmup.overlay()`.
Shift+` is the camera fly mode (`View.setCine`). It uses the debug `FreeCam` (`Debug.fly`, which
creates it without the tools), hides the HUD the way Shift+Space does, and sets `body.cine` so no
element shows a cursor. `debugActive()` covers it, so the game takes no keys; clicks, wheel and RMB
orbit are gated too. Plain ` switches to debug and back. The light pools centre on
`View.lightCol/lightRow`, which is the camera's ground cell in the fly mode. The new
`Area3DTickOpts.lightCol/Row` fields carry it to the city, facility, corp, lab and sewer lamp pools,
the lab and sewer prop lights, and the barrel flame lights.

**Measured:** at (20,18) under the corridor's south wall at zoom 0, the host shows through the wall
as purple scan lines. Badge emissive pushed to 4, with the overlay pass moved before the bloom: the
annulus round the badge averages 85.8, and 60.2 with it after the bloom, i.e. no halo. Flying 1.5 s
east moved the light cell from (20,22) to (37,22), and 6 of the 12 lit lamps changed. The player
stayed at (20,18) and the HUD came back on exit. Lab entry compiled no new programs.

**Trap:** the vision mask stays the player's, so a camera flown out of their sight looks into dark;
`set p.los 0` lifts it for footage.

**Verdict:** landed.


## AO kept off the upright sprites: the frame's alpha past 1 marks them

**Changed:** GTAO's prepass hides the sprite layer (a billboard would go in as a solid slab). The AO
under an actor is therefore the shade of what stands BEHIND it, and the stock `GTAOBlendShader`
multiplied that over the finished frame, the actor included. Close up in front of a vat plinth, its
steps lay as bands across a face. Upright pool quads (`Sprites.paint` with neither `flat` nor
`faceRotY`, and `paintTopple`) now draw with `CustomBlending`: colour as three's normal blend, alpha
`ONE + ONE`. The composer's targets are `HalfFloatType`, so an opaque pixel under a sprite reads
alpha 2, which nothing else writes. `View` replaces the blend material's fragment shader with one that
also samples the frame it was handed (`tBeauty` = `readBuffer.texture`, set per call in the existing
render wrapper). It scales the AO by `1 - clamp(a - 1)`. Decals, wall quads and fake shadows keep
`NormalBlending` and take the surface's AO. `blending` is GL state, not a program define.

**Measured:** camera 4.5 in front of a host standing at the plinth's foot. AO off, the fix and the
old blend (tBeauty forced to an alpha-1 texel), side by side: the old blend lays the step's band across
the face, and the fix matches AO off there.

**Trap:** `render.StreetBlur` already reads alpha as its mask (`1 - a`). Alpha past 1 lands on its
"untouched" side, so a sprite over the far street stays sharp, which is right for it.

**Verdict:** landed.


## Warm programs persisted to GPUCache: `ANGLEPerContextBlobCache`

**Changed:** `MainElectron.main` appends `enable-features=ANGLEPerContextBlobCache`. Chromium did
keep compiled programs in `userData/GPUCache` (ANGLE D3D11 binaries with DXBC, keyed by Chrome
version + GPU + driver, 6 MB cap) and loaded them at launch. But a program warmed through three's
`compileAsync` usually reached GPU MEMORY only. With `KHR_parallel_shader_compile` on, Blink wraps
every `linkProgram` in a `GL_PROGRAM_COMPLETION_QUERY_CHROMIUM`. The GPU side mostly resolves the
finished link inside the decoder's `MakeCurrent()` → `ProcessQueries()`, which `CommandBufferStub`
runs BEFORE `CreateCacheUse` installs the disk-write callback. The feature gives each WebGL context
its own ANGLE blob callbacks, whose `Set` always carries the disk callback.

**Measured:** salted probe programs, polled to completion: 0/4 to disk off, 3/3 on. One launch with
the disk cache disabled: boot warm **8405ms** with ~60 misses and ~63s of HLSL compile summed across
threads. Fully cached: **3816-3898ms**, 0 misses, 0 WebGL compiles. Facility load on the switch:
23 misses → 23 entries. Next launch: facility warm **4414 → 1322ms**, in-game **7.2 → 2.7s**, 1 miss.

**Trap:** the drop was a RACE, not a rule. Without the switch, a link resolved on a scoped path still
landed, so this machine had piled up ~65 of 75 boot programs over many launches and looked warm. A
player's second launch did not. A `COMPLETION_STATUS` ask, then a later `LINK_STATUS`, is the path
that loses. Also: a fully cached boot still takes ~3.8s with zero WebGL compiles, so that floor is
not shaders. Skia relinks ~95 programs every launch (0/193 hits in its own cache, ~0.9s GPU thread).

**Verdict:** landed. +0 calls, +0 programs.


## Boot: shader caches to 64 MB, one menu background, shader info logs debug-only

**Changed:** `MainElectron` appends `gpu-disk-cache-size-kb` and `gpu-program-cache-size-kb` =
65536. Both default to 6 MB and the disk one sat at 5.73 MB. It evicts by last WRITE and a hit never
writes, so the boot set, written once and read every launch, was the first to go and the next boot
compiled cold (11.8-12.1s to the prompt vs ~6s). The memory cache is filled from disk at launch, so it
gets the same size. `MainMenu` picks its random background BEFORE its one `setBackground` call; it
used to decode and upload the default 2688x896 jpeg, then replace it. `SceneSetup` sets
`renderer.debug.checkShaderErrors = Const.isDebug`, so release skips the info-log reads per program.

**Measured:** launch → autosave prompt, 5 relaunches: **5.41 / 5.50 / 5.58 / 5.63 / 6.69s**
(median 5.58) against 6.09 / 6.09 / 6.12. The warm now starts at 1.5s instead of 2.0s, and the warm
itself is unchanged (~4.0s). `MainMenuGL` image onload over the whole boot: **322 → 34ms**. Fill
test: 70 throwaway programs took `GPUCache` to **6.66 MB with all 381 older entries kept**, then
`GPU.ShaderLoadPrefixOK` 451 at the next launch and 0 boot misses. `checkShaderErrors`, isolated:
first render of 40 cached programs **27ms on, 8ms off**.

**Trap:** soundmanager2's 204ms in `canPlayType` is NOT the 18-format probe. With
`audioFormats` cut to mp3 alone it read 233ms: it is Chromium's media stack starting on the first
call, so the override was reverted. The inline script in `app.html` is pinned in the CSP by its
sha256; any edit to it needs the hash recomputed or the script (and `SoundManager`) never runs.

**Verdict:** landed.


## Textures cached by path: one decode and one upload per image (`Textures.share`)

**Changed:** `render.Textures` keeps one private master per loader + path (`t|`, `pm|`, `crop|`,
`alpha|`, `key|`) and hands out `share(master)`: a clone with its own wrap/repeat/offset over the
master's image. `TextureLoader` is gone; `landed()` is the one load path (image, canvas variant or
procedural stand-in). `loadPremultiplied` replaces "load, set `premultiplyAlpha`, `needsUpdate`" in
Buildings grime, FacilityGrime, SewerDetail and WallHole. Every `clone()` + `needsUpdate` in the city
builders (Poly.flattenBox, Buildings, Parapets, Gables, FlatRoofs, Entrances) is now `share()`.
`Poly.reset()` drops the UV editor's per-build texture list on rebuild.

**Measured (same CDP upload counter on HEAD and this build, same save):** boot to the prompt **316 →
158 uploads, 106 → 48 Mpx, 325 → 167 live GL textures**. First entry after boot: MEDIUM city **92 → 12
uploads (32.4 → 3.9 Mpx)**, HIGH **112 → 18**, LOW **123 → 9**; the rest are canvases and glb bitmaps,
no texture PNG. After facility + 4 cities + facility: **1133 → 524** live textures. Warm window of the
boot trace: Decode Image **1061ms x275 → 487ms x140**, main-thread tasks **4.04 → 2.75s**. Launch →
prompt, 5 relaunches: **4.56 / 4.60 / 4.61 / 4.72 / 6.33s** (median 4.61, was 5.58); warm total 4.0
→ 3.0s. Frozen frames (windows forced dark, HUD hidden, PNG) vs HEAD: city and facility **0 pixels
off by more than 8**. Boot `__progs()` set identical (67).

**Trap:** three's `clone()` ends in `needsUpdate`, which bumps the SHARED `source.version` and makes
every sharer re-upload (and an `<img>` re-decode) on its next bind, so `share()` puts it back. And a
copy must not be uploaded inside the loader call: callers set Clamp and colour space right after it,
and three reads both only at upload, so a cache hit uploads from a microtask. The master is never
uploaded: its own Repeat set was a second, unused upload of every door and grime map.

**Left:** CorpMerge still disposes the maps it merges, so 7 facility maps with no other user free and
re-upload on every facility load (20 uploads where HEAD did 100). The remaining +30 live textures per
area entry are shadow maps, canvases and the bloom chain, not `Textures` art; see "Bloom pass freed on
rebuild" for which of them actually held VRAM.

**Verdict:** landed.


## Boot textures decoded as ImageBitmaps off the main thread: no gain, +165 MB

**Tried:** `Textures` masters loaded by fetch → blob → `createImageBitmap(imageOrientation 'flipY',
premultiplyAlpha 'premultiply'|'none', colorSpaceConversion 'default')` with `flipY = false` (WebGL
ignores both unpack flags for a bitmap), CorpMerge flipping a layer only when its map is `flipY`, and
the menu's `loadTex` on the same path.

**Measured:** in isolation it looked like a win. On 14 PNGs (5 Mpx) through the game's renderer the
main-thread upload cost was **13.7 ms/Mpx for `<img>`** (decoded inside `texImage2D`), **13.2 with
`img.decode()` first** (WebGL decodes again anyway) and **1.9 for the bitmap**. Uploaded bytes were
read back and **identical for all 14**, premultiplied grime included. At boot it moved the cost
instead of removing it. Main-thread Decode Image in the warm went **487ms x140 → 26ms x20**, but sync
`GetProgramiv` waits went **253 → 758ms**, because the GPU thread is now busy with the uploads. The
bitmaps then land after the warm and their `texSubImage2D` runs **~0.8s at ~12.5 ms/Mpx** before the
prompt. Main-thread time from warm start to prompt was **~2.75s → ~3.6s**. Prompt median over 5
launches: **4.61 → 4.57s**. Renderer private memory: **370 → 535 MB at the prompt**, 461 → 584 after
a city, 781 → 963 after the facility. A bitmap is never discarded; an `<img>` decode is.

**Trap:** an upload benchmark on an idle GPU says nothing about an upload during the warm. Price it in
the boot trace (main thread warm start → prompt), never per Mpx in isolation.

**Verdict:** reverted. Decode stays on `<img>`.


## Boot warm builds representative buildings only (`WorldPass`, `CityWarm.representatives`)

**Changed:** `World.build`'s `audit:Bool` became `pass:WorldPass` (`REAL`, `WARM`, `WARM_NO_GROUND`).
A warm pass builds `CityWarm.representatives(city.buildings)`, the first 2 buildings per signature
(facade, shop, shopOpen, roof, buried, penthouse, winForce/winBlock/winInset, skipWindowFloor,
frontInfo store/small, noBackWalls). The city's tiles stay whole. The second and third warm cities
are `WARM_NO_GROUND`: Ground only loads its 5 textures, since Lambert + map is one program in every
style.

**Measured:** boot geometries **5382 → 1409**, same 67 programs and **same 158 uploads / 47.9 Mpx**.
Launch → prompt, 5 relaunches: **3.26 / 3.38 / 3.55 / 3.60 / 4.22s** (median 3.55, was 4.61). Warm
sync head **~1.1 → ~0.68s**, warm total **~3.0 → ~2.0s**. Key sets from a FIXED save (slot 6),
HEAD vs this, over facility → MEDIUM → HIGH → LOW → MEDIUM → facility: boot identical, and **no key
this build compiles that HEAD does not**. HEAD had 1 extra on HIGH, inside the run-to-run noise
(5 and 1 keys between two runs of one build). City entries still upload no texture PNG.

**Trap:** never diff key sets off slot 0. It is the autosave, rewritten on every reload, so two
"identical" runs load different actor positions. three's shared shadow depth material takes `map` and
`alphaTest` from whichever caster draws, so a depth variant came and went with the scene and looked
like a missing warm key. Load a manual slot for both builds.

**Not done:** the planned builder hot spots (isWornFace cache, owner index, a FaceUV flattenBox). With
P2 in, World.build over the three warm cities was 540ms with isWornFace 6ms, coveredEdges 4ms and
Ground runs 9ms. The warm now builds representatives, and a real city entry builds in 84-157ms.

**Verdict:** landed.


## Bloom pass freed on rebuild; warm bloom keeps its materials only (`View.disposeBuild`, `Warmup.compile`)

**Changed:** `View.disposeBuild` now calls `bloomPass.dispose()` next to `gtaoPass.dispose()`.
`Warmup.compile` names its throwaway `UnrealBloomPass` and, after the render, disposes its 11 render
targets (`renderTargetsHorizontal`/`Vertical`, `renderTargetBright`) but NOT its materials. The
extern gained those three fields and a minimal `WebGLRenderTarget { dispose }`.

**Measured:** reloading slot 7 (MEDIUM city), the Windows GPU counter for the game process. Before,
10 loads: after a forced GC **1045 → 1199 MB** (~16 MB kept per load), peaks 1238 → 1354. After,
10 loads: **940 → 939 MB**, peaks ≤ 1106; programs **77 on every load** (nothing recompiles). Live
GL textures at the prompt **167-177 → 155-156**. Bloom on vs off still differs only around lit
windows and the path line.

**Trap:** `renderer.info.memory.textures` (+31-36 per load before, +25 after) counts what nobody
DISPOSED, not live VRAM. Chromium frees a WebGL texture when its JS wrapper is collected, so the
per-build shadow maps (moon 2048², 8 lamp spots 512²), the Debris atlas 768x3328 and the Sprites
crops all go at GC. What GC could not take was the bloom chain: three's `WebGLShaderCache.materialCache`
holds every material until `material.dispose()`, and the blur/composite materials' uniforms point at
the mip-chain targets (found by a heap snapshot retainer path). Disposing the warm pass whole would
release the bloom programs the moment the first real build disposes its own pass, and every load
would recompile them; its undisposed materials are what keep them.

**Left:** the GC-reclaimed garbage (~80-100 MB per load) still sits until V8 collects; disposing the
lights' shadows and the per-build Sprites cache on rebuild would flatten the sawtooth, nothing leaks.

**Verdict:** landed.


## Hideable dumpster: the parasite fades out inside it; back doors skip its cell (`Actors`, `WorldCtx.doorBlocked`)

**Changed:** `objects.Dumpster` is a persisted city object (`CityAreaGenerator.placeDumpsters`: 8 on
LOW, 6 on MEDIUM, alley cells with exactly one building beside them, 10 cells apart, and only where
the open cells around stay one 8-connected group). While the parasite hides in one,
`render.Actors` draws it with `vis=false` (the same fade the host invade uses), the slime trail and
`LampShadows`' player shadow stop, and the ring stays on the bin's cell. `CityArea.build` hands
`World.build` the dumpster cells through `WorldCtx.doorBlocked`, which ends a `Geom.doorRuns` run the
way a neighbour's wall does, and clears it right after so warm cities never read it.

**Measured:** a regenerated MEDIUM city (seed 1028134918) placed 6 dumpsters, all non-walkable;
`[check]` PASS with noBackDoor 0. The fallback sprite is entities64 16/5, a keyed LANCZOS cut of
`models-src/dumpster-src.png` pasted by `tools/atlaspaste.py --cols 1 --cell 1024`; it reads as a
dark low box in the alley shadow.

**Trap:** an object's 64 px cell is still needed with no 2D view running: the sprite fallback, the
outline and `LampShadows` all read it. An empty cell draws nothing, so the bin would be invisible.

**Verdict:** landed. The glb replaces the sprite in the next phase.


## City object props: two hand-modelled dumpsters, and the city's rule for which rows it may draw

**Changed:** `render.CityArea` now builds `ObjModels` (objYaw turns a WALL prop's back on its one
building neighbour; `cull` in `tick`, `refreshObjects` rebuilds). Two rows, `dumpster_city` and
`dumpster_slums`, draw `objects.Dumpster` per tier (`getModelKey`), WALL-backed with `off` from
`CityStyle.DUMPSTER_BACK`, `noGhost` and `noCast`. Both are hand-modelled from one shape table
(`models-src/city/kit/dumpster.py` through `models-src/city/kit_build.py`, a copy of the lab kit runner
pointed at `city/`). Each wears a PACK4 that `edit_image` painted off `models-src/dumpster-src.png`:
the city bin green with the reference's real brand logo swapped for a fictional sticker, the slums
one rusted and tagged with the load across BR. Two gens, $0.128.

**Measured:** 1,852 tris (city) and 2,860 (slums: left lid thrown back, right lid ajar, four bags);
buildlib.check holes 0, coplanar 0, islands 1 on both, first export. `propstat` on the built glbs reads
sampled albedo 49/54/52 (city) and 54/55/47 (slums), inside the outdoor 46-52 family. A regenerated
MEDIUM city built one batch of 6, a LOW one a batch of 8. Boot warm 67 → **76** programs; the first
boot paid **+2.7 s** compiling them (6.7 s total), the next one was 4.2 s, back inside the 3.7-4.1 s
spread, off the persisted GPU cache.

**Trap:** the city has no vision mask, and SOLID shares the glb template's material. Every masked kind's
warm used to patch the WHOLE row table, so a city-only row would have carried a mask patch sampling
whatever canvas the last masked area left. `ObjModel.unmasked` marks the city's rows; FacilityWarm and
SewerWarm skip them, and in the city `ObjModels.propFor` answers only for them, so a ship part dropped
on a street keeps its sprite instead of drawing as a prop with another kind's patch. **Second trap:**
the painted stickers came back near-white (sRGB ~215) and were the brightest thing in a black alley;
`gradeRect` scales the three of them to linear x0.45.

**Verdict:** landed. The 64 px fallback icon at 16/5 is now a render of the city glb (`kit_build.py
icon`), not the keyed reference.


## Street wall kit: fire escapes and downpipes on the residential facades, service conduit downtown

> SUPERSEDED (the per-building merge) by Street kit merged per chunk with fade proxies, kits darkened, free-cam far cut

**Changed:** `render.world.StreetProps` dresses the walls per `AreaStyle.wallKit`: a fire escape over
two neighbouring window columns (`fireEscapeChance` 0.35 city, 0.5 slums), a downpipe beside the end
column (`downpipeChance` 0.5 / 0.6; slums `downpipeBroken` 0.6 drops the shoe and one length), and
downtown a conduit run at 4.3 (over the 3.9 door quads) with a riser + junction box and an intake
louvre on each open run of a worn face (`serviceChance` 0.6). Columns come from `Windows.add`, which
now publishes them as `WorldCtx.winCols`; doors via `WorldCtx.doorSpans`; hashed off the footprint.
Kits are hand-modelled in WORLD UNITS on the facade grid (`models-src/city/kit/wallkit*.py`, new
`kit_build.py` modes `pack` = all modules into one glb with one material, and `wall` = a stacked
preview), one glb per style. Each building's modules are cloned, transformed and `mergeGeometries`'d
into ONE mesh tagged `userData.b`. Three sheets, $0.17: city generated, slums an `edit_image` of the
city one (layout kept, so one geometry wears both), downtown generated.

**Measured:** modules 652 (floor), 624 (base), 108/152/64 (pipe/shoe/head), 264/192/24 (conduit/riser/
louvre); every gate holes 0, coplanar 0, islands 1. A/B on the kit meshes at the gameplay camera:
city +2 calls +2.1k tris, slums +3-5 calls +5.8k, downtown alley +2 calls +2k. The kits share an
existing program (none of their own). Occlusion bucketed 147/147, each under its own building, both
on the cached path and on a forced late load (cache evicted, glb landed ~6s after the build).

**Trap:** the city sheet's black iron sampled albedo **31** and was simply not there on night brick at
gameplay zoom (one railing showed, against a lit window). `lift` 0.72 puts it at 57 and it reads as
dark painted iron; the rusted slums kit (85/47/28) needed nothing. Downtown's galvanised sheet came
back at luma 97-144: flat `baseColor` 0.25 to 57-63. **Second trap:** the boot warm first WAITED on
the kit glbs, and a 4.2 -> 6.7 s boot looked like their cost; with the kits moved out of the warm
entirely the boot still read 6.1-6.8 s, so that was machine drift, not the kits. They are prefetched
after the warm now anyway: there is nothing in them to compile.

**Verdict:** landed. Merged per building and not instanced city-wide on purpose: an instanced kit
would stay solid on a faded building, and a fire escape left standing in front of the player is the
one thing the fade exists to remove.


## Street ground props: fifteen hand-modelled pieces per tier, and steam off the stacks

> SUPERSEDED (the piles) by "Street junk dealt per cell from separate pieces; loose swatches; dumpsters at 1024"

**Changed:** `StreetProps.ground` scatters `AreaStyle.groundProps`, one prop a cell at most, hashed off
the cell: KERB (a walkway cell on exactly one road, at the kerb, facing it), WALL (an alley or walkway
cell on exactly one wall, its back to it), SERVICE (WALL on alley cells only, to keep the compactor
off the frontage) and BIN (beside a dumpster). Object cells and lamp cells stay clear, a wall prop
never stands across a door, and each prop is ONE `Models.instanced` SOLID batch culled per instance
in `CityArea.tick`. Slums: sack pile (BIN + WALL), mattress, cart, tyres. City: bag pile (WALL +
KERB), hydrant, parking meter, news boxes, gas meters, steam stack. Downtown: compactor and recycling
(SERVICE), street tree in a grate, bollard, planter. Built by three sub-agents in parallel off one
brief, each piece a reference + a pack4 edit (30 gens, ~$1.8), Blender modules in
`models-src/city/kit/`. `SteamPuffs` puffs off every `vent` prop near the player: ONE instanced
additive quad, faded by instance colour, frontal (fixed yaw, `Sprites.TILT`), double-sided.

**Measured:** 364-2,912 tris a piece, all gates 0/0/1. Placements in the test areas: city 192,
slums 79, downtown 253. Gameplay-camera A/B, the batches detached (toggling `visible` does nothing,
`Models.cull` rewrites it): city +10-12 calls +44k tris, slums +2-4 / +16k, downtown +10-11 / +22k.
No ground prop uses a program the rest of the scene does not; the steam quad's one is warmed in
`CityWarm`.

**Trap:** every sheet came back bright for the outdoor family: sampled 62-150 against 46-52 (the
hydrant 133, the stainless bollard 147). A flat `baseColor` scalar per piece (0.12-0.72) lands them at
48-61 with their chroma kept. **Second trap:** the steam quad was single-sided and vanished from any
camera behind its lean; the FX pool draws its frontal quads DoubleSide for that reason. **Third:** the
boot read 14-17 s through this whole phase. Not this phase: the Phase 3 commit, rebuilt and timed
under the same conditions, read 14.0 and 16.5 s.

**Verdict:** landed. Tris are the bill (the city's +44k is the meters, bags and gas meters in view
and in the moon's shadow pass), not calls.


## Street litter: a PACK64 per tier, through a batched path that reads the cell size

**Changed:** the city's litter no longer deals entities64 rows 41-47 (shared with the sewers, the
facility and the wilderness, which keep them). Each tier deals its own 8x8 PACK64 of 128 px cells,
`city/debris-slums|city|downtown` (`AreaStyle.debrisPack`): rows 0-5 the small things the scatter
clusters at random scale and turn, rows 6-7 the big flat ones laid square. `Images.getImage` loads a
pack on first ask; `Sprites.cellRect/contentRect` take the cell size off `Images.cellSize` instead of
the hardcoded 64, which is also the hook blood and ground money need for their 128 redraw. One sheet
per tier, so the scatter is still one draw: **150 calls either way** on the same frame.

**Art:** three sunburst-high transparent drops, the pack64 prompt shape, no surface named. City and
slums came back UNCUT anyway (alpha min 166 and 29, a painted backdrop); one `edit_image` pass each
("keep the objects, remove everything else") gave 61-62% clear. `pack16.py --cols 8 --rows 8 --cell
128 --tol 4 --valign center` packed all three first time.

**Trap: a pack cell is FULLER than the cell it replaces.** The old rows' content boxes fill a median
0.453 (transformable) / 0.484 (static) of their 64 px cell; the packs fill 0.70-0.73 / 0.75-0.80 of
128. `SIZE * fw` scales by fill, so every piece drew 1.6x the litter it replaced (a scratch card as
wide as a manhole). `DECAL.debrisPackScale` 0.62. **Second trap:** the packs draw at full alpha where
the old rows draw at ~0.5, so `debrisMul` does not carry over; the value lives in the manifest's
`cells.cap` and the pack draws at mul 1.0.

**Measured:** same placements both ways (the rng sequence is unchanged), litter pixels found by
differencing against a no-litter frame, mean linear luminance over its ground. Natural light, caps at
0.065 first: city 1.90 against the old rows' 1.69. Caps x0.89: **city 1.70 / 1.69, downtown 1.55 /
1.55**. Slums would not measure in natural light: a failing-sodium lamp toggles between frames and the
dense litter sits at ground 0.001, where a JPEG step is 10%. Under 4x ambient (control: city 1.99 /
2.12) slums reads **2.7 against the old 3.6**, kept: the old rows read hotter there only because half
their alpha let the darker slums ground through, which nobody fitted.

**Verdict:** landed. Caps slums 0.036, city 0.058, downtown 0.058.

## Street clues: a pack16 of papers and books, the sixth deco sheet

**Changed:** `AreaGame.turnSpawnClues`' street branch (every area but a facility and a military base)
lays an `objects.Document` dealt off `Const.STREET_DOCUMENTS` (row 52, twelve papers) or
`STREET_BOOKS` (row 53, four books), where it laid the generic `Paper`/`Book` at entities64 2/1 and
2/2. The rows redirect through `Const.FACILITY_DECO_HD` as its sixth sheet (`city/clue-pack`, named
in `Images.loadDecoPacks`), the military pack's exact shape: 256 px cells, so 85 texels per world
unit on the flat cell against the old frame's 21. `tools/atlaspaste.py --grow` baked the 64 px icons
into entities64 rows 52-53 (grew 52 -> 54 rows). Being a `Document`, a street clue now takes the
`Actors` DOC_YAW turn off square for free. Item ids stay `paper`/`book`, and `imageRow/imageCol` were
already saved fields: no save change. Old saves' `Paper` objects still draw their 2/1 frame.

**Art:** one sunburst-high transparent drop: all sixteen subjects and the three stamped words
("EVIDENCE", "MISSING", "CONFIDENTIAL") right on the first roll, but UNCUT (alpha min 11) — the
third of four drops this week to come back with a painted backdrop and no surface named. One
`edit_image` re-cut, 49.4% clear, packed first time. Fill median 0.86 of the cell against the old
paper's 0.98, so it draws at scale 1.0 (the litter's 1.6x trap does not apply).

**Trap: dark AND solid on the asphalt.** The papers build 0.21-0.48 linear around the old paper's
0.347, but the black pocket notebook (0.0319) and the red diary (0.0361) are solid slabs (0.96) at the
asphalt's own 0.0329 and read as holes beside a clue that has to be found. `cellgamma.py` 0.62 on
those two cells only, from a pristine copy: 0.094 and 0.105, beside the paperback's 0.085. On screen
in an unlit slums street: diary 2.2x its ground, notebook 1.7x, paperback 1.3x, clipping 3.2x.

**Verdict:** landed. No `lift`, no `sat`, no `cells` cap: a clue keeps its colour against the
desaturated litter.

## The entities64 cells the 3D view still drew at 64: one 128 px redraw sheet

**Changed:** `fx/entities128`, an 8x8 of 128 px holding 34 cells (`Const.HD128`, reading order): the
parasite, dog, item box, nutrient, Choir of Discord and its body, burning barrel, money bill and
scatter, the three spits, the target reticle and frame, and all twenty blood/goo splats (red and
black 40/0-9, acid 21/3-7, slime 22/3-7). `Sprites.atlasFor` redirects every sprite-pool reader (tex,
texContent, silTex, outlineTex, shadows); the batched ground decals (plain blood, ground money) take
`Sprites.batchCell`, since `atlasTex`/`cellRect` work on one whole image and cannot follow a per-cell
redirect. The 2D view keeps entities64. No new program: 84 at boot before and after.

**Art: an EDIT, not a generation.** The old cells laid out 1.75x on a transparent 6x6 of 170, one
sunburst-high `edit_image` ("keep silhouette, pose, position, size, colours; only draw it better"),
cut first time (76% clear). Then each redraw fitted ASPECT-LOCKED into its OLD content box at 2x
(bottom-aligned for the seven upright sprites, centred for the rest), so every anchor, content rect
and shadow root lands exactly where the 64 cell put it: fit 85-100% per axis, centres within 0.2 px.

**Trap: the redraw is darker.** It adds outlines and shading: median 0.82x the old mean linear, money
and barrel ~0.6x. The decal multipliers, the acid/slime glow and the gas blend were all fitted to the
old values, so each cell gets a linear gain back to its own old mean (1.06-1.64; 0.88-1.00 after
highlight clipping). **Second: the gas clouds were redrawn and left out.** A soft cloud gains nothing
from pixels, and the repaint rimmed every lobe and lifted chroma 92/95 -> 114/128; the A/B (cells
patched back to 64, caches cleared) showed a busier, bluer cluster. The badges stay at 64 too: they
draw at 0.32 scale.

**Verified:** all 34 frames resolve to a 128 px texture, the gas to 64, plain blood batches from the
new sheet. Close-up A/B: splats gain clean edges and droplets, the money reads as notes, not blur.

**Verdict:** landed. Reticle and frame came back more saturated (chroma 133 -> 180), kept: UI.

## entities128: the redraw's saturation, matched back to the old cells

**Changed:** one more step in the registration of `fx/entities128`, before the luminance gain: each
cell is blended toward its own per-pixel luminance in LINEAR light (so luminance does not move) by a
bisected factor until its mean HSV saturation equals the old 64 px cell's. Factors: 0.00 black blood,
0.22 dog, 0.25 barrel, ~0.8 the splats, 0.73 reticle and frame, 1.0 the money.

**Measured:** reported from the game ("they sure gained saturation"), and it was the MODEL, not the
gain: the raw redraw is already 1.1-1.4x its own input (acid and slime splats 0.48 -> 0.69, reticle
0.65 -> 0.93, red blood 0.70 -> 0.79, black blood tinted 0.00 -> 0.05, the barrel given a rust rim my
own subject list named). A uniform linear gain cannot do this: it keeps channel ratios. After the
match: saturation within 0.026 of every old cell, luminance 0.95-1.00 (was 0.88-1.00 — less clips).

**Trap:** the edit prompt said "do NOT darken, desaturate, recolour"; a one-sided instruction is read
as a direction. Measure saturation as well as value on any redraw, and never describe a colour in
the subject list that the source does not carry.

**Verdict:** landed.


## Street kit and litter defect pass: blurry iron, hopper heads in the coping, struts on windows, giant litter

**Changed:** reported from the free cam, nine faults. **Kit** (`models-src/city/kit/wallkit.py`,
`wallkit-downtown.py`, unversioned): every swatch is now a whole cell with its edges trimmed, and
`tex` 512 -> 1024 on all three kits; the bracket struts moved to x ±2.22, outside the window columns
(glass and surround reach 2.1), where at ±1.7 each strut came down onto the window below; a toe
plate closes the hatch's open front; the BASE deck is whole (no stair leaves it) with the drop
ladder stowed on its front in two guides; the `head` module is an OPEN hopper (four walls and a
floor, a scupper spout) on a 1.8 socket stub a size up from the pipe. `StreetProps.headTop` stands
it under whatever the roofline does: a gable's eave slab, a brick parapet's cap (`b.h + 0.78`), a
concrete coping band (`b.h - PARAPET_EMBED - 0.04`). **Litter:** `AreaStyle.debrisSizes` gives each
pack cell its drawn longest side in world units (pocket things ~2x life, the big flat rows ~life);
`world.Debris.build` takes the style and overwrites the cluster's random scale with it, a cell sized
0 is never laid (the city's acorns), and `DECAL.debrisPackScale` is gone. `Sprites.atlasTex` names
its texture and `DecalBatch` its mesh (`decals debris-city`), so a probe click on litter says what
it hit.

**Measured:** iron 10 -> ~97 texels a unit, pipe skin 34 -> 68 (ground 57). Gates 0/0/1 on every
module; floor 652 -> 664 tris, base 624, head 64 -> 100. City litter: median 0.26 units, matchbook
0.10-0.14 (was up to 1.34), cup lid ~0.2, 0 acorns of 694 pieces. **Draw calls:** the reported 869
was the FREE CAM; at the gameplay camera on the same spot the frame is **247**, and detaching every
kit and street-prop mesh takes it to 236 (+11). At the free-cam pose the same A/B gave 873 / 844
(+29, 17 of them kit). No call moved with this pass.

**Trap:** the head was placed at `b.h - TOP_MARGIN`, which is where the pipe run ends, not where
the roof is: a concrete coping hangs 0.6 under the roofline and juts 0.37, so the hopper sat inside
it and its floor z-fought the band's underside; behind brick it hung 1.4 under the cap. A head has
to be placed off the roof `Buildings` actually emits. **Second:** `buildlib.check` counts co-facing
faces closer than 0.01, so a 3 cm plate against 3 cm balusters or a 3 cm hopper wall has no legal
spot; the walls went to 4 cm and the plate behind the balusters.

**Verdict:** landed.


## Street kit merged per chunk with fade proxies, kits darkened, free-cam far cut

**Changed:** `StreetProps.merge` builds ONE kit mesh per `render.Chunks` cell (the buildings whose
centre falls in it, one slice each, `mergeGeometries(..., true)` for the ranges), centred on its
contents so the chunk pass buckets it. Each building keeps a PROXY: a mesh over the same buffers
(`drawRange` = its slice) wearing an invisible clone of the material, tagged `userData.b`, so
`render.Occlusion` buckets, hides and ghosts it like any building mesh with no change to Occlusion.
The chunk mesh carries a material ARRAY and is tagged `occMarker`; `StreetProps.sync`, run after the
fader in `CityArea.tick`, lays one draw group per run of slices whose proxy is still visible. Kits
darkened with flat `baseColor`: city 0.40 (over its `lift` 0.72), slums 0.48, downtown 0.25 -> 0.09.
`View.freeCut` pulls the camera's far plane to `RenderConfig.FREE_CAM_FAR` (200) and the scene fog to
120-200 while the free cam flies, and puts both back when it lands.

**Measured:** slums test area: 123 dressed buildings in 35 chunk meshes. Kit draws at the gameplay
camera 7 -> 6 (the view spans few chunks); at a wide free-cam pose 79 -> 23-25. A faded building:
proxy hidden, ghost shown, its chunk split into two groups; walking off returns every chunk to one.
Kit luma 57.7 / 53.2 / 59.7 -> 34.9 / 35.5 / 34.2 (slums walls run 34-62). Free cam, three slums
poses: far 500 drew 2.3-2.5k calls at ~6 fps, 250 1.8-1.9k at ~10, **200 1.2-1.3k at ~40**, 160 ~950,
120 ~600. Gameplay frame unchanged at ~250.

**Trap:** three draws a material ARRAY one call per geometry group and a single material once over
`drawRange`, ignoring groups. So the chunk mesh takes `[mat]`, and with every slice hidden it simply
has no groups and draws nothing. A mesh whose verts are world-baked at the origin is bucketed by the
chunk pass into the 0:0 chunk and grows that chunk's sphere over the whole city; centring the merged
mesh on its contents is what lets it cull with its own chunk.

**Verdict:** landed. Supersedes the per-building merge in the street wall kit entry.

## Dumpster UVs: one isotropic density per swatch, the lid plastic off a whole rib panel

**Changed:** `buildlib.swatch_dens` + `unwrap(dens=)` / `finish(dens=)` (additive; every other
caller unchanged): per rect VALUE, the one texel density, equal on both axes in pixels, that every
fitted face wearing it still fits. `kit_build` passes it for every city piece and fits a `rod`'s
facets (axes 5) instead of laying the whole swatch over each. `kit/dumpster.py`: the lid plastic is a
30 x 400 px rib panel (was the 12 px gap between two ribs), laid per face along its long axis after
the lid is swung; the plate and rib tops lose their quarter turn on a lid thrown back; caster tyres
wrap seven mirrored copies of a 30 px square; the bags a 125 x 110 px bag, mirrored, folding on a
vertex of the oval section.

**Measured** (`uvaniso.py`, sparse-axis texels per unit at 1024, area-weighted): city bin median
41 -> 137, area under 30 px/u 11.3% -> 0%, anisotropy > 3 12.7% -> 0.2%; slums bin 39 -> 137,
15.4% -> 1.4% (bag necks), 17.0% -> 2.3%. The reported faces: lid edges 2.9 x 96 px/u, the top lip
85 x 41, a grab-bar facet 172 px across 0.03 units. Gates 0/0/1, tris unchanged (1,852 / 2,860).

**Trap:** `unwrap`'s `scale` crops a rect to `faceExtent / scale` on EACH axis, so the density is
`rectW / scale` along u and `rectH / scale` along v: one density only for a SQUARE rect. Every
non-square swatch smeared one way, and `buildlib.check`'s `texel_off` is isotropic (sqrt of uv area
over area) so it never saw it. A per-swatch minimum is only as good as the swatch: a strip serves an
edge along its length only, and one face across it drags every face wearing it down (the thrown-back
lid's standing sides took the plastic to 15 px/u until each face was laid along the strip). A
MIRRORED lathe over a `roundrect` section folds mid-face unless the seam sits on a vertex.

**Verdict:** landed for both dumpsters. The other city pieces still carry the per-axis maps (cart
31% under 30 px/u, recycling 31%, planter 18%, tree 13%, tyres 25% anisotropic) until re-exported.

## Street junk dealt per cell from separate pieces; loose swatches; dumpsters at 1024

**Changed:** the slums sack pile, the city bag pile, the tyre stack and the cart's junk were each
ONE modelled heap, the same heap on every street. Their modules now return pieces (sack-pile.py: two
standing sacks, one lying, an open carton, a carton stack, a carton leant on the wall; bag-pile.py:
three bags; tyres.py: three tyres; cart.py: the empty cart, a bottle, the board), and
`StreetProps.deal` lays a `render.world.Pile` per cell off the cell's hash: HEAP (scattered along the
wall's foot, `back` parts against it, `front` ones spilt forward, any yaw, size 0.85-1.15), STACK
(1-4 flat, the rest stood on the tread leaning back on them or lying beside) and LOAD (the cart's
basket, the board pinned at the nose). A prop on a walkway now stands `CURB_H` up. The mattress is
alleys only (SERVICE) with a hashed yaw and lean, slid off the wall by its corner's swing and its
height. kit_build `t.loose(rect)`: a plain swatch each face wears its own long way down, in the face's
own longest-edge frame (`buildlib.frame(f, edge=True)`). The dumpsters' steel is the whole flat band
of BR, hidden faces (back, bottom, the city top) wear the flank so they do not size it, tex 1024.

**Measured:** the reported dumpster faces 33-45 -> 130-203 texels per unit (1024); a tilted 2.0 x 0.1
lid side boxed by its up measured 0.46 tall and held the lid plastic at 65 until it took its own
edge. Pieces at 512: cartons 79-132, sacks 66-68 (sub-30 only on the flattened bottoms), bags 60-78.
Slums gameplay frames by a heap, a tyre stack and a cart: 170-192 calls, the street props 6-14 of
them with their shadows (a whole pile was 2); 159 against 157 where none is in view.

**Trap:** one glb per piece embeds its own copy of the shared sheet, so piece textures stay at 512.
A mirrored lathe over a `roundrect` folds mid-face unless the seam sits on a vertex. Hand-placed
free-cam poses kept landing inside walls: pull the camera in along the gameplay sightline instead.

**Verdict:** landed. Supersedes the modelled-whole piles in the street ground props entry.

## The other eleven street pieces re-mapped on one isotropic density per swatch

**Changed:** bollard, compactor, hydrant, mattress, meter, meters, newsbox, planter, recycling,
steamstack and tree re-exported on `buildlib.swatch_dens` with their swatches refitted (modules only,
no geometry or sheet change): plain ones `t.loose` and widened to the material's whole flat band,
hidden faces (backs, bottoms, buried tops) routed to rects of their own so they stop sizing the
visible ones, lathes given strips at their own density, a few flat rings re-mapped with `disc_uv`
(height had laid each on one texel row) and some lathes mirrored or repeated with every fold on a
vertex. The compactor, the biggest piece, ships at tex 1024; the rest stay 512.

**Measured** (area-median sparse texels per unit at 1024, before -> after; % under 30): compactor
37 -> 141, meters 44 -> 480, newsbox 35 -> 130, recycling 67 -> 132 (30.6% -> 0), planter 124 -> 211
(17.5% -> 0), tree 126 -> 137 (12.5% -> 0), steamstack 155 -> 162 (3.6% -> 0); bollard, hydrant,
meter, mattress unchanged at 222-285 with their anisotropy > 3 cut to 0-2%. Shipped at 512 the
medians run 65-240 against the ground's 57. Gates 0/0/1, tri counts unchanged.

**Trap:** the tree canopy's mirrored `taper_uv` still shears near its folds (9.3% anisotropic, was
11.9%): the lathe skin itself, not a swatch. The sheets' plain areas cap a few faces (compactor top
rail's top 59, meters conduit 68 at 1024).

**Verdict:** landed.

## Slums car wrecks: a hand-modelled carcass parked over two kerb cells

> SUPERSEDED by Slums car wrecks as decoration: read off the unwalkable pair, hatched in tactical, turned off square

**Changed:** `models-src/city/kit/car.py` (an agent, Blender over kit_build): a rusted teal 80s
hatchback stripped to its shell, 3,656 tris, 7.4 x 3.25 x 2.51 half-metre units: real cut-out
arches, separate pillars over the beltline, every window an open hole, drums on concrete blocks, a
gutted interior, bonnet gone. Its sheet is a full side view across the top (both flanks and the inner
door skins map onto it by position), front and rear strips, the roof, and loose swatches. Game side:
`objects.CarWreck` (non-interactive, `isWalkable` false), `CityAreaGenerator.placeCars` parks six per
newly generated slums area on two road cells end to end along exactly one walkway, road again beyond
both, 12 cells apart, both cells flipped to `TILE_ROAD_UNWALKABLE` as the burning barrels are.
`ObjModels` row `car_wreck` (`unmasked`, warmed by CityWarm like the dumpsters) with a new
`PropYaw.KERB`: front away from the walkway, length along the kerb, `off` half a cell onto the pair
and `CAR_KERB` 0.4 toward the kerb. 64 px icon at entities64 16/6 off `kit_build.py icon`.

**Measured:** sparse density median 143 px/u at 1024, 0% under 30, 0% anisotropic; sampled luma 77,
so a flat `baseColor` 0.39; tex 1024 (a 7.4-unit flank at 512 would sit under the ground's 57). A fresh
slums area (3155) dealt six wrecks, every car and tail cell unwalkable road, each pair along one
walkway; one batch, `noCast`.

**Trap:** the boot warm waits on every `unmasked` row's glb, so a row whose glb is not built yet hangs
the boot: keep it out of `unmasked` until `make models` has made it. Old saves get no wrecks.

**Verdict:** landed.

## Slums car wrecks as decoration: read off the unwalkable pair, hatched in tactical, turned off square

**Changed:** `objects.CarWreck`, its `ObjModels` row, `PropYaw.KERB` and `FRAME_CAR_WRECK` deleted.
`CityAreaGenerator.placeCars` only flips its two road cells to `TILE_ROAD_UNWALKABLE`, which nothing
else in a city writes (barrels flip ALLEY), so `StreetProps.wrecks` draws one car over every such
pair: midpoint, length along the pair, local -z to the walkway, `CAR_KERB` in, turned up to
`CAR_TURN` 0.15 off square off a cell hash and pulled back off the kerb by `CAR_HALF * |sin turn|`.
One `Models.instanced` batch culled with the ground props. `TacticalGrid.blocked` skipped all three
unwalkable street ids as void scenery, which is corp's meaning; in the city it now hatches them. The
car's end faces (`kit/car.py across`) take u off the painted panel's own edges per row: the front and
rear strips are trapezoids (rear 549..981 px at its top, 531..999 lower down) and the face mapped the
strip's full 528..1000 at every height, so both top corners sampled the black round the art.

**Measured:** area 3155 draws 6 cars off 6 pairs, yaws 0.1-6.2 degrees off square; each car cell
carries 7 hatch stripes in a tactical build, open road 0. The four end faces' corners sample 79-424
(sum of RGB) against the background's under 45, from 0.18-0.31 dark samples per face before.

**Trap:** a save holding the deleted class throws on load (`Could not resolve class`). Area 3155's six
were removed from CDP before the reload's forced autosave; a save made since the car commit and
never cleaned this way will not load. Not released, so no shim.

**Verdict:** landed.

## Street kit defects: wall kits re-packed, puddles under broken downpipes, tyre stacks kept apart

**Changed:** the three wall-kit glbs re-packed (`kit_build.py pack`, no script change): they were
built before `swatch_dens` and the rod fit landed, so the downpipe shoe's kicked-out foot (a `rod`)
still wore the pipe's whole 32 x 246 px skin strip over 0.42 units. `AreaStyle.pipePuddle`
(slums: the pack's puddle, row 7 col 4): `StreetProps.downpipe` returns a `DebrisSpot` for a broken
pipe, `PUDDLE_OUT` 0.8 off the wall, and the city's debris list takes them. `StreetProps.deal`
STACK: one leant tyre and one lying per side at most, the leaner slid 0.05 off the stack's line where
it slid r/2, since every leaner stood at one depth and two of them passed through each other.

**Measured:** shoe foot 451 x 1014 -> 116 x 116 px/u (pipe skin ~69); area 3155: 70 puddles, 79
tyres, 0 overlapping leaner pairs and 0 overlapping ground pairs (the reported pair stood 0.34 apart,
each ~1.0 across). `demo()` deals 40 full stacks against the rule.

**Trap:** a glb built before a buildlib fix keeps the old map until it is re-exported, and `make
models` reports it up to date: compare the glb's mtime with buildlib's.

**Verdict:** landed.

## Slums litter cap 0.036 -> 0.022: the hottest tier brought under its walkway

**Changed:** `city/debris-slums` `cells.cap` 0.036 -> 0.022 linear (`make tex`; the pack still draws at
mul 1.0). Reported from the game as the 2D decals being too bright. The cap was fitted reading 2.7x
its ground under 4x ambient where the city's control read 2.0, so the slums carried the hottest litter
of the three tiers on the darkest ground (asphalt 0.0185, walkway 0.0254, alley 0.0293).

**Measured:** built sheet 0.0345 -> **0.0214** linear (sRGB 45.7 -> 35.1). Same pinned frame on a
broken downpipe's puddle: puddle/walkway pixels **1.77 -> 0.58**, so it reads as a wet patch rather
than a lit one; the street's litter still shows at ground level.

**Trap:** the cap only ever darkens, so cells already under it keep their value and the sheet mean
falls less than the cap does (0.61x cap, 0.62x mean here because nearly every cell sat at it).

**Verdict:** landed.

## Slums car wrecks parked under the steady lamps first

**Changed:** `SceneSetup.lampFate(col, row, style)`: the dead / sputtering / steady test the scene
build always ran off a lamp's cell hash, now a pure static the scene build calls too.
`CityAreaGenerator` keeps citygen's `lamps` beside its `courtyards`, and `placeCars` deals its first
`CARS_LIT` 3 of 6 wrecks from the kerb pairs with a STEADY lamp on the walkway beside either cell, the
rest from the others. The generator reads `AreaStyle.forArea` for the odds, the one render class it
touches: the fate has to agree with what the 3D view will light, and that lives in the style.

**Measured:** area 3155 regenerated: 252 lamps (86 steady, 41 sputtering, 125 dead), 6 wrecks, 3 of them
with a steady lamp beside a cell (64,28 / 96,70 / 40,72) and the car standing in its pool on screen.

**Trap:** a car under a lamp on the far kerb hides behind the block in front of it from the follow
camera; look from the road's other side.

**Verdict:** landed.

## City street pass: see-through fire-escape grating, decks under the hatch rail, lamps on the kerb, steam off the hatches

**Changed:** nine reports off one medium-city walk. **Grating:** `wallkit-city.png` / `wallkit-slums.png`
TL cell cut to alpha (a luma 14..24 ramp over the TL 512 alone, gaps read 8 and 5 against bars at 40+),
the kit material clips (`kit_build` `Piece(clip=)` -> `buildlib.material` MASK), `wallkit.py` decks
laid in equal lengths of at most `GRATE` 2.4 at one density, `DT` 0.08 -> 0.03 since both cut faces
show, and a `LIP` 0.08 strip of deck across the stair hatch's front (the balusters there stood on air;
the toe plate it replaced is gone). **Warehouse door:** `Buildings` publishes its span to
`WorldCtx.doorSpans` (props and wall decals keep off it) and stands it 0.01 off the wall, which is
what let the probe pick it. `StreetProps.ground` now skips KERB picks on a door cell too. **Lamps:**
posts stand at `CURB_H` (they were sunk in the kerb) with the bulb, cones and pool lifted alike, and a
post slid to its cell's corner keeps `LAMP_BASE` 0.35 inside an edge with no walkway past it.
**Steam:** the steam stack prop is gone; `SteamPuffs` vents are every `sewer_hatch` lid (a walkway
one a kerb up). Dumpster fork-pocket mouths wear the green body, newsbox `baseColor` 0.28 -> 0.16,
`debris-city` leaf, twig, needle and leaf-pile cells at size 0.

**Measured:** grating bar pitch **0.37 -> 0.17** units, 34.6% of the TL cut; kit gates 0/0/1, 688 /
636 tris floor / base. The kit's Lambert carries `alphaTest` 0.5 and draws with program #10, one the
boot warm compiled: no new key on entry. Newsbox shipped luma **50.9 -> 37.4**. 63 vents in the
medium city. 33 warehouse doors published. The reported corner lamp (42,81) is a corner-stepped one:
its `dir` points along the walkway and its slide put the post on the kerb line of the road at +z,
base out to 2.27 against the lip's 2.2.

**Trap:** a cut sheet only survives `make models` on a MASK material: an OPAQUE one has its alpha
flattened before the resize. And a deck with both faces cut reads as two gratings unless it is thin.

**Verdict:** landed. Facility and military roads spawn hatches too (`RoadBlock`) and get no steam.

## Steam off the facility's hatches, and the plume mesh out of the chunk tree

**Changed:** `FacilityArea` builds a `SteamPuffs` over the area's `sewer_hatch` lids (the pavement
row `gen.blocks.RoadBlock` lays them down, y 0) and ticks it above the outro gate, so a compound's
hatches steam like a street's; a military base draws through the same code and has no hatches. Both
areas now build the plume AFTER `chunks.build`: `CityArea` built it before, and `Chunks.build`
bucketed it.

**Measured:** live, the city's steam mesh was parented to a frozen chunk `Group`, not the scene
(`objRadius` reads an `InstancedMesh` at count 0 as a small thing at the origin). Now
`mesh.parent === scene` in both. Facility (25,1): 4 vents, the one under the player puffing; the
plume draws with program #29, compiled by the city's boot warm, so it adds no key on entry.

**Trap:** one mesh holding a city-wide effect at the origin is exactly what the chunk pass is built
to bucket. Every plume went dark whenever the origin's chunk left the frustum. That is the likely
answer to "what happened to the steam" on the old steam stacks.

**Verdict:** landed.

## Steam lit by the scene: a lambert puff with its normal turned up

**Changed:** `SteamPuffs` draws a `MeshLambertMaterial` instead of a `MeshBasicMaterial`. It stays
additive, and the instance colour is still the fade, so a puff now adds the light it scatters: a moon-blue
haze in the dark, sodium-warm under a lamp. The quad's normal is rewritten to world UP, which is
(0, cos TILT, sin TILT) in the leaned plane, and `forceSinglePass` is set. `PlaneGeometry` now extends
`BufferGeometry` in the extern, and `BufferAttribute` gained `setXYZ`.

**Measured:** medium city (6,13), puffs frozen, each lit frame diffed against steam hidden. These are
luma adds over the plume. Hatch (40,20) at the edge of a lamp pool: unlit **p95 +145, mean
(56,57,60)**, lit **p95 +65, mean (16,22,37)**. The same plume moved under the bulb: plane normal
mean **(46,38,38)**, up normal **(67,55,45)**. A hatch 7 cells from any lamp: mean (19,23,33), a
faint blue wisp. No hatch sits under a bulb: the nearest are all 3.77 units off it, so the in-game
case is the pool edge. Program #28 in the city and in the facility, compiled by the boot warm, so
there is no new key on entry. The plume is 1 draw call (141 -> 142).

**Trap:** a frontal quad lit by its own normal faces the camera, so a lamp above and behind the puff
left it dark. Steam scatters light from any side. The up normal is the cheap stand-in for that.

**Verdict:** landed. To make it fainter still, lower `PEAK`, which scales lit and dark alike.

## Street corners: lamps off the turns, kerb props off the bevels, compactors off the alley mouth

**Changed:** `CityGen.addLamp` steps a lamp back off a corner where the road it lights turns or ends
(walkway beside the road cell in front: Ground bevels that cell into a diagonal kerb). It also steps
back off a crossing road, as before. It now drops any lamp that, where it ends up, does not front a
straight stretch of road. The L-turn connectors, which are in neither road list, get lamps along both
edges. `StreetProps.ground` leaves a KERB cell bare when its road turns there. A SERVICE prop stays
off the alley's mouth (`beside`: street either side along its wall). The downtown tree turns 0, so its
grate stays square to the paving.

**Measured:** in the medium city (6,13), 5 of 275 lamps faced pavement. A turned vertical road's loop
starts on its connector's own row, and the old step-back walked the lamp off that road cell
onto walkway. One more lit the bevelled cell of an L-turn and stood in the cut corner. After: 275
lamps, 6 moved (one stepped back, five along the connector). Over 200 seeds of each of default
and downtown: 0 lamps off a road and 0 at a turn. Kerb cells lost to the bevel test: 0.3% (city) and
0.2% (downtown). Service cells lost at the mouth: 7.3% and 12.5%. The downtown compactor is 4.0 x 2.67
world: a whole cell along its wall, so with its 0.7 slide it always crossed the walkway's kerb lip
at a mouth.

**Trap:** CityGen's step-back reads `dir` from the loop that dealt the lamp, not from the cell it
lands on. Check the destination, not the source.

**Verdict:** landed. Lamps are render-only (the slums wrecks read them once, at generation), so
existing saves only see lamps move.

## Downtown's two-cell pavement: a furniture row at the kerb, a clear row behind it

**Changed:** `CityGen` classifies a cell as walkway when a road lies within `profile.setback` of it
(the square round it, so the pavement still wraps convex corners), where before it had to touch a
road. Downtown's setback goes 1 -> 2. The rule is identical at setback 1, so the other tiers are
byte-identical. Trees and planters are `block` ground props. `CityAreaGenerator.placeFurniture` rolls
their summed chance (0.11) on every kerb-row cell whose road runs straight past it. It skips hatches,
lamps and crosswalk ends, and flips the cell to `TILE_WALKWAY_UNWALKABLE`. `StreetProps.ground` draws
one `block` prop centred and square on each such cell, picked off the cell hash by chance. Bollards
stay hash-dealt walk-past decoration. `AreaGame.cityGenVersion` (0 by `init`, `Profiles.VERSION` 1 at
generation) gates all of it: a downtown saved before this gets `DowntownProfile.LEGACY` (setback 1)
and its old hash-dealt props.

**Measured:** new downtown (10,6): 136 furniture cells, drawn as 95 trees and 41 planters, matching
one for one, plus 75 bollards. The 3D tiles match the game cells (0 of 10,000 differ), and both
survive a save and reload unchanged. `__check` on (9,7): pass, 110 buildings. Old downtown (9,8),
from a save without the field: version 0, 0 mismatches, 77 trees and 27 planters hash-dealt as before.

**Trap:** `setback: 2` alone (the old profile comment) puts a dead alley strip between the buildings
and a one-cell walkway: the second ring touches no road. And a city's 3D view comes from its seed
alone, so a layout change without a version gate splits every saved city from its own picture.

**Verdict:** landed.

## Downtown compactors impassable, and no two planters side by side

**Changed:** the compactor is a `block` SERVICE prop. `CityAreaGenerator.placeFurniture` deals it on
a cell a dumpster could take (`isDumpsterSpot`: one wall, its eight neighbours stay one group, so it
cuts no route) that is off the alley's mouth (`isServiceSpot`). It flips that cell to
`TILE_ALLEY_UNWALKABLE`. `StreetProps.ground` stands it against that wall, unslid. `render.CityArea`
reads alley furniture as well as kerb furniture, and adds both to `WorldCtx.doorBlocked`, so no back
door opens onto a compactor. A new `apart` flag (the planter) swaps a pick for the spot's other
furniture (the tree) where an orthogonal neighbour already holds it. Recycling stations and bollards
stay walk-past dressing.

**Measured:** new downtown (10,7): 129 kerb furniture cells = 93 trees + 36 planters, 15 alley cells
= 15 compactors, 0 planters orthogonally adjacent, `__check` pass with 0 doorless.

**Trap:** the furniture cells are drawn as well as walled off, so both sides must read the same
cells. The 3D view reads the game's tiles, never its own hash.

**Verdict:** landed. Areas generated before this have no alley furniture, and in them the compactor is
neither drawn nor dealt.

## Downtown recycling stations impassable; the planter's corners and its concrete level

**Changed:** the recycling station is a `block` SERVICE prop beside the compactor, so the generator
deals both from one summed chance (0.03 + 0.03) on the same dumpster-safe, off-the-mouth alley cells,
and `StreetProps` picks between them by weighted cell hash. Only bollards remain walk-past dressing.
The planter (`models-src/city/kit/planter.py`) had two faults. Its four upright arrises (the box's
0.035 chamfer) wore the `loose` plain-concrete swatch laid SIDEWAYS, so each corner was a strip of a
different tone with no formwork joint, between two faces that carry one. Each arris now wears the
sides' own edge column (sheet x 3..14, y 36..292) whole and upright. The rows match the faces'
rows, because both span the same chamfered height, so the joint line runs round the corner. Its
concrete was also too bright: the flat `baseColor` 0.47 had been fitted to the WHOLE map's mean
(luma 73), and the dark boxwood half dragged that mean down.

**Measured:** the sides are linear 0.29 on the sheet and the rim 0.37, so they drew at 0.137
(srgb ~103), against downtown paving at 0.038. A `gradeRect` at scale 0.40 on the concrete rows
(x 0..512, y 0..720) leaves the soil and leaves untouched and takes the sides to ~66 and the rim to
~75; in game the planter now sits just over the paving. New downtown (11,7): 32 alley cells =
17 compactors + 15 recycling stations, 112 kerb = 86 trees + 26 planters, every instance on an
unwalkable tile, `__check` pass with 0 doorless.

**Trap:** a flat `baseColor` fitted to a two-material sheet's mean leaves the bright half bright.
Read the surfaces apart, and grade the rect.

**Verdict:** landed. Downtowns generated earlier draw recycling on some of their compactor cells,
since those cells now pick from both.

## 2D-only readouts onto the badge pass: padlock, organ health bar + broken X, forma cursor

**Changed:** retiring the 2D area renderer took four readouts that nothing in 3D drew: the padlock on
a locked door, a damaged base organ's health bar, the red X on a broken one, and the forma
(base-building) cursor. All four are now quads in `render.actors.Badges`, painted from
`Actors.update` beside the target marker (`drawObjBadges`) and after the player x-ray
(`drawFormaCursor`), so Shift+Space hides them with the rest of the UI. The padlock is the entities64
`FRAME_LOCKED_ICON` cell at the doorway's mid-height (`FacilityStyle.DOOR_H * 0.5`). The bar and the X
are inline SVGs through `Sprites.svgTex`, centred on the footprint, the bar lifted screen-up by
`BADGE_LIFT` like the AI badge row; the bar texture is bucketed to 5%, so at most 21 are cached. The
forma cursor is the targeting reticle laid flat on the cursor cell, the way `paintTargetMarker` lays
it under a target. All four are `depthTest:false` and emissive white, i.e. `Sprites.overlay` after the
bloom, like the badges. Entering forma also turns the tactical camera on (the `forma` action in
`PlayerArea`) and Exit Forma turns it off: at the close sewer camera the cursor walked off screen in a
21x14 habitat.

**Measured:** topbar `dc`, single frames in a habitat with the heart at 60%: 66 with no readout, 67
with the bar, 68 with the bar and the X. One call per quad shown and +0 programs: the overlay program
is the one `Warmup.overlay` compiles at boot.

**Trap:** a door is `iconOff` in every 3D kind that has doors, and `Door.visible()` is false, so it
carries no mark. The padlock still finds it: `drawActor` writes the pose before its `iconOff` return,
and the gate is the object loop's own `vis`, not `mark`.

**Verdict:** landed. Not ported: 2D forma mode also drew the whole habitat through line of sight; the
3D view keeps its fog.

## Glass bullet holes: a crack star where a bullet crosses a facility/corp window pane

**Changed:** a bullet that crosses a window cell (`Const.isWindowTile`; corp and compound ribbon
windows, the city grid has none) now leaves a crack star on the pane, next to the glass-hit sound
`Shot.firstGlass` already plays. It reuses the `WALLHOLE` decoration: same FIFO cap, same area-exit
clear, same radius fade. A `glass` flag picks a third texture set in `render.decals.WallHole`. The save
tuple's slot 10 was the 0/1 metal flag and is now a material index (0 masonry, 1 metal, 2 glass), so
the tuple stays at 11 and old saves decode unchanged. `Shot.spawnGlassHole` meets pellet 0's tracer
with the pane plane through the cell centre and stands the star on the face toward the shooter. It
places nothing when the tracer runs along the pane, and nothing for a stun bolt. The art is one
gpt-image-2.5-sunburst pack ($0.055), four labels `decals/bullet-hole-glass-1..4`. Each crop is square
and centred on the puncture, since the quad is centred on the crossing.

**Measured:** `renderer.info.render.calls` 63 → 67 with four stars on screen, A/B/A/B identical:
+1 call per star, the same as a masonry hole.

**Trap:** the first stars were invisible. The pane batch is transparent at `renderOrder` 0 like the
sprite pool, and three sorts it by its bounding sphere's centre, which is mid-plate. It often sorted
after a star on the north wall and blended its dark glass over it, even though the star is in front.
Glass stars now draw at `Sprites.ORD_FIXTURE` through a new `PaintWallOpts.order`.

**Trap:** at the gameplay camera a wall face is steeply foreshortened. At scale 0.2 a star was an
8 px dot and at 0.45 only the hole showed, so `glassScale` is 0.6. A chest-height crossing (1.2)
then hangs below the ~0.95 sill. The spandrel under the sill is coplanar with the decal, so the star
painted onto the masonry. `glassFloor` 1.0 keeps the star's lower edge on the glass.

**Verdict:** landed. The cracks stay faint in an unlit room, and `lift` is the wrong knob for that: it
is a gamma that greys the dark puncture and leaves the pale cracks where they are.

**Follow-up:** the puncture drew as an opaque black disc where the pane should show through. The
pack's dark pixels are their own band (luma mode 16-31, almost nothing at 32-39, the crushed rim from
40), so `tools/textures.py` gained `hole_alpha` (the dark mirror of `glass_alpha`) and the four labels
key luma < 36 to alpha 0. Checked on the built textures over a flat backdrop, not yet in game.

## The 2D area renderer retired: AreaView is a shim, the lighting stack is gone

**Changed:** every area kind draws through `render.View`, so the 2D area canvas never painted, yet
its code still compiled and part of it still ran every turn. Deleted: the `AreaView` draw body, tile
pass, smooth-LOS overlays and visibility cache (1,262 lines → 79: camera update, the 3D path preview
feed, the legacy particle list), the whole atmosphere lighting stack (`AreaLighting`,
`AreaLightingDebug`, `lighting/`, `debug lights`), the built-in 2D particle subclasses, the 2D entity
draw family and the sewer 2D atlas. `particles.Particle` stays for mods, marked LEGACY: `draw` is
never called, `onDeath` still fires off a 10 ms reaper. The `Particle.create*` factories hand off to
`view3d.play*` and, when the view declines, keep only the lasting part (the persisted splat, the
sound). The five readouts that lived only in the 2D draw were ported: the badge-pass readouts (entry
above), the minimap (a HUD canvas, `ui.hud.MinimapHud`, cropped to the walkable bounds) and the
glass-hit sound (`Shot.firstGlass`, timed to the tracer, once per shot).

**Measured:** phases 1-5, five commits: 6,771 lines deleted, 203 added.

**Trap:** nothing errored when areas went 3D. The readouts sat inside a draw body that a 3D area
early-outs, so they vanished silently, and the code that fed them kept running. Three live bugs were
hiding there: transient lights were pruned only in the 2D lighting draw, so in a 3D sewer or habitat
the 100 Hz redraw interval never stopped; `getSpawnRect` had no `corp`/`undergroundLab` case and
spawned over the 2D canvas rect; and `AreaView.turn` ran twice per turn.

**Verdict:** landed. The region map stays 2D and keeps `Entity`/`PawnEntity`/`Tileset.draw`. The mod
SDK docs call 2D particles legacy, and `examples/chainsaw` dropped its two 2D particle classes for
the engine's splat fallback.

## City alley-mouth fences: chain-link downtown, boards on the residential streets and the slums

**Changed:** `game.CityAreaGenerator.placeFences` is the last object post-pass. Each 4-connected
alley group rolls 30/30/40% (downtown/medium/slums). Its mouth runs are alley cells with exactly one
street 4-neighbour, grouped straight along the kerb. All of them take a fence tile except one random
run, which stays open. An 8-way street-reach flood before and after reverts the group if anything
other than the fence cells was cut off. The pass is unseeded and saved in the cells, so the CityGen
rng is untouched. New tile row 29: `TILE_CITY_FENCE_CHAIN` 464 (unwalkable, see-through) and
`TILE_CITY_FENCE_WOOD` 465 (unwalkable, opaque). `render.world.CityFences` emits one quad per cell
across its middle, parallel to the kerb, as one merged Lambert mesh per area. The art paints its own
post and rail, so there is no post geometry. u tiles one image per CELL with a half-image offset, so
the painted post lands on the cell boundary. v maps 0..1 (chain-link 1 cell high, the 4:3 board
panels 0.75). New labels: `downtown/fence-chainlink` (alpha, cut 0.3), `city/fence-wood` (opaque)
and `slums/fence-wood` (alpha gaps).

**Measured:** 45-48 chain cells per fresh downtown, 60-95 boards per medium, 115 per slums tile.
calls **92 → 93** with the mesh visible (median of 9, three A/B pairs, pinned frame).

**Trap 1:** the mesh is added AFTER `chunks.build`. A merged mesh at the origin under 64 units
across is bucketed by its origin and culls with that chunk (the steam's trap).

**Trap 2:** the boards drew near-black at night. A vertical face in an alley mouth gets ambient and
hemisphere light only; the moon is shadowed and grazing. At the drop's ~48 sRGB the panel was
invisible even with the material colour at 3x, and read from about 5x. `lift` 0.55 on both board
labels (~48 → ~102 built) and 0.85 on the chain-link (~89 → ~105).

**Trap 3:** a fence running north-south (street east or west of the mouth) is seen edge-on by the
default camera and reads as a thin top line. Same as the military perimeter. Accepted.

**Verdict:** landed. An old city save loads with no fences and plays on.

## Mountain cave habitat shell: marching squares over a blurred floor field, no 90 degree walls

**Changed:** new `render/cave/` (`CaveArea`/`CaveScene`/`CaveGeom`/`CaveModel`/`CaveStyle`/`CaveWarm`),
a sibling of the tunnels that keeps their pipeline (`VisionMask`, `ObjModels`, `LampLights`,
`PropLights`, `CAMERA_SEWER`) and none of their art. The floor grid is box-blurred into a field
(`gen.cave.CaveField`, half-width 0.35 cell) with smooth noise added, then cut at ISO 0.17 by
marching squares on a lattice of 4 samples per cell. Three welded indexed meshes come out of it, one
call each. The floor is flat, darkened along the walls by vertex colour off the field. The rock top
is WALL_H 3.0 less a smooth sag, less a rounded lip near the outline, and only ever lower. The wall is
a 5-row strip stood up along each walked iso loop, with u = arc length and the middle rows bulging by
noise. Its foot and lip lie exactly on the outline, so it welds to both the floor and the top. Saddle
cells are resolved by the cell centre. Three separate gens: `cave/wall`, `cave/floor`, `cave/rocktop`.

**Measured:** shell **16.8k tris in 3 calls** (floor 5,500 / rock top 8,928 / wall 2,416) at 24x18.
The frame is **21 calls / 18.0k tris**. Warm 101 programs, live 106. The tunnels' warm is 109 → 116
on a fresh boot into a sewer habitat, the same five generic programs (ladder glow, basic, depth x2,
indoor physical), so the cave adds no entry compile of its own.

**Trap 1:** the invariant is that no walkable cell is ever drawn under rock. With the blur box at
0.35, a floor cell's own quarter alone reads 0.25 at its corner, so noise pulling toward the floor is
capped at 0.06 (0.25 − 0.06 > 0.17). Pushing into the rock is free (0.18), faded by the coverage so a
lone pillar keeps its core. `GenCheck.caveSane` asserts the invariant headless over every walkable
cell's lattice and every rock cell's centre. LUMP_OUT 0.14 fails 658 cells over 200 seeds.

**Trap 2:** the tunnels' fill (3.95 / 1.89, blue pair) left the floor near black and turned the warm
silt purple. Swept live: ambient `0x4e4d4a` 7.0, hemi `0x5c6272`/`0x1c1814` 3.0.

**Trap 3:** the first rock-top roll asked for "rounded knobs and domes packed together" and read as
laid cobbles from the overhead camera. The second roll asks for fractured bedrock plates and bans
rounded stones, and it reads as one mass.

**Verdict:** landed. The floor is flat (no `WorldCtx.ground`); bumps were skipped as invisible under
CAMERA_SEWER.

## Mountain cave dressing: a hand-modelled kit of eight off their own references, and four floor decals

**Changed:** `models-src/cave/cave_build.py`, a trimmed `lab/top_build.py` with `wild/rock_build.py`'s
chipped blob, plus one module per piece in `kit/`, built headless by two agents in parallel.
Each piece got its own reference (`style_prop`) and a PACK4 sheet painted off it by
`edit_image`, levelled per cell onto the shell's values. `render.cave.CaveProps` is a clone of
`SewerProps`: per 2x2 block, gated per wall face, dealt from flat, corner and hang decks, never
the south face. The difference is that each prop finds its own wall: the outline sits a lumpy
distance past the cell edge, so it walks `CaveField` to the ISO crossing and stands off that. Root
curtains hang only on north faces, lifted so their top sits under `CaveGeom.topY` at the lip. The
exit is a new `ObjModels` row, `cave_exit`, reached through `HabitatExit.getModelKey` off the
saved name 'cave mouth'. `objWall` stands it off the same foot. Floor decals come from
`SewerGround.scatter`, made public with an optional `near` filter: guano, crust and fungus anywhere,
moss within two cells of a mouth.

**Measured:** pieces at 560 to 2,456 tris, all `check` 0/0/1 with `texel_off` 0, and every shell's
signed volume positive. Eight gens at ~$0.06 each, plus 4+4 for the decals. A 24x18 cave deals
17 floor props and 3 root curtains. The frame went from **21 to 30-32 calls** (7 prop batches,
4 decal meshes), and to 47k tris zoomed out. Warm cached 103 against 108 live: the same five
generic programs as before, so the kit adds no entry compile.

**Trap 1:** at the sewer's per-face gate (14-18) a cave dealt **six** props. A tunnel is mostly
walkway, but a cave's dressing is the room. It took 40 to reach 17.

**Trap 2:** crystals at `emissiveStrength` 2.5 bloomed to white stars from the far camera. 1.2
keeps them cyan (fungus 1.5).

**Trap 3:** a decal prompt that names the surface it lies on ("on a warm brown silt floor") makes
gpt-image-2.5 paint that surface in, opaque, even with `background: transparent` (alpha min
138-234). Re-rolled with the surroundings left out: 67-75% clear. The fungus came back opaque on
flat navy twice and is chroma-keyed instead.

**Verdict:** landed.

## Mountain cave feedback pass: floor patches, pool water, prop fits, darker dressing

The user's eye pass on the dressing, item by item.
- **Floor patches:** `render.cave.CavePatches` lays three ragged overlays over the floor: wet clay,
  bedrock showing through, and loose gravel. It uses `WildPatches`' idiom on `CoverageMask`, with
  one mesh per layer, each cell split on the field lattice. Every vertex takes the floor's own
  wall-foot darkening (`CaveGeom.floorShade`, now shared).
- **Mouth blend:** gravel also rings both mouths. The mouth sheet's scree cell was desaturated to
  0.45 (it was a saturated orange), and its foot was faded into a crop of the cave floor at the
  ramp's texel scale.
- **Pool water:** `render.cave.CaveWater` folds a surface into the rimstone's OWN material, keyed
  on uv (the bottom row of its sheet), so there is no second mesh.
- **Rubble:** one cell per stone; the slab is pale, the boulders dark.
- **Crystals:** the facet cell was re-laid as three solid bands, one band per prism. Five bands per
  facet had read as purple stripes.
- **Fungus:** the cap-top glow was brought up to the gills' (x1.6 on the emissive map).
- **Root curtains:** they hang only on a north run of 2+ cells, clamped inside it, clear of its
  rounded ends (`HANG_END`). The back sits on the frontmost foot across the curtain's width, or the
  curtain is dropped (`HANG_FLUSH`).
- **Floor props:** they step out until a footprint ellipse, `w`/`r` x `h` x scale plus `PROP_CLEAR`,
  clears the rock, or they are dropped.
- **Darker dressing:** every piece is at `baseColor` 0.55. The decals take `lift` 1.11-1.65.

**Measured:** patches built at 0.75x / 1.82x / 1.53x the floor's linear value. They add 3 calls,
and the frame is now 31-40 calls with 50-53k tris. Warm cached 105 against 110 live, the same five
as before, so the patch and water programs both warm. The habitat 3843 corner curtain at 13,4 is
gone; 2 curtains remain. Crystal emissive went 1.2 → 1.8.

**Trap 1:** the water's virtual light first hung at a fixed WORLD direction 15 degrees off the
mirror, so a flat pool sat inside the glint and went a pale sticker blue. The light now hangs off
the mirror by a VIEW-space offset of ~20 degrees, through a `smoothstep(0.996, 1)` edge, so only a
ripple's steep side sparks.

**Trap 2:** a 3-cell north run left two candidate cells in a twisty cave and **zero** curtains.
Two cells plus the clamp is enough.

**Trap 3:** both transparent patch gens came back with a painted halo, alpha never reaching 0
(min 31 and 54). A linear alpha remap (200-240, 215-245) cut it, with no re-roll.

**Trap 4:** crystal emissive x2.4 blew every prism to white under ACES. At 1.8 the cyan prisms
bloom and keep their hue. A blue or violet prism never crosses the 0.9 luminance threshold at
any strength that keeps its colour.

**Verdict:** landed.

## Mountain cave lighting pass: glow lights in the idle spot slots, baked glow, moonbeams, per-piece shading, crystal glints, blocked pools

> the moonbeams SUPERSEDED by Mountain cave rubble piles, mouth glow and the arch fade order

Asked for as "we lack any interesting lighting... the stones are all uniform", plus four fixes.

- **Why uniform, computed off the rig:** ambient 0x4e4d4a x7.0 is 0.52 on every face; hemi x3.0 adds 0.37 up,
  0.20 vertical, 0.03 down. Top 0.89 / side 0.72: ambient is 73% of a side face and all four sides match.
- **Glow lights** (`CaveScene`, `CaveProps.glows`): one `LampPost` per crystal cluster and fungus patch,
  `LIGHT_OUT` 1.0 in front and `LIGHT_Y` 1.8x the crown, aimed at its foot, `penumbra` 0.6. The pool
  had 12 slots and the cave used 2, so 13 posts cost no light and no program. `LampPost.penumbra` is new,
  published per slot as a uniform. **Fill** 7.0 / 3.0 -> 3.5 / 6.0: top/side 1.24 -> ~1.52.
- **Baked glow** (`CaveGeom.glow`): colour x `glow` x (1-d/5)^2 x wrapped N.L into the shell's and the
  patches' vertex colours, after `computeVertexNormals`. 0 calls, works with the spot pool off.
- **Moonbeams** (`CaveBeams`): a slanted open shell from inside each arch to 3.5 in front, additive,
  fading to black at the floor, plus 18 CPU-drifted `Points` per shaft. +2 calls.
- **`CaveShade`** on every dressing batch: +/-18% per placement (hash of the instance translation),
  +/-14% world noise, a foot at 0.55 rising over min(1.2, 0.4h). Crystals add a climbing emissive band, a
  breath, view-space orbiting glints, and cut 85% of the prisms' diffuse.
- **Crystals:** blue 0.145 -> 0.298, violet 0.102 -> 0.318 luminance (cyan 0.447); emissive 1.8 -> 1.0;
  cave bloom threshold 0.9 -> 0.6. **Crust decal** lift 1.65 -> 2.3: 3.08x the floor -> 1.55x.
- **Pools block walking:** `CaveGen.pools` stamps `TILE_FLOOR_POOL` 902 (see area-gen.md); the basin lies
  only there at scale 1.25-1.4. The live 18,10 basin had sat 0.58 from a cell centre against a 3.0-wide actor quad.

**Measured:** frame 37-38 calls; warm 109 vs live 114, the same five; 0 failed programs; 2000 cave seeds OK.

**Trap 1:** aimed OUT from the crown 3 units, a glow light landed as a torch disc two units off the piece,
and at mul 0.15 it added +24% at grazing incidence — invisible. Hung over the piece aiming back at it, it pools.
**Trap 2:** penumbra 0.9 thinned the whole cone to nothing; 0.6 is soft and still reads.
**Trap 3:** that spotlight hangs ~1.5 units from prisms whose albedo is 4-5x the floor's, and with ACES
the brightest texels hit 214/243/253, white. The diffuse cut plus emissive 0.9-1.0 gave 165/219/238.
**Trap 4:** an absolute 1.2-unit foot blacked out the 0.33-tall basin, hence the share of h.
**Trap 5:** a cave from before the pools deals no basin, `Models.instanced` builds no mesh, and the
patch hit null and blanked the area. Empty batches are skipped.
**Trap 6:** the cave scene holds TWO ambients (the debug full-bright one at pi, hidden); a fill A/B by
`isAmbientLight` alone edited the wrong one.

**Verdict:** landed.

## Mountain cave rubble piles, mouth glow and the arch fade order

Four asks: rubble "looks repetitive", moss under a crust decal, the moonbeam "detached from the actual
mouth" (make the mouth the source: glow quads on its edges, dust, fake actor shadows), and the arch going
see-through "in stages" with a bare dark rectangle.

- **Rubble piles** (`CaveProps.pile`, `kit/rubble.py`): the baked pile is now four stone glbs on its sheet
  (boulder 176, block 150, slab 110, chunk 70 tris). The rubble entry is dealt as before (`pile: true`, its
  old r/w as the footprint) and heaped from a hash of its position: 1-3 big stones along the wall at -0.5
  depth, 65% a slab (across two big ones at 0.85 of the lower top, else tipped in front), 2-6 chunks round
  the front at random pitch. `CaveShade` values each stone off its own origin. This cave: 9 boulders, 4
  blocks, 3 slabs, 26 chunks over 6 piles.
- **Moss under crust** (`CaveGeom.decals`): the two `SewerGround.scatter` passes roll the SAME block hash,
  so where both reach a block they lay on one spot. The first pass now skips cells within MOSS_REACH + 1
  of a mouth (an organic decal spills half a cell). Quad-bbox overlaps with moss, live: 0.
- **Mouth glow** (`CaveMouthGlow`, was `CaveBeams`): an additive card across the hole, rim band 1.0,
  middle 0.3, a 0.6 halo fading out, `GLOW_ALPHA` 0.16; dust leaves the hole and fans/sinks 3.5 into the
  cave. The mouth `LampPost` gets `beam` 16: long fake shadows into the cave, cone-gated.
- **Arch fade** (`kit/mouth.py`): GHOST draws with `depthWrite` off, so triangles blend in index order,
  and the plate and ramp were appended last. Now sorted first; at t 0.16 the boulders stay over the hole.

**Measured:** +3 calls bound (4 stone batches for 1; card for shell); HUD 37-41 calls; warm 109 vs
live 114, the same five.

**Trap 1:** sorting on the face tag `== -1` changed nothing: `tile_uv` marks the rocks' faces -1 too.
Sort on membership in the set of faces made before `plate()`.
**Trap 2:** behind the boulders (0.1 behind the arch centre) the card lit only the cut-out hole and read
as a flat blue panel. In front of them (-0.25) the halo lies on their faces. A side view still shows it as a sheet.
**Trap 3:** `beam` 10 reaches from the post, 2 units behind the mouth, so the shadows died a cell out.

**Verdict:** landed.

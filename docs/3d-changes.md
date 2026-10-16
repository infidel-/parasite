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

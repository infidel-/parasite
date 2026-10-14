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

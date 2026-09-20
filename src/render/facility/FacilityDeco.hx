package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.TableDeco;
import render.particles.AtlasBox;
import render.particles.Sprites;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// where one fitting stands, as `rectOf` works it out — the answer both this file's emitters and
// render.facility.FacilityCable's panels are written against
typedef DecoRect = {
  // the footprint, world, already slid along its wall and squeezed to the masonry
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  // which of the cell's four sides that masonry is on, in FacilityGeom.face's numbering. never -1:
  // a unit with no wall on any hand is stood square in its cell facing 0
  dir:Int,
  // and whether that hand is really SOLID masonry rather than glazing or the fallback above — the
  // test anything laid ON the wall has to make
  hasWall:Bool,
  // how tall it stands
  h:Float,
};

// one hazard-barrel livery and the fitting kind that deals it. all three share a mesh and differ
// only in their baked paint, so this carries no size — they take FacilityStyle.DECO_ROUND_H like
// every other round low fitting
typedef DrumProp = {
  // which _FittingKind stands this drum
  kind:Int,
  // and the RenderConfig.MODELS entry that draws it
  path:String,
};

// the room furniture that used to be an upright 2D sprite: a bookcase, an open metal shelving unit
// with boxes on it, a server rack and the same rack one tile tall, a twin-door lab case, a machine
// casing and that casing knee-high, plus the two ROUND things that stand on the same cells — a
// hazard drum and a lidded bin.
//
// MERGED GEOMETRY and not a glb wherever there is a choice, the call render.facility.FacilityTables
// already made for the benches: a merged buffer is ONE draw call for every unit in the compound,
// where an instanced glb is one call per model kind in view and arrives at a few thousand triangles
// off an unwrap lottery.
//
// THE DRUM AND THE BIN ARE THE CASE WITH NO CHOICE, and they are worth naming as such: the emitters
// below take axis-aligned rects, so a cylinder has no quad route at all. Both are glbs the compound
// ALREADY SHIPS — the tunnels' drum and the lot's own bin — so neither cost a generation, and the
// bin does not even cost a batch, because render.facility.FacilityGround.bins already instances that
// model and simply takes these placements into its own list (see `placeRound`).
//
// ONE TEXTURE PER FACE, not per family, and that is the whole shape of this file. The first build
// dressed each unit in a single sheet and every face it was wrong on was wrong the same way: book
// spines lying flat across a bookcase's top and running down its sides, cardboard boxes wearing the
// shelving's steel, a rack's own vent panel seen from above. A face is a different SURFACE from the
// face beside it, so it gets a different image, and the buffers here are keyed by texture rather
// than by kind.
//
// AND "THE SAME MATERIAL" IS NOT A REASON TO SHARE ONE. The rack's sides and lid rode the
// shelving's perforated shelf plate — both are dark steel, and the shared buffer was a shared draw
// call — and the unit read as a server made out of shelves, because a cabinet's flank has no holes
// in it and the holes were what the eye picked up. Two more surfaces, two more calls.
//
// WHICH CELLS is not this file's decision and never was. The generator stands an objects.Decoration
// on a room cell one step in from a window wall (game.FacilityAreaGenerator's chem-lab pass) and
// stamps the tile unwalkable; render.facility.FacilityModel.findDeco reads those objects back and
// leaves a per-cell kind in `m.deco`. So the furniture is REAL GAME STATE with a real footprint,
// unlike the lab kit beside it, which is render-only and walked straight through — and it needs no
// migration, because the kind comes out of the decoration's own atlas frame (Const.fittingOf) and
// those frames were in every save already.
//
// AGAINST THE WALL, and the direction is free: the generator only ever places these one cell in
// from a wall run, and a HIGH decoration is never dealt beside glazing (nextToWindow forces the low
// list), so the masonry behind one is always plain. A LOW one is the opposite case and takes the
// glazing rather than nothing — see `wall`. The rect is taken off FacilityGeom.slab's own
// face, which is a unit inside the cell boundary — the trap the corridor casework and the lab kit
// both record. Where the wall line stops beside the cell the unit is SLID along the wall to fit,
// and only squeezed if the masonry is genuinely narrower than it is: a squeeze is a stretch on the
// two faces that map their art 0..1, and FacilityKit's own answer here — reject the cell — is not
// available to a fitting that is already in the save.
class FacilityDeco
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the WC pan the flag picks, resolved once so the batch and its warm row cannot disagree
  public static final TOILET_PATH = FacilityStyle.TOILET_BLENDER ?
    RenderConfig.MODELS.facilityToiletHand : RenderConfig.MODELS.facilityToilet;

  // the blink clock every rack's lights reference BY IDENTITY, in BASE_MS units — so writing .value
  // reaches every light at once. the shared-uniform idiom render.wild.WildGrass' wind runs on
  static var uTime = { value: 0.0 };

// advance that clock. called once per frame from render.facility.FacilityArea.tick, beside the
// grass's own
  public static function tick(dtMs:Float):Void
    {
      uTime.value += dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS;
    }

// does the facility draw this object as furniture instead of as its sprite? STATELESS, like
// render.facility.FacilityDoors.draws which it mirrors — the answer is a property of the object's
// atlas frame and of nothing else, so render.Actors can ask it without a model
  public static function draws(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      if (area == null ||
          area.typeID != AREA_FACILITY)
        return false;
      // the drain has geometry of its own now (see `drain`), so its icon must stop being laid flat
      // under it — two coplanar copies of the same art, the sharp one 0.04 under the blurred one
      if (o.type == 'floor_drain')
        return true;
      // and a bench decoration standing on an OFFICE desk keeps no sprite either: the generator deals
      // the laboratory's own table frames in every room (the corner cells MUST carry one, or a clue
      // can spawn there), and a rack of test tubes on a researcher's writing desk is the laboratory's
      // glassware. what stands in for it is FacilityClutter's office sheet, which is not an object at
      // all. NOTHING is drawn here for it — suppressing an icon is all this hook can do
      if (onOfficeDesk(area, o))
        return true;
      return o.type == 'decoration' &&
        Const.fittingOf(o.imageRow, o.imageCol) >= 0;
    }

// is this object a bench decoration lying on an office DESK rather than on a laboratory bench?
//
// OFF THE NEIGHBOURING TILES and not off the surface grid, because this hook has no model: a desk
// cell is a bench tile like any other, and what makes it a desk is the room around it, which the
// generator floors in Const.TILE_FLOOR_WOOD1. a run of desks always has that floor on some hand — the
// room's own — so one four-neighbour look answers it
  static function onOfficeDesk(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      if (o.type != 'decoration' ||
          !Const.isTableDeco(o.imageRow))
        return false;
      for (dir in 0...4)
        {
          var t = area.getCellType(o.x + DC[dir], o.y + DR[dir]);
          if (t == Const.TILE_FLOOR_WOOD1 ||
              t == Const.TILE_FLOOR_WOOD1 + 16)
            return true;
        }
      return false;
    }

// how big this object's sprite draws in the facility, as a fraction of the full billboard. 1.0 for
// everything except a decoration standing on a laboratory BENCH.
//
// those 43 icons keep their sprite — a flask, a retort stand and a microscope are what a mesh
// generator is for and what an emitted box cannot state at all — but they were drawing at full size,
// which put a 1.08 m microscope on a 1 m worktop. See FacilityStyle.DECO_TABLE_SCALE, where the
// measurement is; shrinking them is also what takes them from 21.3 texels per world unit to 59.
//
// STATELESS like `draws` above and for the same reason: the answer is a property of the object's
// atlas ROW and of nothing else, so render.Actors can ask it without a model
  public static function spriteScale(area:game.AreaGame, o:objects.AreaObject):Float
    {
      return onBench(area, o) ? FacilityStyle.DECO_TABLE_SCALE : 1.0;
    }

// is this object one of the laboratory BENCH decorations — the family that keeps its 2D sprite and
// stands on a worktop instead of on the floor? the shared gate of the three hooks around it, all of
// which render.Actors asks per object with no model in hand
  static inline function onBench(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return area != null &&
        area.typeID == AREA_FACILITY &&
        o.type == 'decoration' &&
        Const.isTableDeco(o.imageRow);
    }

// how much of its own chroma one of those keeps.
//
// EVERY FRAME, PACK CELL OR NOT. The knob was fitted against the stock icon sheet, which is
// flat-design vector work that reads cheerful in a dark laboratory — entities64 9/10 comes in at
// chroma 42.4 and linear 0.5592, five times the brightness of anything else in the room — and it was
// then made per-FRAME on the argument that a pack16 cell is already drawn in the game's palette
// (chroma median 10.4, p90 26.4) so halving it again would only turn a tinted liquid grey. Reported
// from the game: it does not. The pack cells still read as the most saturated thing in a lab room,
// and the worktop clutter beside them was tamed by the same 0.5 in the same space at the same time
// (art/textures.json facility/worktop-clutter's `sat`, baked because a merged lambert has no uniform
// to hand it to). The two families share a worktop and now share a number.
//
// it costs no second texture: render.particles.Sprites carries the knob as a shader uniform on the
// quad's own material, so this is a number handed to a paint and nothing else
  public static function spriteSat(area:game.AreaGame, o:objects.AreaObject):Float
    {
      return onBench(area, o) ? FacilityStyle.DECO_TABLE_SAT : 1.0;
    }

// does it need the LEAN taken back out of its resting height? every upright sprite leans back by
// Sprites.TILT about its own centre, which lifts its content bottom clear of the surface it is
// standing on — 0.199 world units for this family, reported from the game as decorations hanging in
// the air over their own contact pool. render.Actors does the arithmetic; this is only the gate, and
// it is the bench family alone because an ACTOR's art is posed against that same lean already
//
// STATELESS like the three hooks above, asked per object with no model in hand
  public static function spriteSinks(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return onBench(area, o);
    }

// and does it LIE DOWN on the worktop rather than stand up on it? three of the 43 do — see
// Const.FACILITY_FLAT_DECO, which is a per-FRAME table because the gloves sit among eleven upright
// flasks on their own rows.
//
// nothing else has to be arranged for it: render.world.WorldCtx.floorY already routes through
// FacilityTables.groundY, so a flat quad on a bench cell lands on BENCH_H and not on the floor
  public static function spriteFlat(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return onBench(area, o) &&
        Const.isFlatDeco(o.imageRow, o.imageCol);
    }

// the contact pool one of them wants, worked out from the icon's own alpha box. `null` in means the
// atlas has not decoded, and then both numbers fall back to FacilityStyle's measured averages.
//
// BOTH ARE PROPERTIES OF THE SPRITE, which is the reason this sits here beside spriteScale rather
// than at the emitter: render.facility.FacilityTables knows where a bench cell is and nothing at all
// about how a billboard is posed over one. See FacilityModel.TableDeco for the measurements
  public static function poolOf(b:AtlasBox):TableDeco
    {
      if (b == null)
        return {
          dx: 0.0,
          dz: FacilityStyle.TABLE_POOL_DZ,
          r: FacilityStyle.TABLE_POOL_R,
        };
      // the quad the icon is drawn on leans back by Sprites.TILT about world X, and that rotation is
      // about its CENTRE — so the content bottom, which is the part that reads as resting on the
      // worktop, swings toward the camera by its own drop below that centre times sin(TILT).
      //
      // sideways there is no rotation to account for and the art's own offset is the whole of it:
      // the opaque box's centre against the cell's, which is where the object is actually drawn
      // the box's OWN cell, which is 256 for a frame redrawn off a pack sheet and 64 for one still
      // on entities64 (Const.FACILITY_DECO_HD) — every number below is a cell fraction, so reading
      // it off the box is what keeps a pool the same size whichever sheet the art came from
      var t = b.t;
      var span = Sprites.SIZE * FacilityStyle.DECO_TABLE_SCALE;
      return {
        dx: span * ((b.x + b.w * 0.5) / t - 0.5),
        dz: span * (0.5 - Sprites.bottomOf(b, t)) * Math.sin(Sprites.TILT),
        r: span * (b.w / t) * 0.5 * FacilityStyle.TABLE_POOL_FOOT,
      };
    }

// is this kind drawn as an instanced glb rather than emitted here? the two ROUND ones — a drum and a
// bin are cylinders and FacilityGeom emits axis-aligned quads only, so there is no quad route to
// take. they are in the deco grid for what READS it: the sprite gate above, and the one-fitting-to-
// a-tile test render.facility.FacilityKit makes of it. not for the emitters below
  public static inline function isProp(kind:Int):Bool
    {
      return kind == _FittingKind.FIT_BIN ||
        kind == _FittingKind.FIT_DRUM_STEEL ||
        kind == _FittingKind.FIT_DRUM_BIO ||
        kind == _FittingKind.FIT_DRUM_RAD;
    }

// how tall a fitting of this kind stands, world units. public for render.facility.FacilityCable,
// which has to know whether a fitting between two of its panels reaches the cable strung over it —
// the LOW half of this family (a 1.8 drum, a 2.2 machine) passes under a run that a 3.43 cabinet
// would be drawn straight through
  public static function heightOf(kind:Int):Float
    {
      return switch (kind)
        {
          case _FittingKind.FIT_SHELVING: FacilityStyle.DECO_SHELF_H;
          case _FittingKind.FIT_BOOKCASE: FacilityStyle.DECO_BOOKCASE_H;
          case _FittingKind.FIT_RACK: FacilityStyle.DECO_RACK_H;
          case _FittingKind.FIT_RACK_LOW: FacilityStyle.DECO_RACK_LOW_H;
          case _FittingKind.FIT_CABINET: FacilityStyle.DECO_CABINET_H;
          case _FittingKind.FIT_MACHINE: FacilityStyle.DECO_MACHINE_SZ;
          case _FittingKind.FIT_MACHINE_LOW: FacilityStyle.DECO_MACHINE_LOW_SZ;
          case _FittingKind.FIT_ANALYSER: FacilityStyle.DECO_ANALYSER_H;
          case _FittingKind.FIT_STALL: FacilityStyle.STALL_H;
          case _FittingKind.FIT_BASIN: FacilityStyle.BASIN_H;
          case _FittingKind.FIT_PARTITION: FacilityStyle.PART_H;
          case _FittingKind.FIT_SOFA: FacilityStyle.DECO_SOFA_H;
          case _FittingKind.FIT_TABLE_LOW: FacilityStyle.DECO_TABLE_LOW_H;
          case _FittingKind.FIT_PALLET_RACK: FacilityStyle.DECO_PALLET_RACK_H;
          case _FittingKind.FIT_PALLET_STACK: FacilityStyle.DECO_PALLET_STACK_H;
          case _FittingKind.FIT_DRUM_PALLET: FacilityStyle.DECO_DRUM_PALLET_H;
          default: 0.0;
        };
    }

// every fitting in the compound. one merged mesh per SURFACE — sixteen of them plus the rack lights.
//
// `leds` comes in ALREADY FILLED by render.facility.FacilityWork, whose towers carry status lights of
// exactly the shape this family's server racks do. A borrowed buffer and not a second additive mesh:
// every blinking speck in the compound then shares one draw call, one material and one clock, and a
// workstation's lights cost nothing at all beyond their four vertices
  public static function build(scene:Scene, m:Facility, leds:MeshBuf):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // indexed by Buf below, so a face names the surface it is made of rather than the kind it
      // belongs to
      var b = [for (_ in 0...23) MeshBufTools.make()];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.drain[row][col])
              drain(b[B_DRAIN], col, row, half);
            var kind = m.deco[row][col] - 1;
            if (kind < 0 ||
                isProp(kind))
              continue;
            unit(m, b, leds, col, row, kind);
          }
      // the end frame is the one CUT surface; everything else is plain opaque merged geometry
      cut(scene, b[B_SHELF_SIDE], FacilityStyle.DECO_SHELF_SIDE);
      // DoubleSide: a shelf is a bare quad with no thickness, so it has to be seen from under it
      solid(scene, b[B_SHELF_TOP], FacilityStyle.DECO_SHELF_TOP, true);
      solid(scene, b[B_BC_FRONT], FacilityStyle.DECO_BOOKCASE_FRONT, false);
      solid(scene, b[B_BC_SIDE], FacilityStyle.DECO_BOOKCASE_SIDE, false);
      solid(scene, b[B_BC_TOP], FacilityStyle.DECO_BOOKCASE_TOP, false);
      solid(scene, b[B_RACK], FacilityStyle.DECO_RACK, false);
      solid(scene, b[B_RACK_SIDE], FacilityStyle.DECO_RACK_SIDE, false);
      solid(scene, b[B_RACK_TOP], FacilityStyle.DECO_RACK_TOP, false);
      solid(scene, b[B_CAB_FRONT], FacilityStyle.DECO_CABINET_FRONT, false);
      solid(scene, b[B_CAB_SIDE], FacilityStyle.DECO_CABINET_SIDE, false);
      solid(scene, b[B_CAB_TOP], FacilityStyle.DECO_CABINET_TOP, false);
      solid(scene, b[B_MACH_FRONT], FacilityStyle.DECO_MACHINE_FRONT, false);
      solid(scene, b[B_MACH_SIDE], FacilityStyle.DECO_MACHINE_SIDE, false);
      solid(scene, b[B_MACH_TOP], FacilityStyle.DECO_MACHINE_TOP, false);
      solid(scene, b[B_DRAIN], FacilityStyle.DECO_DRAIN, false);
      // DoubleSide: a partition and a door leaf are bare quads with no thickness, seen from both
      // sides of the cubicle. free on an opaque material, which draws DoubleSide in one pass
      solid(scene, b[B_STALL], FacilityStyle.STALL_PANEL, true);
      solid(scene, b[B_STALL_SIDE], FacilityStyle.STALL_SIDE, true);
      // the divider is a solid stud wall and not a panel, so it takes no DoubleSide
      solid(scene, b[B_PART], FacilityStyle.WASH_PARTITION, false);
      solid(scene, b[B_COUNTER], FacilityStyle.WASH_COUNTER, false);
      // the basin and its tap are CUT, exactly as render.facility.FacilitySink draws the same sheet
      cut(scene, b[B_BASIN], FacilityStyle.SINK_TEX);
      solid(scene, b[B_BASIN_TOP], FacilityStyle.WASH_COUNTER_TOP, false);
      solid(scene, b[B_MIRROR], FacilityStyle.MIRROR, false);
      lamps(scene, leds);
    }

  // which merged surface a face goes in — the buffers are keyed by TEXTURE, so two families
  // sharing a material would share a draw call. NONE DO ANY MORE. The rack's sides and lid rode
  // B_SHELF_TOP, the shelving's perforated shelf plate, on the argument that both are steel — and a
  // cabinet drawn with shelf holes in its flanks reads as SHELVING, which is what it was reported
  // as. A rack's side is a blank painted sheet and its lid is slots and grommets; those are two
  // more surfaces and two more calls, and the call is what the read costs
  static inline var B_SHELF_SIDE = 0;
  static inline var B_SHELF_TOP = 1;
  // RETIRED AND NOT RENUMBERED: the crates are dealt into a lid by render.facility.FacilityClutter
  // now and flushed from there, so nothing in this file writes buffer 2. The index stays because
  // every constant below it is one, and a hole costs an unused MeshBuf
  static inline var B_BOX = 2;
  static inline var B_BC_FRONT = 3;
  static inline var B_BC_SIDE = 4;
  static inline var B_BC_TOP = 5;
  static inline var B_RACK = 6;
  static inline var B_RACK_SIDE = 7;
  static inline var B_RACK_TOP = 8;
  static inline var B_CAB_FRONT = 9;
  static inline var B_CAB_SIDE = 10;
  static inline var B_CAB_TOP = 11;
  static inline var B_MACH_FRONT = 12;
  static inline var B_MACH_SIDE = 13;
  static inline var B_MACH_TOP = 14;
  static inline var B_DRAIN = 15;
  // the washroom's, and there are SIX of them because one laminate turned out not to be one surface.
  // The leaf, the side panels, the divider and the counter's apron shared B_STALL on the argument
  // that they are all the same board — and the art is a DOOR, so the compound grew a door on every
  // blank side panel, on the vanity apron and on the wall between the two halves. The bowl and its
  // tap are the laboratory sink's own sheet, which this family gets for free, and the mirror is the
  // one face here that maps its art 0..1
  static inline var B_STALL = 16;
  static inline var B_BASIN = 17;
  static inline var B_MIRROR = 18;
  // the counter's LID: drawn top-down, where every panel above is a bottom-up elevation and laid
  // flat would read as an elevation lying down
  static inline var B_BASIN_TOP = 19;
  static inline var B_STALL_SIDE = 20;
  static inline var B_PART = 21;
  static inline var B_COUNTER = 22;

// where a fitting of this kind on this cell actually stands: the rect its faces are emitted on, the
// hand its wall is on, and whether that wall is solid masonry.
//
// PULLED OUT OF `unit` SO A SECOND FAMILY CAN ASK. render.facility.FacilityCable hangs a panel over a
// machine and drops a cable onto its lid, and neither the lid's height nor the back edge it leaves
// from is derivable from the cell — `fit` slides a unit along its wall and the slab face is a whole
// unit inside the cell boundary, so a hand-written second copy would be wrong in exactly the two
// places that are hard to see. Computed twice and shared nowhere, FacilityPoint.places' own
// discipline: it is a pure function of the saved grid, so either caller may run first
  public static function rectOf(m:Facility, col:Int, row:Int, kind:Int):DecoRect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // THE PARTITION IS THE ONE FITTING THAT DOES NOT STAND AGAINST A WALL — it IS one — so it takes
      // none of the wall search, the slide or the stand-off below. It spans its cell exactly on the
      // axis its own line runs along, which is what makes a column of them one unbroken wall rather
      // than a row of slabs with seams between, and PART_T across. The axis comes off the NEIGHBOURS
      // and not off the room, the same way FacilityDeco.stall reads its own run
      if (kind == _FittingKind.FIT_PARTITION)
        {
          var cx = (col + 0.5) * CELL - half;
          var cz = (row + 0.5) * CELL - half;
          // THE AXIS IS THE ONE WITH MORE NEIGHBOURS ON IT, and a plain `has an x neighbour` read it
          // wrong at the one cell that matters. The T's junction is the middle of the BAR with the
          // stem arriving on one hand: one x neighbour against two in z, so "any x neighbour" called
          // the bar's own cell a horizontal run, spanned it the full CELL in x — reaching a boundary
          // the stem is not on — and then took BOTH z hands as crossing arms. Four arms out of three
          // neighbours, reported from the game as the divider being + shaped instead of T. Counting
          // leaves every straight run and every stub exactly where it was
          var ax = (isKind(m, col - 1, row, kind) ? 1 : 0) +
            (isKind(m, col + 1, row, kind) ? 1 : 0);
          var az = (isKind(m, col, row - 1, kind) ? 1 : 0) +
            (isKind(m, col, row + 1, kind) ? 1 : 0);
          var alongX = (ax > 0 && ax >= az);
          var hw = (alongX ? CELL : FacilityStyle.PART_T) / 2;
          var hd = (alongX ? FacilityStyle.PART_T : CELL) / 2;
          var px0 = cx - hw, px1 = cx + hw;
          var pz0 = cz - hd, pz1 = cz + hd;
          // AND A RUN THAT ENDS AT MASONRY REACHES THE MASONRY'S OWN FACE, not its own cell
          // boundary. FacilityGeom.slab insets a wall cell by (CELL - thick) / 2 on the hands its
          // line does not carry into, so the wall's inner face stands 1.4 units back inside its cell
          // — and a divider ending on the boundary left exactly that much daylight between the two
          // halves it divides. Reported from the game as the separator not coming all the way to the
          // outer wall. The same measurement the corridor casework and the kit props take
          for (k in 0...2)
            {
              var d = (alongX ? 2 : 0) + k;
              var c = col + FacilityGeom.DC[d], r = row + FacilityGeom.DR[d];
              // isWall AND NOT isSolidWall: a washroom's light wells are glazing, and a divider
              // meeting one meets the same masonry line the slab is inset off. A DOOR cell answers
              // `carries` too and is not a wall, which is what keeps a divider out of an opening
              if (isKind(m, c, r, kind) ||
                  !FacilityModel.isWall(m, c, r) ||
                  !FacilityGeom.carries(m, c, r))
                continue;
              var s = FacilityGeom.slab(m, c, r);
              switch (d)
                {
                  case 0: pz0 = s.z1;
                  case 1: pz1 = s.z0;
                  case 2: px0 = s.x1;
                  default: px1 = s.x0;
                }
            }
          return {
            x0: px0,
            x1: px1,
            z0: pz0,
            z1: pz1,
            // the hand its long faces look out of: a wall between two halves faces both of them
            dir: (alongX ? 0 : 2),
            hasWall: false,
            h: FacilityStyle.PART_H,
          };
        }
      var w = FacilityStyle.DECO_SHELF_W, d = FacilityStyle.DECO_SHELF_D;
      if (kind == _FittingKind.FIT_BOOKCASE)
        {
          w = FacilityStyle.DECO_BOOKCASE_W;
          d = FacilityStyle.DECO_BOOKCASE_D;
        }
      else if (kind == _FittingKind.FIT_RACK ||
               kind == _FittingKind.FIT_RACK_LOW)
        {
          w = FacilityStyle.DECO_RACK_W;
          d = FacilityStyle.DECO_RACK_D;
        }
      else if (kind == _FittingKind.FIT_CABINET)
        {
          w = FacilityStyle.DECO_CABINET_W;
          d = FacilityStyle.DECO_CABINET_D;
        }
      else if (kind == _FittingKind.FIT_MACHINE ||
               kind == _FittingKind.FIT_MACHINE_LOW)
        {
          // a CUBE, and the height is the same number — see FacilityStyle.DECO_MACHINE_SZ
          w = heightOf(kind);
          d = w;
        }
      else if (kind == _FittingKind.FIT_ANALYSER)
        {
          w = FacilityStyle.DECO_ANALYSER_W;
          d = FacilityStyle.DECO_ANALYSER_D;
        }
      else if (kind == _FittingKind.FIT_STALL)
        {
          w = FacilityStyle.STALL_W;
          d = FacilityStyle.STALL_D;
        }
      else if (kind == _FittingKind.FIT_BASIN)
        {
          w = FacilityStyle.BASIN_W;
          d = FacilityStyle.BASIN_D;
        }
      else if (kind == _FittingKind.FIT_SOFA)
        {
          w = FacilityStyle.DECO_SOFA_W;
          d = FacilityStyle.DECO_SOFA_D;
        }
      else if (kind == _FittingKind.FIT_TABLE_LOW)
        {
          w = FacilityStyle.DECO_TABLE_LOW_W;
          d = FacilityStyle.DECO_TABLE_LOW_D;
        }
      else if (kind == _FittingKind.FIT_PALLET_RACK)
        {
          w = FacilityStyle.DECO_PALLET_RACK_W;
          d = FacilityStyle.DECO_PALLET_RACK_D;
        }
      else if (kind == _FittingKind.FIT_PALLET_STACK)
        {
          w = FacilityStyle.DECO_PALLET_STACK_W;
          d = FacilityStyle.DECO_PALLET_STACK_D;
        }
      else if (kind == _FittingKind.FIT_DRUM_PALLET)
        {
          w = FacilityStyle.DECO_DRUM_PALLET_W;
          d = FacilityStyle.DECO_DRUM_PALLET_D;
        }
      var cx = (col + 0.5) * CELL - half;
      var cz = (row + 0.5) * CELL - half;
      var dir = wall(m, col, row, Const.isLowFitting(kind));
      // whether the wall shadow may be laid, and it is NOT the same question as `dir >= 0`: the
      // fallback below forces a hand on a unit that has none, and a halo on a WINDOW cell would land
      // on the glazing. SOLID masonry only, the test `placeRound` makes for the same reason
      var hasWall = (dir >= 0 &&
        FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]));
      var x0 = cx - w / 2, x1 = cx + w / 2;
      var z0 = cz - d / 2, z1 = cz + d / 2;
      if (dir < 0)
        {
          // no masonry on any hand, which is a ROW OF RACKING down the middle of a store's floor
          // (gen.facility.FacilityRooms.storeIslands) and, failing that, one thing standing where
          // the generator's own placement rule should have made impossible. Either way it keeps its
          // geometry: a cell must never lose its sprite AND its geometry, and render.Actors has
          // already stopped drawing the one.
          //
          // IT FACES ALONG ITS OWN RUN, which a flat 0 cannot. Laid along the grid's z axis, four
          // 3.9-wide bays at dir 0 come out as four slabs facing ACROSS the run with a 2.2 gap
          // between them instead of one continuous line of racking
          dir = runDir(m, col, row, kind);
          if (dir >= 2)
            {
              x0 = cx - d / 2;
              x1 = cx + d / 2;
              z0 = cz - w / 2;
              z1 = cz + w / 2;
            }
        }
      else
        {
          // off the WALL FACE and not the cell boundary, which is a unit away
          var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
          if (dir < 2)
            {
              var r = fit(x0, x1, s.x0, s.x1);
              x0 = r[0];
              x1 = r[1];
              if (dir == 0)
                {
                  z0 = s.z1 + FacilityStyle.STAND_GAP;
                  z1 = z0 + d;
                }
              else
                {
                  z1 = s.z0 - FacilityStyle.STAND_GAP;
                  z0 = z1 - d;
                }
            }
          else
            {
              var r = fit(cz - w / 2, cz + w / 2, s.z0, s.z1);
              z0 = r[0];
              z1 = r[1];
              if (dir == 2)
                {
                  x0 = s.x1 + FacilityStyle.STAND_GAP;
                  x1 = x0 + d;
                }
              else
                {
                  x1 = s.x0 - FacilityStyle.STAND_GAP;
                  x0 = x1 - d;
                }
            }
        }
      return {
        x0: x0,
        x1: x1,
        z0: z0,
        z1: z1,
        dir: dir,
        hasWall: hasWall,
        h: heightOf(kind),
      };
    }

// which way a fitting with NO masonry behind it faces: along its own run, named by a neighbouring
// cell carrying the same kind. 0 for a run along x (and for one standing alone), 2 for one along z —
// the same two hands `wall` would have returned, so the yaw and the rect follow with no second rule
  static function runDir(m:Facility, col:Int, row:Int, kind:Int):Int
    {
      if (isKind(m, col, row - 1, kind) ||
          isKind(m, col, row + 1, kind))
        return 2;
      return 0;
    }

// one fitting: work out the rect it stands on, then hand each of its faces to the surface it is
// made of
  static function unit(m:Facility, b:Array<MeshBuf>, leds:MeshBuf, col:Int, row:Int,
      kind:Int):Void
    {
      var r = rectOf(m, col, row, kind);
      var x0 = r.x0, x1 = r.x1, z0 = r.z0, z1 = r.z1;
      var dir = r.dir, hasWall = r.hasWall, h = r.h;
      var y = FacilityGround.surfY(Surf.TILE);
      // the floor pool under it, on the plain rect — the field is what darkens the tile a standing
      // thing sits on, and it is repainted once after every prop pass has placed
      ContactMask.prop(x0, x1, z0, z1);
      // and the other half of the same job, on the wall behind: the field is top-down and cannot
      // reach a vertical face, so that one is a quad. see render.facility.FacilityDetail.halos
      if (hasWall)
        FacilityDetail.stand({
          col: col,
          row: row,
          dir: dir,
          a0: (dir < 2 ? x0 : z0),
          a1: (dir < 2 ? x1 : z1),
          len: 1,
          y: y,
          h: h,
        });
      // the axis the wall does NOT lie on: the two ends of any of these
      var head = (dir < 2 ? 2 : 0);
      switch (kind)
        {
          case _FittingKind.FIT_SHELVING:
            if (!FacilityStyle.DECO_SHELF_GLB)
              shelf(b, x0, x1, z0, z1, y, h, head);
          case _FittingKind.FIT_BOOKCASE:
            // front, two ends, a top, and no back and no bottom: the back is buried in the masonry
            // and this camera pitches 51 degrees down, so nothing ever sees under a fitting —
            // render.facility.FacilityRoof.box's own finding
            if (!FacilityStyle.DECO_BOOKCASE_GLB)
              {
                FacilityGeom.pane(b[B_BC_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
                FacilityGeom.face(b[B_BC_SIDE], x0, x1, z0, z1, head, y, y + h,
                  FacilityStyle.DECO_BOOKCASE_TILE);
                FacilityGeom.face(b[B_BC_SIDE], x0, x1, z0, z1, head + 1, y, y + h,
                  FacilityStyle.DECO_BOOKCASE_TILE);
                // the LID takes the unit's OWN width as its period and not DECO_BOOKCASE_TILE, so
                // it draws under one repeat both ways and no wrap line is ever laid across it —
                // the rack's `localCap` answer, and what the glb's own sheet is packed at
                localCap(b[B_BC_TOP], x0, x1, z0, z1, y + h, FacilityStyle.DECO_BOOKCASE_W);
              }
          case _FittingKind.FIT_CABINET:
            // the bookcase's own shape, one surface family over: an authored front mapped 0..1 by
            // `pane`, two tiling ends and a tiling top, and no back and no bottom for the same
            // reason — the back is buried in the masonry and nothing at this pitch sees under a
            // fitting. UNLESS the glb is on, in which case `fittings` stands one here instead
            if (!FacilityStyle.DECO_CABINET_GLB)
              {
                FacilityGeom.pane(b[B_CAB_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
                FacilityGeom.face(b[B_CAB_SIDE], x0, x1, z0, z1, head, y, y + h,
                  FacilityStyle.DECO_CABINET_TILE);
                FacilityGeom.face(b[B_CAB_SIDE], x0, x1, z0, z1, head + 1, y, y + h,
                  FacilityStyle.DECO_CABINET_TILE);
                FacilityGeom.cap(b[B_CAB_TOP], x0, x1, z0, z1, y + h,
                  FacilityStyle.DECO_CABINET_TILE);
              }
          case _FittingKind.FIT_STALL:
            stall(b, m, col, row, x0, x1, z0, z1, y, h, dir, head);
          case _FittingKind.FIT_BASIN:
            basin(b, m, col, row, x0, x1, z0, z1, y, h, dir, head);
          case _FittingKind.FIT_PARTITION:
            partition(b, m, col, row, x0, x1, z0, z1, y, h, dir);
          // the lounge's pair, and the only kinds here that emit NOTHING. Every other glb in this
          // family is a switch over quads that came first; these two were modelled from the start,
          // so there is no emitted version to fall back to — and a case is still required, because
          // `default` below is the rack and an unlisted kind would be drawn as one
          // and the STORE's three, on the same terms: modelled from the start, so nothing is
          // emitted for them either — and a case is still required, because `default` below is the
          // rack and an unlisted kind is drawn as one
          case _FittingKind.FIT_PALLET_RACK | _FittingKind.FIT_PALLET_STACK |
               _FittingKind.FIT_DRUM_PALLET:
          case _FittingKind.FIT_SOFA | _FittingKind.FIT_TABLE_LOW:
          // the hangar's second machine: modelled from the start like those two, so it emits nothing
          // — but it DOES blink, and its lamps are the painted lenses of its port plate rather than
          // a control strip across the whole front. See FacilityStyle.DECO_ANAL_LED_U, which is
          // measured off models-src/facility/analyser-sheet.png and then carried onto the UNIT'S
          // width, because that plate is only DECO_ANALYSER_PLATE of the face wide
          case _FittingKind.FIT_ANALYSER:
            machLights(leds, {
              x0: x0,
              x1: x1,
              z0: z0,
              z1: z1,
              y: y,
              h: h,
              dir: dir,
              col: col,
              row: row,
              us: FacilityStyle.DECO_ANAL_LED_U,
              v: FacilityStyle.DECO_ANAL_LED_V,
              size: FacilityStyle.DECO_ANAL_LED_SIZE,
              greenFrom: FacilityStyle.DECO_ANAL_LED_GREEN_FROM,
              mode: FacilityStyle.DECO_LED_SCAN,
            });
          case _FittingKind.FIT_MACHINE | _FittingKind.FIT_MACHINE_LOW:
            // the same four faces again, and the ONLY kind here where EVERY one of them maps 0..1 —
            // the lid included. It was emitted with `face`/`cap` first, tiling off the world the way
            // the bookcase's flanks do, and came back from the game as a misaligned front and a lid
            // with its corners cut off: all three of these images carry discrete features (a strip of
            // dials, bolt columns down the edges, two grille patches and a gland) and a swatch that
            // only reads whole cannot be shown in part. `localCap` at the unit's own width is a full
            // 0..1 across the lid because this unit is a CUBE, which is what an aspect-locked face on
            // a square image costs and the reason it is one
            if (!FacilityStyle.DECO_MACHINE_GLB)
              {
                FacilityGeom.pane(b[B_MACH_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
                FacilityGeom.pane(b[B_MACH_SIDE], x0, x1, z0, z1, head, y, y + h);
                FacilityGeom.pane(b[B_MACH_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
                localCap(b[B_MACH_TOP], x0, x1, z0, z1, y + h, x1 - x0);
              }
            machLights(leds, {
              x0: x0,
              x1: x1,
              z0: z0,
              z1: z1,
              y: y,
              h: h,
              dir: dir,
              col: col,
              row: row,
              us: FacilityStyle.DECO_MACH_LED_U,
              v: FacilityStyle.DECO_MACH_LED_V,
              size: FacilityStyle.DECO_MACH_LED_SIZE,
              greenFrom: FacilityStyle.DECO_MACH_LED_GREEN_FROM,
              mode: FacilityStyle.DECO_LED_CHASE,
            });
          default:
            // the rack: three faces of one cabinet, each on its own surface, and all of them laid
            // from the UNIT'S OWN CORNER rather than off the world — see `localFace`. UNLESS the
            // glb is switched on, in which case `racks` stands one here instead and this emits
            // nothing; the LIGHTS are outside the switch, because both answers put six chassis in
            // the same six places (FacilityStyle.DECO_RACK_GLB)
            if (!FacilityStyle.DECO_RACK_GLB)
              {
                localFace(b[B_RACK], x0, x1, z0, z1, dir ^ 1, y, y + h);
                localFace(b[B_RACK_SIDE], x0, x1, z0, z1, head, y, y + h);
                localFace(b[B_RACK_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
                localCap(b[B_RACK_TOP], x0, x1, z0, z1, y + h, FacilityStyle.DECO_RACK_TILE);
              }
            lights(leds, x0, x1, z0, z1, y, h, dir, col, row);
        }
    }

// slide a span of the fitting's own width inside the masonry it stands against, and SQUEEZE it only
// when the masonry is genuinely narrower.
//
// FacilityGeom.slab insets a face by a unit wherever the wall line stops there, so a unit centred on
// its cell can hang past the end of the wall it is bolted to. The corridor casework clamps both
// ends and the lab kit rejects the cell; neither is right here — a fitting is in the save and
// cannot be dropped, and clamping is a STRETCH on the two faces that map their image 0..1
  static inline function fit(a0:Float, a1:Float, lo:Float, hi:Float):Array<Float>
    {
      var len = a1 - a0;
      if (hi - lo <= len)
        return [lo, hi];
      if (a0 < lo)
        return [lo, lo + len];
      if (a1 > hi)
        return [hi - len, hi];
      return [a0, a1];
    }

// which hand this cell's wall is on, or -1 for a cell with none. the first hand that answers is
// taken, exactly as the lab kit's own test does: a cell with masonry on two hands is a room corner,
// and either face stands the fitting in the same corner.
//
// MASONRY FIRST AND GLAZING ONLY AFTER IT, and only for a LOW fitting — the rule `placeRound` below
// already runs the round ones on. FacilityModel.isSolidWall rules a window out, and the generator
// FORCES the low list beside glazing (game.FacilityAreaGenerator's nextToWindow test), so on masonry
// alone most of that family has no wall on any hand and takes the stood-square-in-the-cell fallback.
// Measured in game on a machine at a window run: it stood a clear half cell off the glass with floor
// all round it, which is what a fitting is not. A HIGH fitting still refuses glazing outright, and
// the sill is why: it sits at 0.93 world units (FacilityGeom.build's own centring of a pane
// 4.14 tall in WALL_H 6.0), so a 3.4-tall cabinet would blank the whole opening where a 2.2 machine
// takes the bottom third of it — which is where a machine in a lab stands anyway
  static function wall(m:Facility, col:Int, row:Int, low:Bool):Int
    {
      for (dir in 0...4)
        if (FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]))
          return dir;
      if (!low)
        return -1;
      for (dir in 0...4)
        if (FacilityModel.isWall(m, col + DC[dir], row + DR[dir]))
          return dir;
      return -1;
    }

// one vertical face of a fitting, its art laid from the UNIT'S OWN CORNER.
//
// FacilityGeom.face divides the WORLD coordinate by the period, which is exactly what a wall run
// wants — two neighbouring cells then carry one continuous course — and exactly what a cabinet does
// not. Measured on the compound's rack: its left edge stands at world x −48.88, so u opened at
// −33.71 and the art began 0.29 of a tile in; the front is an authored composition with an end rail
// down each side and both rails landed in the middle of the face. Reported from the game as "front
// and top look like they're drawn with a u or v shift", which is what it was.
//
// the winding is FacilityGeom.ends' and must never be re-derived here — a quad wound for the wrong
// hand lands inside the object and simply never appears
  static function localFace(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var t = FacilityStyle.DECO_RACK_TILE;
      var u = (dir < 2 ? x1 - x0 : z1 - z0) / t;
      var v = (y1 - y0) / t;
      MeshBufTools.quad(b, [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [0, 0, u, 0, u, v, 0, v]);
    }

// and the lid, the same mapping laid flat: u across the unit's width, v across its depth, both from
// its own corner. FacilityGeom.cap's winding, for the same reason as above.
//
// the period is an ARGUMENT because two kinds want two answers off one mapping: the rack passes its
// own DECO_RACK_TILE and gets u 0..0.75 over a lid narrower than the art, and the machine passes its
// own WIDTH and gets exactly 0..1, which is the only thing that shows that lid's corner bolts
  static function localCap(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float,
      t:Float):Void
    {
      var u = (x1 - x0) / t;
      var v = (z1 - z0) / t;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [0, v, u, v, u, 0, 0, 0]);
    }

// one WC cubicle: the partitions either side of it, and the door leaf across its open face.
//
// THE PARTITION IS A BOUNDARY AND NOT A SIDE, which is the whole of this function's care. Two
// cubicles side by side share one divider; emitted per unit, both would land on the same plane and
// z-fight down their whole height. So a unit takes its `head` side ALWAYS and its `head + 1` side
// only where the next cell is not another cubicle — n cubicles, n + 1 partitions, no duplicate. It
// works because STALL_W is exactly one cell: every plane lands on the grid the cells do.
//
// no lid and no back: the back is the masonry it stands against, and at this camera's 51 degrees a
// ceiling over the cubicle would hide everything in it — FacilityRoof.box's finding, and the same
// one the bookcase's missing top rides on
  static function stall(b:Array<MeshBuf>, m:Facility, col:Int, row:Int, x0:Float, x1:Float,
      z0:Float, z1:Float, y:Float, h:Float, dir:Int, head:Int):Void
    {
      // the sides take the BLANK panel and the leaf takes the one with a door drawn on it, which is
      // the whole of FacilityStyle.STALL_SIDE's reason for existing
      var t = FacilityStyle.STALL_TILE;
      FacilityGeom.face(b[B_STALL_SIDE], x0, x1, z0, z1, head, y, y + h, t);
      if (!isStall(m, col + DC[head + 1], row + DR[head + 1]))
        FacilityGeom.face(b[B_STALL_SIDE], x0, x1, z0, z1, head + 1, y, y + h, t);
      // the leaf, standing STALL_DOOR_GAP clear of the floor the way every public one does
      FacilityGeom.face(b[B_STALL], x0, x1, z0, z1, dir ^ 1,
        y + FacilityStyle.STALL_DOOR_GAP, y + h, t);
    }

// is there another cubicle on this cell? the partition rule above is the only caller
  static inline function isStall(m:Facility, col:Int, row:Int):Bool
    {
      return isKind(m, col, row, _FittingKind.FIT_STALL);
    }

// does this cell carry a fitting of exactly this kind? bounds-safe, and the test every family that
// reads its own RUN out of the grid makes
  static inline function isKind(m:Facility, col:Int, row:Int, kind:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.deco[row][col] - 1 == kind;
    }

// the washroom's dividing wall, one cell of it. four faces and a lid, all in the cubicle laminate —
// the same buffer the partitions and the basin counter go in, so the whole washroom's casework is
// still ONE draw call however it is divided.
//
// no end-cap rule like `stall`'s: this is a full-height wall meeting its neighbours on the shared
// cell boundary, and two coplanar end faces inside a solid run would z-fight where a cubicle's
// chest-high partitions cannot. So the ends are emitted ONLY where the line actually stops, which is
// at a passage or at the room wall.
//
// AND THE T JUNCTION IS A SECOND ARM, which a cell gets ONE rect and so cannot state on its own.
// `rectOf` spans the cell on the axis its own line runs along and is PART_T across — so where a
// second line arrives on one of the OTHER two hands, the neighbour's slab reaches the shared cell
// boundary and this cell's reaches only PART_T / 2 from its centre, leaving (CELL - PART_T) / 2 =
// 1.7 units of daylight straight through the wall. The patch is exactly that gap and no more: from
// this arm's own SURFACE out to the boundary, PART_T across, two long faces and a lid.
//
// STARTED AT THE SURFACE AND NOT AT THE CENTRE, which is the one trap here: from the centre its lid
// would overlap this arm's lid on a 0.6 x 0.3 square of coplanar quad, i.e. a z-fight at the top of
// the wall where it is most visible. Started at the surface, the patch's inner end is closed by this
// arm's own long face and its outer end by the neighbour's — whose end face was skipped for exactly
// this reason — so the union is solid with no face inside it and none doubled
  static function partition(b:Array<MeshBuf>, m:Facility, col:Int, row:Int, x0:Float, x1:Float,
      z0:Float, z1:Float, y:Float, h:Float, dir:Int):Void
    {
      var head = (dir < 2 ? 2 : 0);
      // ITS OWN ART AND ITS OWN PERIOD: a full-height wall wearing a cubicle door was the first
      // build, and PART_TILE carries why the period is the wall's own height and not STALL_TILE
      var t = FacilityStyle.PART_TILE;
      // the two long faces, one into each half
      FacilityGeom.face(b[B_PART], x0, x1, z0, z1, dir, y, y + h, t);
      FacilityGeom.face(b[B_PART], x0, x1, z0, z1, dir ^ 1, y, y + h, t);
      // and an end wherever the line does not carry on
      for (k in 0...2)
        {
          var d = head + k;
          if (isKind(m, col + DC[d], row + DR[d], _FittingKind.FIT_PARTITION))
            continue;
          FacilityGeom.face(b[B_PART], x0, x1, z0, z1, d, y, y + h, t);
        }
      cope(b, x0, x1, z0, z1, y + h);
      // the crossing arm, on either of the two hands this one does not run along
      var cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
      var hp = FacilityStyle.PART_T / 2;
      var half = CELL / 2;
      for (k in 0...2)
        {
          var d = (head + 2 + k) % 4;
          if (!isKind(m, col + DC[d], row + DR[d], _FittingKind.FIT_PARTITION))
            continue;
          var px0 = cx - hp, px1 = cx + hp;
          var pz0 = cz - hp, pz1 = cz + hp;
          if (d == 0)
            {
              pz0 = cz - half;
              pz1 = cz - hp;
            }
          else if (d == 1)
            {
              pz0 = cz + hp;
              pz1 = cz + half;
            }
          else if (d == 2)
            {
              px0 = cx - half;
              px1 = cx - hp;
            }
          else
            {
              px0 = cx + hp;
              px1 = cx + half;
            }
          // the patch's long faces are the pair perpendicular to the hand it reaches on
          var lf = (d < 2 ? 2 : 0);
          FacilityGeom.face(b[B_PART], px0, px1, pz0, pz1, lf, y, y + h, t);
          FacilityGeom.face(b[B_PART], px0, px1, pz0, pz1, lf + 1, y, y + h, t);
          cope(b, px0, px1, pz0, pz1, y + h);
        }
    }

// the divider's LID, and it is not the divider's art.
//
// FacilityGeom.cap maps a horizontal face WORLD-ALIGNED — u = x / t, v = z / t — while
// facility/wash-partition is a bottom-up ELEVATION that does not tile vertically: a dark skirting
// band across its bottom 8% and a joint line two thirds up. At PART_TILE 6.0 the EAST-WEST arm's lid
// spans z by PART_T 0.6, so dv = 0.1 and it lands on one flat band; the NORTH-SOUTH arm spans z by a
// whole CELL, so dv = 0.667 and it drags the skirting and the joint straight across the top. Reported
// from the game as black bars on the north-south part, and it is the one axis that can show it.
//
// So the lid takes the counter's laminate, which is the family's own top-down art (its note: "must
// read as a horizontal surface looked down on", tiling on BOTH axes) at the period every other
// horizontal surface in the compound uses. Same buffer as the basin counter's own lid, so a washroom
// with both still costs one draw call for the pair
  static function cope(b:Array<MeshBuf>, x0:Float, x1:Float, z0:Float, z1:Float, y:Float):Void
    FacilityGeom.cap(b[B_BASIN_TOP], x0, x1, z0, z1, y, FacilityStyle.BENCH_TOP_TILE);

// one washbasin: a counter in the cubicles' own laminate, the laboratory sink's basin lying on it,
// its tap standing at the back, and a mirror on the masonry above.
//
// THE BOWL AND THE TAP ARE THE LAB SINK'S SHEET, not new art. facility/sink.png holds both quads
// already (the basin top-down on the left, the tap in elevation on the right) and a washroom basin is
// the same fixture as a laboratory one at this distance — what says washroom is the counter it sits
// in and the mirror over it, and both of those are here
  static function basin(b:Array<MeshBuf>, m:Facility, col:Int, row:Int, x0:Float, x1:Float,
      z0:Float, z1:Float, y:Float, h:Float, dir:Int, head:Int):Void
    {
      // the counter: a top, the front under it, and the two ends. no back — it is against masonry.
      //
      // TWO PERIODS AND TWO SURFACES, which is this file's own rule and not a detail. The top is
      // world-tiled both ways like every other horizontal here; the apron is composed BOTTOM-UP and
      // does not tile vertically, so its period is the counter's own height and v runs exactly 0..1
      // up it. BOTH ARE THE WASHROOM'S OWN ART NOW — the top wore the researcher's desk laminate and
      // the apron wore a cubicle door, which were the set's two reuses
      //
      // ALL OF IT EXCEPT THE MIRROR is switched off when the glb ships (FacilityStyle
      // .DECO_BASIN_GLB): the mirror hangs on the WALL and not on the unit, so it stays a quad here
      var cx = (x0 + x1) / 2, cz = (z0 + z1) / 2;
      var alongX = (dir < 2);
      if (!FacilityStyle.DECO_BASIN_GLB)
        {
          var t = FacilityStyle.BASIN_H;
          FacilityGeom.cap(b[B_BASIN_TOP], x0, x1, z0, z1, y + h, FacilityStyle.BENCH_TOP_TILE);
          FacilityGeom.face(b[B_COUNTER], x0, x1, z0, z1, dir ^ 1, y, y + h, t);
          FacilityGeom.face(b[B_COUNTER], x0, x1, z0, z1, head, y, y + h, t);
          FacilityGeom.face(b[B_COUNTER], x0, x1, z0, z1, head + 1, y, y + h, t);
          // the bowl, centred on the counter and lying on it. FacilityGeom.cap's winding with the
          // sheet's own sub-rect instead of a world period, and v is flipped, so the art's top row
          // lands on the BACK edge — FacilitySink.emit's own trap, one axis at a time here because a
          // washroom wall may be on any of the four hands
          var bw = FacilityStyle.SINK_BASIN_W / 2;
          var bd = FacilityStyle.SINK_BASIN_D / 2;
          var by = y + h + FacilityStyle.SINK_Y;
          var ax0 = cx - (alongX ? bw : bd), ax1 = cx + (alongX ? bw : bd);
          var az0 = cz - (alongX ? bd : bw), az1 = cz + (alongX ? bd : bw);
          MeshBufTools.quad(b[B_BASIN], [ax0, by, az1], [ax1, by, az1], [ax1, by, az0],
            [ax0, by, az0], [
            FacilityStyle.SINK_BASIN_U0, FacilityStyle.SINK_BASIN_V0,
            FacilityStyle.SINK_BASIN_U1, FacilityStyle.SINK_BASIN_V0,
            FacilityStyle.SINK_BASIN_U1, FacilityStyle.SINK_BASIN_V1,
            FacilityStyle.SINK_BASIN_U0, FacilityStyle.SINK_BASIN_V1,
          ]);
          // the tap, standing on the counter at its wall edge and looking into the room
          var fw = FacilityStyle.SINK_FAUCET_W;
          var fh = FacilityStyle.SINK_FAUCET_H;
          var fe = FacilityGeom.ends(cx - fw / 2, cx + fw / 2, cz - fw / 2, cz + fw / 2, dir ^ 1);
          var back = FacilityStyle.SINK_BASIN_D / 2;
          var dx = (dir == 2 ? -back : (dir == 3 ? back : 0.0));
          var dz = (dir == 0 ? -back : (dir == 1 ? back : 0.0));
          MeshBufTools.quad(b[B_BASIN],
            [fe[0] + dx, y + h, fe[1] + dz], [fe[2] + dx, y + h, fe[3] + dz],
            [fe[2] + dx, y + h + fh, fe[3] + dz], [fe[0] + dx, y + h + fh, fe[1] + dz], [
            FacilityStyle.SINK_FAUCET_U0, FacilityStyle.SINK_FAUCET_V0,
            FacilityStyle.SINK_FAUCET_U1, FacilityStyle.SINK_FAUCET_V0,
            FacilityStyle.SINK_FAUCET_U1, FacilityStyle.SINK_FAUCET_V1,
            FacilityStyle.SINK_FAUCET_U0, FacilityStyle.SINK_FAUCET_V1,
          ]);
        }
      // and the mirror, on the MASONRY's own face pushed MOUNT_PROUD clear of it — the notice board's
      // mounting exactly, and never the cell boundary, which is a whole unit inside the room
      var mw = FacilityStyle.MIRROR_W / 2;
      var my = FacilityStyle.MIRROR_Y;
      var mh = FacilityStyle.MIRROR_H / 2;
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var inw = dir ^ 1;
      if (alongX)
        {
          var mz = (inw == 0 ? s.z0 - e : s.z1 + e);
          FacilityGeom.pane(b[B_MIRROR], cx - mw, cx + mw, mz, mz, inw, my - mh, my + mh);
        }
      else
        {
          var mx = (inw == 2 ? s.x0 - e : s.x1 + e);
          FacilityGeom.pane(b[B_MIRROR], mx, mx, cz - mw, cz + mw, inw, my - mh, my + mh);
        }
    }

// one floor drain, centred on its cell.
//
// IT USED TO BE ITS OWN ATLAS ICON LAID FLAT, and that is the whole reason this exists. The icon is
// baked into app/img/entities64.png at 32 x 32 inside a 64 cell, drawn on a render.particles.Sprites
// quad of SIZE 3.0 — 21 texels per world unit against the floor tile's own 73, and reported from the
// game as blurry. The atlas is right for the 2D view and right for BATCHING (see Sprites.atlasTex:
// per-cell textures open a draw call each), but it caps a floor fitting at 32 px forever.
//
// emitted here it takes the 256 source directly, mapped 0..1 over its own square: 170 texels per
// world unit, one merged mesh for every drain in the compound, and a normal `lift` for its value.
// render.facility.FacilityGeom.floorBuf still refuses to paint Surf.GRATE as a floor — a cell-wide
// 2 m square of grating read as a vehicle pit, and that finding is about the SIZE, not the route
  static function drain(b:MeshBuf, col:Int, row:Int, half:Float):Void
    {
      var cx = (col + 0.5) * CELL - half;
      var cz = (row + 0.5) * CELL - half;
      var s = FacilityStyle.DECO_DRAIN_SZ / 2;
      var y = FacilityGround.surfY(Surf.TILE) + FacilityStyle.DECO_DRAIN_EPS;
      // FacilityGeom.cap's winding, so it faces up, with the art over the square instead of tiled
      MeshBufTools.quad(b,
        [cx - s, y, cz + s], [cx + s, y, cz + s], [cx + s, y, cz - s], [cx - s, y, cz - s],
        [0, 1, 1, 1, 1, 0, 0, 0]);
    }

// where the ROUND low fittings stand, appended to `places`. shared by the drum batch below and by
// the bin batch in render.facility.FacilityGround, which the compound's OUTDOOR bins already own — a
// second batch for a handful of indoor bins would be a second draw call for nothing.
//
// AGAINST THE WALL where the cell has one, and a WINDOW COUNTS here where it does not for a fitting.
// FacilityModel.isSolidWall rules a window out because a sill is exactly where a worktop would be,
// which is the right answer for a 2.8-tall cabinet and the wrong one for something 1.8 high — and it
// matters because the generator FORCES the low list beside glazing (FacilityAreaGenerator's
// nextToWindow test), so on masonry alone most of this family would stand adrift in the middle of
// its cell. With no wall on any hand it does stand in the middle, which the cell is unwalkable for
// either way.
//
// where a ROUND fitting on this cell stands, and which hand its wall is on. the job `rectOf` does for
// the emitted family, and pulled out of `placeRound` for the same reason that one was pulled out of
// `unit`: `standOff` below has to answer where the glb is DRAWN, and a hand-written second copy of
// the slab arithmetic would be wrong in exactly the place that is hard to see — the face is a whole
// unit inside the cell boundary. dir -1 = no masonry on any hand, and then it stands in the middle
  public static function roundAt(m:Facility, col:Int, row:Int):{ x:Float, z:Float, dir:Int }
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var cx = (col + 0.5) * CELL - half;
      var cz = (row + 0.5) * CELL - half;
      var dir = -1;
      for (i in 0...4)
        if (FacilityModel.isWall(m, col + DC[i], row + DR[i]))
          {
            dir = i;
            break;
          }
      // off the WALL FACE and not the cell boundary, which is a unit away — the trap the corridor
      // casework and the lab kit both record
      if (dir >= 0)
        {
          var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
          var off = FacilityStyle.DECO_ROUND_D / 2 + FacilityStyle.STAND_GAP;
          cx = (dir == 2 ? s.x1 + off : (dir == 3 ? s.x0 - off : cx));
          cz = (dir == 0 ? s.z1 + off : (dir == 1 ? s.z0 - off : cz));
        }
      return {
        x: cx,
        z: cz,
        dir: dir,
      };
    }

// how far the thing standing on this cell is DRAWN from the cell's centre, in world xz — null where
// it stands in the middle, which is every cell with no fitting on it and every fitting with no wall
// on any hand.
//
// THE POSE HAS TO FOLLOW THE GEOMETRY, and this is the hook that lets it. render.Actors holds one
// pose per object and that pose is the cell centre; the fitting families here all stand OFF THE WALL
// FACE instead, which is a whole unit inside the cell boundary, so a 1.2-wide drum is drawn 2.28 of a
// 4-unit cell away from its own object. Everything that reads the geometry already agrees — the
// contact pool, the wall halo and the glb placement are all built off the same rect — and the actor
// POSE was the one thing left behind. It is not seen as a misplaced icon because `draws` suppresses
// that icon; it is seen as render.actors.LampShadows projecting the fake cast shadow from the middle
// of the tile while the drum stands against the wall, which is how it was reported.
//
// reached from render.Actors through render.world.WorldCtx.standOff, the same per-cell hook
// FacilityGeom.wallMounts answers on — a pure function of the saved grid, asked per object per frame
  public static function standOff(m:Facility, col:Int, row:Int):{ x:Float, z:Float }
    {
      if (!FacilityModel.inside(m, col, row))
        return null;
      var kind = m.deco[row][col] - 1;
      if (kind < 0)
        return null;
      var half = (CityConfig.GRID * CELL) / 2;
      var cx = (col + 0.5) * CELL - half;
      var cz = (row + 0.5) * CELL - half;
      var x, z;
      if (isProp(kind))
        {
          var p = roundAt(m, col, row);
          x = p.x;
          z = p.z;
        }
      else
        {
          var r = rectOf(m, col, row, kind);
          x = (r.x0 + r.x1) / 2;
          z = (r.z0 + r.z1) / 2;
        }
      if (x == cx &&
          z == cz)
        return null;
      return {
        x: x - cx,
        z: z - cz,
      };
    }

// the yaw is FREE: a drum is a cylinder, and a bin's mouth may as well look anywhere indoors — where
// the outdoor bins aim theirs at the path, these have no path to aim at
  public static function placeRound(m:Facility, kind:Int, places:Array<Models.PropPlace>):Void
    {
      var y = FacilityGround.surfY(Surf.TILE);
      var r = FacilityStyle.DECO_ROUND_D / 2;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.deco[row][col] - 1 != kind)
              continue;
            var p = roundAt(m, col, row);
            var cx = p.x, cz = p.z, dir = p.dir;
            // TURNED AWAY from the masonry it stands against. the bin's mouth is a hole in its lid
            // and its own front is local +z (measured off the built glb — see FacilityGround.bins),
            // so a free turn would put a third of them face to the wall. a drum is a cylinder and
            // does not care either way, so one rule serves both; with no wall on any hand the turn
            // goes back to being free
            var h = FacilityModel.mix((col * 668265263) ^ (row * 374761393));
            places.push({
              x: cx,
              z: cz,
              yaw: (dir >= 0 ? Math.atan2(DC[dir ^ 1], DR[dir ^ 1]) :
                ((h % 1000) / 1000) * 2 * Math.PI),
              y: y,
            });
            // the floor pool under it, on the plain square: the field is what darkens the tile a
            // standing thing sits on, and it is repainted once after every prop pass has placed
            ContactMask.prop(cx - r, cx + r, cz - r, cz + r);
            // and the shadow on the masonry behind, which a top-down field cannot reach. SOLID walls
            // only — a halo laid on a window cell would land on the glazing
            if (dir >= 0 &&
                FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]))
              FacilityDetail.stand({
                col: col,
                row: row,
                dir: dir,
                a0: (dir < 2 ? cx : cz) - r,
                a1: (dir < 2 ? cx : cz) + r,
                len: 1,
                y: y,
                h: FacilityStyle.DECO_ROUND_H,
              });
          }
    }

// the hazard barrels: ONE BATCH PER LIVERY, all three off the same source mesh.
//
// the atlas draws three different drums and the low list deals all three, so each is its own
// art/models.json label over the TUNNELS' own sewer/drum.glb — repainted, not regenerated (see
// art/models.json's facility/drum-steel for why an edit_image pass was rejected for a per-pixel
// transform). They are three PATHS and not one because render.Models.instanced is keyed by path and
// carries no per-instance UV offset: a livery is a batch and a batch is a draw call. That is the
// price of the marking, paid knowingly.
//
// the BIN is the round fitting with no entry here, and it is the one that costs nothing: the
// compound's outdoor bin batch already exists, so those placements go into it — see `placeRound`
// and render.facility.FacilityGround.bins
//
// AND THE PATHS ARE A SWITCH, FacilityStyle.DECO_DRUM_BLENDER: the hand-modelled barrels are the
// same three liveries off the same three batches, so nothing above changes — what changes is 1,200
// generated triangles against 44 authored ones, and a WRAP instead of a bake
  public static final PROPS:Array<DrumProp> = [
    {
      kind: _FittingKind.FIT_DRUM_STEEL,
      path: (FacilityStyle.DECO_DRUM_BLENDER ?
        RenderConfig.MODELS.facilityDrumSteelHand : RenderConfig.MODELS.facilityDrumSteel),
    },
    {
      kind: _FittingKind.FIT_DRUM_BIO,
      path: (FacilityStyle.DECO_DRUM_BLENDER ?
        RenderConfig.MODELS.facilityDrumBioHand : RenderConfig.MODELS.facilityDrumBio),
    },
    {
      kind: _FittingKind.FIT_DRUM_RAD,
      path: (FacilityStyle.DECO_DRUM_BLENDER ?
        RenderConfig.MODELS.facilityDrumRadHand : RenderConfig.MODELS.facilityDrumRad),
    },
  ];

// the WC pans, one batch for the compound. a glb and not geometry for the drum's own reason: a pan
// is a curved shell with a cistern behind it and FacilityGeom emits axis-aligned quads only.
//
// PLACED OFF THE CUBICLE'S OWN RECT and not off the cell: `rectOf` has already slid the cubicle along
// its wall, so the pan goes against the BACK of that rect on its centre line, turned to face the door
  public static function toilets(scene:Scene, m:Facility):Models.InstancedProp
    {
      var y = FacilityGround.surfY(Surf.TILE);
      var places:Array<Models.PropPlace> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.deco[row][col] - 1 != _FittingKind.FIT_STALL)
              continue;
            var r = rectOf(m, col, row, _FittingKind.FIT_STALL);
            // the back of the cubicle is the wall hand; the pan stands half its own depth off it
            var back = FacilityStyle.TOILET_D / 2 + FacilityStyle.STAND_GAP;
            var cx = (r.x0 + r.x1) / 2, cz = (r.z0 + r.z1) / 2;
            var x = (r.dir == 2 ? r.x0 + back : (r.dir == 3 ? r.x1 - back : cx));
            var z = (r.dir == 0 ? r.z0 + back : (r.dir == 1 ? r.z1 - back : cz));
            places.push({
              x: x,
              z: z,
              // looking the way the door does, i.e. away from the masonry — placeRound's own turn
              yaw: Math.atan2(DC[r.dir ^ 1], DR[r.dir ^ 1]),
              y: y,
            });
          }
      var prop = Models.instanced(scene, TOILET_PATH, places,
        FacilityStyle.TOILET_H, SOLID);
      // NOT CASTING, the drums' own finding: an instanced batch is drawn into the moon's shadow map
      // as many times as into the frame, and these stand under a faded roof
      if (places.length > 0)
        Models.get(TOILET_PATH, function(_)
          {
            VisionMask.patchMesh(prop.mesh);
            prop.mesh.castShadow = false;
          });
      return prop;
    }

// every FITTING KIND that ships as a hand-modelled glb instead of emitted quads, ONE BATCH EACH.
// A row is here only while its family's ..._GLB flag is on, and `unit` above emits that family's
// quads only while it is off — so the A/B is a rebuild and never a deletion.
//
// THE ROW IS PER MESH AND NOT PER FAMILY, which cost the low rack a second path, material, program
// and warm row and is still the only right answer. Models.instanced sizes a batch by HEIGHT alone,
// and DECO_RACK_LOW_H is DECO_RACK_TILE — exactly three chassis — while `lights` below deals
// `h / DECO_RACK_TILE * DECO_LED_PER_TILE` rows off that same arithmetic. Drawing the six-chassis
// mesh at the low height therefore gave six SQUASHED units standing under three rows of lights: the
// cheap version was not a compromise, it was wrong
  public static function fittings(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var rows:Array<{ kind:Int, path:String, h:Float, on:Bool }> = [
        {
          kind: _FittingKind.FIT_RACK,
          path: RenderConfig.MODELS.facilityRack,
          h: FacilityStyle.DECO_RACK_H,
          on: FacilityStyle.DECO_RACK_GLB,
        },
        {
          kind: _FittingKind.FIT_RACK_LOW,
          path: RenderConfig.MODELS.facilityRackLow,
          h: FacilityStyle.DECO_RACK_LOW_H,
          on: FacilityStyle.DECO_RACK_GLB,
        },
        {
          kind: _FittingKind.FIT_CABINET,
          path: RenderConfig.MODELS.facilityCabinet,
          h: FacilityStyle.DECO_CABINET_H,
          on: FacilityStyle.DECO_CABINET_GLB,
        },
        // both machine heights off ONE path, which is the rack's trap the other way up: nothing in
        // this family is a count, so scaling the cube by height is the whole difference
        {
          kind: _FittingKind.FIT_MACHINE,
          path: RenderConfig.MODELS.facilityMachine,
          h: FacilityStyle.DECO_MACHINE_SZ,
          on: FacilityStyle.DECO_MACHINE_GLB,
        },
        {
          kind: _FittingKind.FIT_MACHINE_LOW,
          path: RenderConfig.MODELS.facilityMachine,
          h: FacilityStyle.DECO_MACHINE_LOW_SZ,
          on: FacilityStyle.DECO_MACHINE_GLB,
        },
        {
          kind: _FittingKind.FIT_BOOKCASE,
          path: RenderConfig.MODELS.facilityBookcase,
          h: FacilityStyle.DECO_BOOKCASE_H,
          on: FacilityStyle.DECO_BOOKCASE_GLB,
        },
        {
          kind: _FittingKind.FIT_SHELVING,
          path: RenderConfig.MODELS.facilityShelving,
          h: FacilityStyle.DECO_SHELF_H,
          on: FacilityStyle.DECO_SHELF_GLB,
        },
        // sized by the mesh's OWN height and not by BASIN_H — the tap is part of it
        {
          kind: _FittingKind.FIT_BASIN,
          path: RenderConfig.MODELS.facilityBasin,
          h: FacilityStyle.BASIN_MESH_H,
          on: FacilityStyle.DECO_BASIN_GLB,
        },
        {
          kind: _FittingKind.FIT_SOFA,
          path: RenderConfig.MODELS.facilitySofa,
          h: FacilityStyle.DECO_SOFA_H,
          on: FacilityStyle.DECO_SOFA_GLB,
        },
        {
          kind: _FittingKind.FIT_TABLE_LOW,
          path: RenderConfig.MODELS.facilityTableLow,
          h: FacilityStyle.DECO_TABLE_LOW_H,
          on: FacilityStyle.DECO_TABLE_LOW_GLB,
        },
        // APPENDED, never inserted — render.facility.FacilityArea.EXTRA has to stay index-aligned
        // with `green` and this list is what fills it. The hangar's second machine, and the one row
        // here with no flag to turn off: it never had an emitted version to fall back to
        {
          kind: _FittingKind.FIT_ANALYSER,
          path: RenderConfig.MODELS.facilityAnalyser,
          h: FacilityStyle.DECO_ANALYSER_H,
          on: true,
        },
        // and the STORE's three, appended for the same reason and with no flag each: they replace
        // nothing, so there is nothing to A/B them against
        {
          kind: _FittingKind.FIT_PALLET_RACK,
          path: RenderConfig.MODELS.facilityPalletRack,
          h: FacilityStyle.DECO_PALLET_RACK_H,
          on: true,
        },
        {
          kind: _FittingKind.FIT_PALLET_STACK,
          path: RenderConfig.MODELS.facilityPalletStack,
          h: FacilityStyle.DECO_PALLET_STACK_H,
          on: true,
        },
        {
          kind: _FittingKind.FIT_DRUM_PALLET,
          path: RenderConfig.MODELS.facilityDrumPallet,
          h: FacilityStyle.DECO_DRUM_PALLET_H,
          on: true,
        },
      ];
      var out = [];
      for (r in rows)
        {
          var places:Array<Models.PropPlace> = [];
          if (r.on)
            for (row in 0...m.h)
              for (col in 0...m.w)
                {
                  if (m.deco[row][col] - 1 != r.kind)
                    continue;
                  var rect = rectOf(m, col, row, r.kind);
                  places.push({
                    x: (rect.x0 + rect.x1) / 2,
                    z: (rect.z0 + rect.z1) / 2,
                    // facing away from the masonry it is bolted to, the toilets' own turn
                    yaw: Math.atan2(DC[rect.dir ^ 1], DR[rect.dir ^ 1]),
                    y: FacilityGround.surfY(Surf.TILE),
                  });
                }
          var prop = Models.instanced(scene, r.path, places, r.h, SOLID);
          out.push(prop);
          // NOT CASTING and mask-patched, the drums' own two findings — see `drums` below
          if (places.length > 0)
            Models.get(r.path, function(_)
              {
                VisionMask.patchMesh(prop.mesh);
                prop.mesh.castShadow = false;
              });
        }
      return out;
    }

// one instanced batch per livery, index-aligned with PROPS — the shape render.facility.FacilityKit
// .props takes, so render.facility.FacilityGround.EXTRA and FacilityWarm both derive their rows off
// the table above and a fourth livery needs no edit in either
  public static function drums(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var out = [];
      for (p in PROPS)
        {
          var places:Array<Models.PropPlace> = [];
          placeRound(m, p.kind, places);
          var prop = Models.instanced(scene, p.path, places, FacilityStyle.DECO_ROUND_H, SOLID);
          out.push(prop);
          // behind the loader callback, because the mesh does not exist until the glb resolves —
          // and only for a batch that placed something, or an empty one is patched for nothing.
          // NOT CASTING, the indoor litter bin's own finding: an instanced batch is drawn into the
          // moon's shadow map as many times as it is drawn into the frame, so the second draw is a
          // second call the moment the batch is in view at all, and these stand under a faded roof
          if (places.length > 0)
            Models.get(p.path, function(_)
              {
                VisionMask.patchMesh(prop.mesh);
                prop.mesh.castShadow = false;
              });
        }
      return out;
    }

// the shelving as QUADS: two alpha-cut end frames and a bare quad per shelf.
//
// SUPERSEDED BY THE GLB and kept behind FacilityStyle.DECO_SHELF_GLB for the A/B, exactly as the
// rack, the cabinet, the machine and the bookcase are. What it could never state is the reason the
// glb exists: an end FRAME drawn on a pane is a cut-out of a frame, and the shelves have no
// thickness because a slab plus an edge band is four more quads a level.
//
// NO BACK AND NO TOP. Both were in the first build and both were wrong for the same reason — this
// camera pitches 51 degrees DOWN, so a lid is most of what is seen of a unit and it hid everything
// under it, and a back panel behind an open frame is a flat card you cannot see past. The glb keeps
// both rules.
//
// AND THE BOXES ARE NOT HERE ANY MORE. `boxes` stood 1..3 crates on every plate of every unit and
// nothing else ever, which is why a shelving unit was the same object every time; the crates are
// one of the things render.facility.FacilityClutter deals into a lid now, mixed with the sheet
  static function shelf(b:Array<MeshBuf>, x0:Float, x1:Float, z0:Float, z1:Float, y:Float,
      h:Float, head:Int):Void
    {
      FacilityGeom.pane(b[B_SHELF_SIDE], x0, x1, z0, z1, head, y, y + h);
      FacilityGeom.pane(b[B_SHELF_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
      for (lv in FacilityStyle.DECO_SHELF_Y)
        FacilityGeom.cap(b[B_SHELF_TOP], x0, x1, z0, z1, y + h * lv,
          FacilityStyle.DECO_SHELF_TILE);
    }

// one box, TURNED about its own vertical axis. four sides and a top, no bottom.
//
// it cannot go through FacilityGeom.face, which takes an axis-aligned rect — and the turn is the
// point: a rank of square-on cuboids reads as one machined object rather than as things someone
// put there. `u` runs along each face's own length at WORLD scale from a per-box phase rather than
// 0..1 across it, so the cardboard is never stretched by the turn and no two boxes show the same
// patch of the sheet.
//
// AND IT CARRIES ITS OWN SHADING, on the vertex channel, because the room has none to give it: the
// bay's weight over the whole box and a darkening down each side to the plate it stands on. The
// buffer this writes into is the ONLY one keyed to a colour — B_BOX is written by this function and
// nothing else — so no shared surface has to learn to push a channel it does not use
  public static function crate(b:MeshBuf, o:FacilityCrateOpts):Void
    {
      var c = Math.cos(o.yaw), s = Math.sin(o.yaw);
      // the corners in the one cyclic order that winds every face OUTWARD: sides walk i -> i + 1,
      // the top takes the same cycle starting one step later (see FacilityGeom.cap's winding)
      var lx = [ -o.hw, -o.hw, o.hw, o.hw ];
      var lz = [ -o.hd, o.hd, o.hd, -o.hd ];
      var wx = [], wz = [];
      for (i in 0...4)
        {
          wx.push(o.cx + lx[i] * c - lz[i] * s);
          wz.push(o.cz + lx[i] * s + lz[i] * c);
        }
      var t = FacilityStyle.DECO_BOX_TILE;
      var foot = o.ao * FacilityStyle.DECO_BOX_AO_FOOT;
      var u = o.ph;
      for (i in 0...4)
        {
          var j = (i + 1) % 4;
          var dx = wx[j] - wx[i], dz = wz[j] - wz[i];
          var un = u + Math.sqrt(dx * dx + dz * dz) / t;
          // p0 and p1 are the two on the shelf, p2 and p3 the two at the lid — so the contact runs
          // up the face and never across it, whichever way the box was turned
          MeshBufTools.quadC(b,
            [wx[i], o.y0, wz[i]], [wx[j], o.y0, wz[j]], [wx[j], o.y1, wz[j]], [wx[i], o.y1, wz[i]],
            [u, o.y0 / t, un, o.y0 / t, un, o.y1 / t, u, o.y1 / t],
            [foot, foot, o.ao, o.ao]);
          u = un;
        }
      // the top, mapped along the box's OWN axes so the flute lines turn with it. flat at the bay's
      // own weight: it is the face furthest from the shelf and the one this camera mostly sees
      var u0 = o.ph, u1 = o.ph + 2 * o.hw / t, v0 = o.ph, v1 = o.ph + 2 * o.hd / t;
      MeshBufTools.quadC(b,
        [wx[1], o.y1, wz[1]], [wx[2], o.y1, wz[2]], [wx[3], o.y1, wz[3]], [wx[0], o.y1, wz[0]],
        [u0, v1, u1, v1, u1, v0, u0, v0],
        [o.ao, o.ao, o.ao, o.ao]);
    }

// one rack's lights: a pair of specks on each CHASSIS of its front face, each with its own blink
// phase and its own hue. all of them in ONE additive mesh with the compound's other racks (see
// `lamps`), so a wall of them costs one draw call and no per-frame work beyond the shared clock.
//
// the field is READ OFF THE ART: rows on the units the image draws, columns in the blank strip
// beside their vent panels. It shipped as an even 6 x 3 grid over a band of the face, which put
// specks across the vent mesh and across the recessed gaps between chassis — a lattice on a rack
// rather than a rack's own ports
  static function lights(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, h:Float,
      dir:Int, col:Int, row:Int):Void
    {
      var e = FacilityStyle.DECO_LED_EPS;
      // the plane the field lies in, a hair proud of the face so the additive quad is never coplanar
      var f = (dir == 0 ? z1 + e : (dir == 1 ? z0 - e : (dir == 2 ? x1 + e : x0 - e)));
      // ACROSS the face from the TEXTURE'S OWN u ORIGIN and not from the lower coordinate: `localFace`
      // opens u at FacilityGeom.ends' first vertex, which is x1 or z1 on two of the four hands. The
      // old even grid was symmetric about the face and could not tell the difference; a band pinned
      // to a strip of the art can, and pinned the wrong way round it lands on the vent panel
      var w = FacilityGeom.ends(x0, x1, z0, z1, dir ^ 1);
      var a0 = (dir < 2 ? w[0] : w[1]);
      var a1 = (dir < 2 ? w[2] : w[3]);
      // one row per CHASSIS, over however many repeats of the art the face is tall
      var rows = Math.round(h / FacilityStyle.DECO_RACK_TILE * FacilityStyle.DECO_LED_PER_TILE);
      var s = FacilityStyle.DECO_LED_SIZE / 2;
      var g = FacilityModel.mix((col * 971658137) ^ (row * 1266489917));
      for (r in 0...rows)
        for (c in 0...FacilityStyle.DECO_LED_COLS)
          {
            var hh = FacilityModel.mix(g ^ ((r * FacilityStyle.DECO_LED_COLS + c) * 40503));
            var uf = FacilityStyle.DECO_LED_U0 + (FacilityStyle.DECO_LED_U1 -
              FacilityStyle.DECO_LED_U0) * (c + 0.5) / FacilityStyle.DECO_LED_COLS;
            var ac = a0 + (a1 - a0) * uf;
            var yc = y + h * (r + 0.5) / rows;
            // r = level, g = blink phase, b = which of the two hues. see MeshBufTools.quadRGB and
            // the shader patch in `blink` — the three are read apart there rather than multiplied in
            var lvl = 0.7 + ((hh % 1000) / 1000) * 0.3;
            var ph = ((hh >>> 11) % 1000) / 1000;
            var hue = ((hh >>> 21) % 3 == 0 ? 0.0 : 1.0);
            var p0 = (dir < 2 ? [ac - s, yc - s, f] : [f, yc - s, ac - s]);
            var p1 = (dir < 2 ? [ac + s, yc - s, f] : [f, yc - s, ac + s]);
            var p2 = (dir < 2 ? [ac + s, yc + s, f] : [f, yc + s, ac + s]);
            var p3 = (dir < 2 ? [ac - s, yc + s, f] : [f, yc + s, ac - s]);
            MeshBufTools.quadRGB(b, p0, p1, p2, p3,
              [0, 0, 1, 0, 1, 1, 0, 1], lvl, ph, hue);
          }
    }

// the machine's control strip: one lit dot RUNNING the row of five buttons, with a decaying tail.
//
// same buffer, same mesh, same material and same clock as `lights` above, so a compound full of
// machines and racks together is still ONE additive draw call — but a different PATTERN off them,
// which is the whole point. A rack's ports are independent traffic and the square wave beside this
// says so; a machine panel is a sequencer, and a row of specks blinking at random on one would read
// as a small rack rather than as a machine doing something. The two are told apart in the shader by
// the hue channel: `blink` treats 0..1 as a rack and 2..3 as a machine (see FacilityStyle
// .DECO_MACH_LED_U for the measured slots, and `blink` for what the channel costs).
//
// the face maps 0..1 here, unlike the rack's, so a slot's u IS the texture's u and one measurement
// off the art serves both heights at any width
  static function machLights(b:MeshBuf, o:DecoLedOpts):Void
    {
      var e = FacilityStyle.DECO_LED_EPS;
      // the plane the strip lies in, a hair proud of the FRONT — the face opposite the wall
      var f = (o.dir == 0 ? o.z1 + e :
              (o.dir == 1 ? o.z0 - e :
              (o.dir == 2 ? o.x1 + e : o.x0 - e)));
      // ACROSS the face from the TEXTURE'S OWN u origin and not from the lower coordinate, the trap
      // `lights` records: FacilityGeom.ends opens u at x1 or z1 on two of the four hands
      var w = FacilityGeom.ends(o.x0, o.x1, o.z0, o.z1, o.dir ^ 1);
      var a0 = (o.dir < 2 ? w[0] : w[1]);
      var a1 = (o.dir < 2 ? w[2] : w[3]);
      var s = Math.abs(a1 - a0) * o.size / 2;
      var yc = o.y + o.h * o.v;
      // and one OFFSET per unit, so two machines in a room are not stepping in lockstep — the clock
      // is shared by identity and the slot phases below are fixed, so this is the only thing that
      // can separate them
      var g = FacilityModel.mix((o.col * 1103515245) ^ (o.row * 12345));
      var off = ((g % 1000) / 1000);
      for (i in 0...o.us.length)
        {
          var ac = a0 + (a1 - a0) * o.us[i];
          // the light's PLACE in the run, which is what the shader's chase reads its phase as
          var ph = off + i / o.us.length;
          var hue = (i >= o.greenFrom ? 1.0 : 0.0);
          var p0 = (o.dir < 2 ? [ac - s, yc - s, f] : [f, yc - s, ac - s]);
          var p1 = (o.dir < 2 ? [ac + s, yc - s, f] : [f, yc - s, ac + s]);
          var p2 = (o.dir < 2 ? [ac + s, yc + s, f] : [f, yc + s, ac + s]);
          var p3 = (o.dir < 2 ? [ac - s, yc + s, f] : [f, yc + s, ac - s]);
          // b carries the hue OFFSET BY THE MODE, which is how one mesh runs four patterns — see
          // `blink` and FacilityStyle.DECO_LED_CHASE
          MeshBufTools.quadRGB(b, p0, p1, p2, p3,
            [0, 0, 1, 0, 1, 1, 0, 1], 1.0, ph, o.mode + hue);
        }
    }

// merge one surface's buffer into a lit mesh. interior surfaces, so they receive the moon's shadow
// and cast none of their own — the pair every indoor buffer in FacilityGeom takes, and the same
// merge render.facility.FacilityTables makes for its benches. VisionMask.patch is what also folds
// in the indoor lighting swap, so nothing else has to be asked for here.
//
// `both` is for a surface with NO THICKNESS — the shelving's bare shelf quads, which have to be
// seen from under as well as over. an opaque material draws DoubleSide in ONE pass.
//
// `vertexColors` is DERIVED from the buffer and never passed in, which is what stops it drifting out
// of step with FacilityGeom.geom's own test: exactly one of these six carries a colour channel
// (B_BOX, filled by `crate`), and a mismatch either way is silent — an attribute nothing samples, or
// a shader reading one that is not there
  public static function solid(scene:Scene, b:MeshBuf, tex:String, both:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: both ? THREE.DoubleSide : THREE.FrontSide,
        vertexColors: b.col.length > 0,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// and the one surface that is CUT: the shelving's end frame, an alpha-tested OPAQUE material rather
// than a transparent one — it draws DoubleSide in a single pass and still writes depth, where a
// transparent twin would sort against every other see-through thing in the compound for nothing.
// `transparent` stays false, which also keeps VisionMask on its darkening branch (see the note in
// FacilityGeom.addPane for what setting it first would cost)
  static function cut(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        alphaTest: FacilityStyle.DECO_CUT,
        side: THREE.DoubleSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// every rack light in the compound, in one additive mesh — the shape render.facility.FacilityGlow
// merges the ceiling panels and window spill with, and for the same reason. it is a SECOND mesh and
// not a few more quads in that one because these MOVE: the glow layer is built once and never
// touched again, and its brightness arithmetic is load-bearing for what blooms
  static function lamps(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var geo = new BufferGeometry();
      geo.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      geo.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      geo.setAttribute('color', new Float32BufferAttribute(b.col, 3));
      geo.setIndex(b.idx);
      // a round soft dot rather than the square-cornered patch the window spill takes: at 0.30 the
      // rounded-box SDF that generator draws IS a circle
      var mesh = new Mesh(geo, VisionMask.patch(blink(new MeshBasicMaterial({
        color: 0xffffff,
        transparent: true,
        alphaMap: Textures.makeRectGlowGradient(0.30),
        vertexColors: true,
        depthWrite: false,
        side: THREE.DoubleSide,
        blending: untyped THREE.AdditiveBlending,
      }))));
      // BELOW the actors, the call FacilityGlow's own header records: nothing in the sprite pool
      // writes depth, so a glow at the actors' order paints straight through anyone in front of it
      mesh.renderOrder = Sprites.ORD_FIXTURE;
      scene.add(mesh);
    }

// fold the blink into the light material.
//
// it REPLACES <color_fragment> rather than adding to it, and that is the whole trick: three's own
// include multiplies the vertex colour into the diffuse, which would make a phase stored in g tint
// the light green. Here the three channels are read APART — r is the light's level, g its phase, b
// which of the two hues it burns — so one mesh carries a whole rack of independent lights.
//
// AND FOUR PATTERNS OFF ONE PROGRAM, which is what the b channel is doing quadruple duty for. A
// rack's ports are independent traffic (a square wave, each light on its own phase); a machine's
// control strip is a SEQUENCER (one dot running the row with a decaying tail); a workstation's SCREEN
// is neither, and is two sines with no common period summed shallow, so it wobbles and never loops;
// an ANALYSER's lens row is a SCAN, one head bouncing along it slowly, which is the fourth and was
// added because the analyser and the machine ran the same chase off the same clock and were reported
// from the game as one object drawn twice. All four live in the same mesh and material because a
// second one is a second draw call, so the mode
// has to travel per VERTEX — and there are only three channels. It rides the hue: b in 0..1 is a RACK
// burning `mix(A, B, b)`, b in 2..3 a MACHINE burning `mix(A, B, b - 2)`, b in 4..5 a SCREEN burning
// C outright (one colour, off the screen art's own measured hue — see WORK_SCREEN_GLOW), b in 6..7 an
// ANALYSER burning the machine's two hues on the scan (FacilityStyle.DECO_LED_SCAN). Nothing else
// samples this attribute (the include that would is the one being replaced) and a varying is not
// clamped, so a 2 or a 4 reaches the fragment stage untouched. Every branch is evaluated and mixed
// rather than branched on: they are a handful of instructions each and this mesh is a few hundred
// specks.
//
// every rate, depth and falloff is a UNIFORM and not a literal, so retuning any of them compiles
// nothing (the PropShine pulse's own note); the chaining
// and the customProgramCacheKey are render.world.PropEnv.apply's, whose header carries the trap
// (three's Material has a DEFAULT customProgramCacheKey on the PROTOTYPE, so it must be taken as an
// own property or it is called unbound every draw)
  static function blink(mat:Dynamic):Dynamic
    {
      var uRate = { value: FacilityStyle.DECO_LED_RATE };
      var uDepth = { value: FacilityStyle.DECO_LED_DEPTH };
      var uChase = { value: FacilityStyle.DECO_MACH_LED_RATE };
      var uTail = { value: FacilityStyle.DECO_MACH_LED_TAIL };
      var uA = { value: new Color(FacilityStyle.DECO_LED_AMBER)
        .multiplyScalar(FacilityStyle.DECO_LED_GLOW) };
      var uB = { value: new Color(FacilityStyle.DECO_LED_GREEN)
        .multiplyScalar(FacilityStyle.DECO_LED_GLOW) };
      var uC = { value: new Color(FacilityStyle.WORK_SCREEN_GLOW) };
      var uScr = { value: FacilityStyle.DECO_SCREEN_RATE };
      var uScr2 = { value: FacilityStyle.DECO_SCREEN_RATE2 };
      var uScrD = { value: FacilityStyle.DECO_SCREEN_DEPTH };
      var uAnal = { value: FacilityStyle.DECO_ANAL_LED_RATE };
      var inject =
        '  float decoAnal = step( 5.5, vColor.b );\n' +
        '  float decoScr = step( 3.5, vColor.b ) * ( 1.0 - decoAnal );\n' +
        '  float decoMode = step( 1.5, vColor.b ) * ( 1.0 - decoScr ) * ( 1.0 - decoAnal );\n' +
        '  float decoHue = vColor.b - 2.0 * decoMode - 4.0 * decoScr - 6.0 * decoAnal;\n' +
        '  float decoBlink = 1.0 - decoLedDepth + decoLedDepth *\n' +
        '    step( 0.5, fract( decoLedTime * decoLedRate + vColor.g ) );\n' +
        '  float decoRun = pow( 1.0 -\n' +
        '    fract( decoLedTime * decoLedChase - vColor.g ), decoLedTail );\n' +
        '  float decoFlick = 1.0 - decoScrDepth + decoScrDepth * ( 0.5 + 0.5 * (\n' +
        '    0.6 * sin( decoLedTime * decoScrRate + vColor.g * 6.2831 ) +\n' +
        '    0.4 * sin( decoLedTime * decoScrRate2 + vColor.g * 19.739 ) ) );\n' +
        // the head BOUNCES: a triangle wave off the same clock, and the distance to it is measured
        // the SHORT WAY ROUND (the fract/0.5 pair), because a slot's phase is its place in the run
        // plus its unit's own offset and that sum runs past 1
        '  float decoHead = abs( 2.0 * fract( decoLedTime * decoAnalRate ) - 1.0 );\n' +
        '  float decoScan = pow( max( 0.0, 1.0 - 2.0 *\n' +
        '    abs( fract( decoHead - vColor.g + 0.5 ) - 0.5 ) ), decoLedTail );\n' +
        '  diffuseColor.rgb = mix( mix( decoLedA, decoLedB, decoHue ), decoLedC, decoScr ) *\n' +
        '    ( vColor.r * mix( mix( mix( decoBlink, decoRun, decoMode ), decoFlick, decoScr ),\n' +
        '      decoScan, decoAnal ) );\n';
      var prev:Dynamic = mat.onBeforeCompile;
      var prevKey:Dynamic = untyped mat.hasOwnProperty('customProgramCacheKey') ?
        mat.customProgramCacheKey : null;
      var hook:Dynamic = function(shader:Dynamic, renderer:Dynamic)
        {
          if (prev != null)
            prev(shader, renderer);
          shader.uniforms.decoLedTime = uTime;
          shader.uniforms.decoLedRate = uRate;
          shader.uniforms.decoLedDepth = uDepth;
          shader.uniforms.decoLedChase = uChase;
          shader.uniforms.decoLedTail = uTail;
          shader.uniforms.decoLedA = uA;
          shader.uniforms.decoLedB = uB;
          shader.uniforms.decoLedC = uC;
          shader.uniforms.decoScrRate = uScr;
          shader.uniforms.decoScrRate2 = uScr2;
          shader.uniforms.decoScrDepth = uScrD;
          shader.uniforms.decoAnalRate = uAnal;
          shader.fragmentShader = 'uniform float decoLedTime;\n' +
            'uniform float decoLedRate;\n' +
            'uniform float decoLedDepth;\n' +
            'uniform float decoLedChase;\n' +
            'uniform float decoLedTail;\n' +
            'uniform float decoScrRate;\n' +
            'uniform float decoScrRate2;\n' +
            'uniform float decoScrDepth;\n' +
            'uniform float decoAnalRate;\n' +
            'uniform vec3 decoLedA;\n' +
            'uniform vec3 decoLedB;\n' +
            'uniform vec3 decoLedC;\n' +
            StringTools.replace(shader.fragmentShader, '#include <color_fragment>', inject);
        };
      if (prev != null)
        for (f in Reflect.fields(prev))
          Reflect.setField(hook, f, Reflect.field(prev, f));
      hook.decoLed = true;
      mat.onBeforeCompile = hook;
      mat.customProgramCacheKey = function()
        return (prevKey != null ? Std.string(Reflect.callMethod(mat, prevKey, [])) : '') +
          'decoled';
      mat.needsUpdate = true;
      return mat;
    }
}

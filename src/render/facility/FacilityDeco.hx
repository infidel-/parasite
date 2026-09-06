package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.particles.Sprites;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

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
      return o.type == 'decoration' &&
        Const.fittingOf(o.imageRow, o.imageCol) >= 0;
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
      if (area == null ||
          area.typeID != AREA_FACILITY ||
          o.type != 'decoration' ||
          !Const.isTableDeco(o.imageRow))
        return 1.0;
      return FacilityStyle.DECO_TABLE_SCALE;
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

// how tall a fitting of this kind stands, world units
  static function heightOf(kind:Int):Float
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
          default: 0.0;
        };
    }

// every fitting in the compound. one merged mesh per SURFACE — sixteen of them plus the rack lights
  public static function build(scene:Scene, m:Facility):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      // indexed by Buf below, so a face names the surface it is made of rather than the kind it
      // belongs to
      var b = [for (_ in 0...16) MeshBufTools.make()];
      var leds = MeshBufTools.make();
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.drain[row][col])
              drain(b[B_DRAIN], col, row, half);
            var kind = m.deco[row][col] - 1;
            if (kind < 0 ||
                isProp(kind))
              continue;
            unit(m, b, leds, col, row, kind, half);
          }
      // the end frame is the one CUT surface; everything else is plain opaque merged geometry
      cut(scene, b[B_SHELF_SIDE], FacilityStyle.DECO_SHELF_SIDE);
      // DoubleSide: a shelf is a bare quad with no thickness, so it has to be seen from under it
      solid(scene, b[B_SHELF_TOP], FacilityStyle.DECO_SHELF_TOP, true);
      solid(scene, b[B_BOX], FacilityStyle.DECO_BOX, false);
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

// one fitting: work out the rect it stands on, then hand each of its faces to the surface it is
// made of
  static function unit(m:Facility, b:Array<MeshBuf>, leds:MeshBuf, col:Int, row:Int, kind:Int,
      half:Float):Void
    {
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
      var h = heightOf(kind);
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
          // no masonry on any hand, which the generator's own placement rule should make impossible.
          // stood square in the cell facing the resting camera rather than dropped: a cell must never
          // lose its sprite AND its geometry, and render.Actors has already stopped drawing the one
          dir = 0;
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
            shelf(b, x0, x1, z0, z1, y, h, dir, head, col, row);
          case _FittingKind.FIT_BOOKCASE:
            // front, two ends, a top, and no back and no bottom: the back is buried in the masonry
            // and this camera pitches 51 degrees down, so nothing ever sees under a fitting —
            // render.facility.FacilityRoof.box's own finding
            FacilityGeom.pane(b[B_BC_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
            FacilityGeom.face(b[B_BC_SIDE], x0, x1, z0, z1, head, y, y + h,
              FacilityStyle.DECO_BOOKCASE_TILE);
            FacilityGeom.face(b[B_BC_SIDE], x0, x1, z0, z1, head + 1, y, y + h,
              FacilityStyle.DECO_BOOKCASE_TILE);
            FacilityGeom.cap(b[B_BC_TOP], x0, x1, z0, z1, y + h, FacilityStyle.DECO_BOOKCASE_TILE);
          case _FittingKind.FIT_CABINET:
            // the bookcase's own shape, one surface family over: an authored front mapped 0..1 by
            // `pane`, two tiling ends and a tiling top, and no back and no bottom for the same
            // reason — the back is buried in the masonry and nothing at this pitch sees under a
            // fitting
            FacilityGeom.pane(b[B_CAB_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
            FacilityGeom.face(b[B_CAB_SIDE], x0, x1, z0, z1, head, y, y + h,
              FacilityStyle.DECO_CABINET_TILE);
            FacilityGeom.face(b[B_CAB_SIDE], x0, x1, z0, z1, head + 1, y, y + h,
              FacilityStyle.DECO_CABINET_TILE);
            FacilityGeom.cap(b[B_CAB_TOP], x0, x1, z0, z1, y + h, FacilityStyle.DECO_CABINET_TILE);
          case _FittingKind.FIT_MACHINE | _FittingKind.FIT_MACHINE_LOW:
            // the same four faces again, and the ONLY kind here where EVERY one of them maps 0..1 —
            // the lid included. It was emitted with `face`/`cap` first, tiling off the world the way
            // the bookcase's flanks do, and came back from the game as a misaligned front and a lid
            // with its corners cut off: all three of these images carry discrete features (a strip of
            // dials, bolt columns down the edges, two grille patches and a gland) and a swatch that
            // only reads whole cannot be shown in part. `localCap` at the unit's own width is a full
            // 0..1 across the lid because this unit is a CUBE, which is what an aspect-locked face on
            // a square image costs and the reason it is one
            FacilityGeom.pane(b[B_MACH_FRONT], x0, x1, z0, z1, dir ^ 1, y, y + h);
            FacilityGeom.pane(b[B_MACH_SIDE], x0, x1, z0, z1, head, y, y + h);
            FacilityGeom.pane(b[B_MACH_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
            localCap(b[B_MACH_TOP], x0, x1, z0, z1, y + h, x1 - x0);
            machLights(leds, x0, x1, z0, z1, y, h, dir, col, row);
          default:
            // the rack: three faces of one cabinet, each on its own surface, and all of them laid
            // from the UNIT'S OWN CORNER rather than off the world — see `localFace`
            localFace(b[B_RACK], x0, x1, z0, z1, dir ^ 1, y, y + h);
            localFace(b[B_RACK_SIDE], x0, x1, z0, z1, head, y, y + h);
            localFace(b[B_RACK_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
            localCap(b[B_RACK_TOP], x0, x1, z0, z1, y + h, FacilityStyle.DECO_RACK_TILE);
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
// the yaw is FREE: a drum is a cylinder, and a bin's mouth may as well look anywhere indoors — where
// the outdoor bins aim theirs at the path, these have no path to aim at
  public static function placeRound(m:Facility, kind:Int, places:Array<Models.PropPlace>):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var y = FacilityGround.surfY(Surf.TILE);
      var r = FacilityStyle.DECO_ROUND_D / 2;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.deco[row][col] - 1 != kind)
              continue;
            var cx = (col + 0.5) * CELL - half;
            var cz = (row + 0.5) * CELL - half;
            var dir = -1;
            for (i in 0...4)
              if (FacilityModel.isWall(m, col + DC[i], row + DR[i]))
                {
                  dir = i;
                  break;
                }
            // off the WALL FACE and not the cell boundary, which is a unit away — the trap the
            // corridor casework and the lab kit both record
            if (dir >= 0)
              {
                var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
                var off = r + FacilityStyle.STAND_GAP;
                cx = (dir == 2 ? s.x1 + off : (dir == 3 ? s.x0 - off : cx));
                cz = (dir == 0 ? s.z1 + off : (dir == 1 ? s.z0 - off : cz));
              }
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
  public static final PROPS:Array<DrumProp> = [
    {
      kind: _FittingKind.FIT_DRUM_STEEL,
      path: RenderConfig.MODELS.facilityDrumSteel,
    },
    {
      kind: _FittingKind.FIT_DRUM_BIO,
      path: RenderConfig.MODELS.facilityDrumBio,
    },
    {
      kind: _FittingKind.FIT_DRUM_RAD,
      path: RenderConfig.MODELS.facilityDrumRad,
    },
  ];

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

// the shelving: two alpha-cut end frames, a bare quad per shelf, and the boxes standing on them.
//
// NO BACK AND NO TOP. Both were in the first build and both were wrong for the same reason — this
// camera pitches 51 degrees DOWN, so a lid is most of what is seen of a unit and it hid every box
// under it, and a back panel behind an open frame is a flat card you cannot see past. What is left
// is what an open steel unit actually is: two frames, some shelves, and whatever is on them.
//
// the shelves have NO THICKNESS either. A slab plus an edge band is four more quads a level to
// state something a 0.12-thick steel shelf does not have at this distance, and the end frame's own
// cross rails already draw the line a shelf sits on
  static function shelf(b:Array<MeshBuf>, x0:Float, x1:Float, z0:Float, z1:Float, y:Float,
      h:Float, dir:Int, head:Int, col:Int, row:Int):Void
    {
      FacilityGeom.pane(b[B_SHELF_SIDE], x0, x1, z0, z1, head, y, y + h);
      FacilityGeom.pane(b[B_SHELF_SIDE], x0, x1, z0, z1, head + 1, y, y + h);
      var lv = FacilityStyle.DECO_SHELF_Y;
      for (i in 0...lv.length)
        {
          var sy = y + h * lv[i];
          // the bay is up to the NEXT rail, or to the top rail for the last one — the frame's own
          // spacing is uneven, so this cannot be one number
          var bay = h * ((i + 1 < lv.length ? lv[i + 1] : FacilityStyle.DECO_SHELF_TOP_Y) - lv[i]);
          FacilityGeom.cap(b[B_SHELF_TOP], x0, x1, z0, z1, sy, FacilityStyle.DECO_SHELF_TILE);
          boxes(b[B_BOX], x0, x1, z0, z1, sy, bay, dir, col, row, i);
        }
    }

// the boxes on one shelf. count, size, offset and TURN are all rolled off the cell and the shelf
// index with render.facility.FacilityModel.mix — the deterministic placement hash every other prop
// family here turns on, and never Math.random(): a unit has to come back the same on every rebuild
// of the same area
  static function boxes(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, room:Float,
      dir:Int, col:Int, row:Int, lvl:Int):Void
    {
      // how much light this bay gets, which the room cannot say — see FacilityStyle.DECO_BOX_AO_LOW.
      // the TOP shelf is the one bay an open frame leaves no lid over, so it takes the full 1.0 and
      // the rest ramp down to _LOW at the floor
      var n1 = FacilityStyle.DECO_SHELF_Y.length - 1;
      var ao = FacilityStyle.DECO_BOX_AO_LOW + (1 - FacilityStyle.DECO_BOX_AO_LOW) *
        (n1 > 0 ? lvl / n1 : 1.0);
      var g = FacilityModel.mix((col * 374761393) ^ (row * 668265263) ^ (lvl * 83492791));
      var n = 1 + g % FacilityStyle.DECO_BOX_MAX;
      // the run along the wall, shared out into one bay per box, and the shelf's own depth
      var a0 = (dir < 2 ? x0 : z0);
      var span = ((dir < 2 ? x1 : z1) - a0) / n;
      var deep = (dir < 2 ? z1 - z0 : x1 - x0);
      // the middle of the shelf ACROSS the wall: a box sits centred in the depth, so the turn below
      // has the same room to swing into on both sides
      var dc = (dir < 2 ? (z0 + z1) : (x0 + x1)) / 2;
      for (i in 0...n)
        {
          var hh = FacilityModel.mix(g ^ (i * 40503));
          // a box is a BOX, in world units, and the bay only caps it
          var bw = Math.min(span * 0.85, FacilityStyle.DECO_BOX_W +
            ((hh % 1000) / 1000) * FacilityStyle.DECO_BOX_W_VAR);
          var bh = Math.min(room * 0.8, FacilityStyle.DECO_BOX_H +
            (((hh >>> 10) % 1000) / 1000) * FacilityStyle.DECO_BOX_H_VAR);
          var yaw = (((hh >>> 4) % 1000) / 1000 - 0.5) * 2 * FacilityStyle.DECO_BOX_YAW;
          // and the DEPTH is what the turn is paid for out of. turning a box about its centre swings
          // its far corner out by hd * cos J + hw * sin J, so the half-depth that still fits inside
          // the shelf is (deep / 2 - hw * sin J) / cos J — the lab trolley's KIT_GAP arithmetic,
          // solved for the box instead of for the gap
          var c = Math.cos(yaw), s = Math.abs(Math.sin(yaw));
          var hd = Math.min(deep * FacilityStyle.DECO_BOX_D / 2, (deep / 2 - bw / 2 * s) / c);
          var ac = a0 + i * span + (span - bw) * (((hh >>> 20) % 1000) / 1000) + bw / 2;
          // and the SAME swing ALONG the wall, which the depth fit above does not cover: a box in
          // the end bay was turning its corner out past the frame's own upright
          var ext = bw / 2 * c + hd * s;
          var lo = a0 + ext, hi = a0 + span * n - ext;
          ac = (lo > hi ? (lo + hi) / 2 : Math.max(lo, Math.min(hi, ac)));
          var cx = (dir < 2 ? ac : dc);
          var cz = (dir < 2 ? dc : ac);
          var hw = (dir < 2 ? bw : 2 * hd) / 2;
          var hdd = (dir < 2 ? 2 * hd : bw) / 2;
          crate(b, {
            cx: cx,
            cz: cz,
            hw: hw,
            hd: hdd,
            y0: y,
            y1: y + bh,
            yaw: yaw,
            ph: ((hh >>> 14) % 1000) / 1000,
            ao: ao,
          });
          // and the shadow it lays on the plate under it, which the box's own vertex shading cannot
          // be: that darkens the box's SIDES down to the plate, and this is the patch of plate the
          // box sits in. render.world.ContactMask does the same job on the floor and cannot reach a
          // shelf two units up — it is one top-down field, so a box up here would darken the tile
          // below the whole unit. emitted from HERE and not from `crate` because the clamp needs the
          // plate's own extent, which is this function's argument
          FacilityDetail.pool({
            cx: cx,
            cz: cz,
            hw: hw,
            hd: hdd,
            yaw: yaw,
            y: y,
            plate: {
              x0: x0,
              x1: x1,
              z0: z0,
              z1: z1,
            },
          });
        }
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
  static function crate(b:MeshBuf, o:FacilityCrateOpts):Void
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
  static function machLights(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, h:Float,
      dir:Int, col:Int, row:Int):Void
    {
      var e = FacilityStyle.DECO_LED_EPS;
      // the plane the strip lies in, a hair proud of the FRONT — the face opposite the wall
      var f = (dir == 0 ? z1 + e : (dir == 1 ? z0 - e : (dir == 2 ? x1 + e : x0 - e)));
      // ACROSS the face from the TEXTURE'S OWN u origin and not from the lower coordinate, the trap
      // `lights` records: FacilityGeom.ends opens u at x1 or z1 on two of the four hands
      var w = FacilityGeom.ends(x0, x1, z0, z1, dir ^ 1);
      var a0 = (dir < 2 ? w[0] : w[1]);
      var a1 = (dir < 2 ? w[2] : w[3]);
      var us = FacilityStyle.DECO_MACH_LED_U;
      var s = Math.abs(a1 - a0) * FacilityStyle.DECO_MACH_LED_SIZE / 2;
      var yc = y + h * FacilityStyle.DECO_MACH_LED_V;
      // and one OFFSET per unit, so two machines in a room are not stepping in lockstep — the clock
      // is shared by identity and the slot phases below are fixed, so this is the only thing that
      // can separate them
      var g = FacilityModel.mix((col * 1103515245) ^ (row * 12345));
      var off = ((g % 1000) / 1000);
      for (i in 0...us.length)
        {
          var ac = a0 + (a1 - a0) * us[i];
          // the light's PLACE in the run, which is what the shader's chase reads its phase as
          var ph = off + i / us.length;
          var hue = (i >= FacilityStyle.DECO_MACH_LED_GREEN_FROM ? 1.0 : 0.0);
          var p0 = (dir < 2 ? [ac - s, yc - s, f] : [f, yc - s, ac - s]);
          var p1 = (dir < 2 ? [ac + s, yc - s, f] : [f, yc - s, ac + s]);
          var p2 = (dir < 2 ? [ac + s, yc + s, f] : [f, yc + s, ac + s]);
          var p3 = (dir < 2 ? [ac - s, yc + s, f] : [f, yc + s, ac - s]);
          // b carries the hue OFFSET BY 2, which is the mode flag as well — see `blink`
          MeshBufTools.quadRGB(b, p0, p1, p2, p3,
            [0, 0, 1, 0, 1, 1, 0, 1], 1.0, ph, 2.0 + hue);
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
  static function solid(scene:Scene, b:MeshBuf, tex:String, both:Bool):Void
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
// AND TWO PATTERNS OFF ONE PROGRAM, which is what the b channel is doing double duty for. A rack's
// ports are independent traffic (a square wave, each light on its own phase); a machine's control
// strip is a SEQUENCER (one dot running the row with a decaying tail). Both live in the same mesh
// and material because a second one is a second draw call, so the mode has to travel per VERTEX —
// and there are only three channels. It rides the hue: b in 0..1 is a RACK burning `mix(A, B, b)`,
// b in 2..3 is a MACHINE burning `mix(A, B, b - 2)`. Nothing else samples this attribute (the
// include that would is the one being replaced) and a varying is not clamped, so a 2 or a 3 reaches
// the fragment stage untouched. Both branches are evaluated and mixed rather than branched on: they
// are a handful of instructions each and this mesh is a few hundred specks.
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
      var inject =
        '  float decoMode = step( 1.5, vColor.b );\n' +
        '  float decoHue = vColor.b - 2.0 * decoMode;\n' +
        '  float decoBlink = 1.0 - decoLedDepth + decoLedDepth *\n' +
        '    step( 0.5, fract( decoLedTime * decoLedRate + vColor.g ) );\n' +
        '  float decoRun = pow( 1.0 -\n' +
        '    fract( decoLedTime * decoLedChase - vColor.g ), decoLedTail );\n' +
        '  diffuseColor.rgb = mix( decoLedA, decoLedB, decoHue ) *\n' +
        '    ( vColor.r * mix( decoBlink, decoRun, decoMode ) );\n';
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
          shader.fragmentShader = 'uniform float decoLedTime;\n' +
            'uniform float decoLedRate;\n' +
            'uniform float decoLedDepth;\n' +
            'uniform float decoLedChase;\n' +
            'uniform float decoLedTail;\n' +
            'uniform vec3 decoLedA;\n' +
            'uniform vec3 decoLedB;\n' +
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

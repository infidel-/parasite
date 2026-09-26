package render.corp;

import Const;
import citygen.CityConfig;
import render.Models;
import render.facility.FacilityDetail;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.world.ContactMask;

// what the tower's own decoration objects became, for __corp()
typedef CorpDecoSet = {
  var silenced:Int;    // decoration sprites this pass turned off
  var cabinets:Int;    // and what stands in their place
  var fridges:Int;
  var vendings:Int;
  var boards:Int;
  var bins:Int;
};

// THE OLD 2D ART COMES OFF THE PLATE.
//
// gen.corp spawns thirty-odd families of `objects.Decoration` — chairs, computers, whiteboards,
// coolers, cabinets, bins, fridges, vending machines, machinery, and two dozen things that belong
// on a worktop. Every one of them is a 64-pixel atlas frame drawn as an upright billboard
// (render.Actors -> render.particles.Sprites), because ObjModels has no corp row and the three
// suppression hooks that exist are all gated on AREA_FACILITY. So a tower built out of new
// geometry and new glbs was standing the 2D game's furniture in the middle of it, and the server
// room in particular had a machinery ICON standing at floor level inside every 2 m cabinet.
//
// THE RULE IS THE ROW AND NOT A TABLE OF FRAMES. The compound needs Const.FACILITY_DECO because
// its decoration rows are shared with the chem-lab set and only some of them became furniture;
// corp owns atlas rows 23-39 outright and every frame in them is a thing this layer now draws or
// deliberately does not draw. One range test beats thirty rows of table that could only ever say
// the same thing.
//
// WHAT REPLACES WHAT, and the three answers are all different:
//
//   * A WORKTOP ITEM is already drawn — render.corp.CorpClutter scatters two PACK64 sheets of mugs,
//     phones, trays, files and kettles over every worktop cell in the building. The sprite was a
//     second, larger, upright copy of the same idea standing in the middle of it. Nothing is
//     emitted for these; the suppression IS the fix.
//   * A CHAIR, A COMPUTER, A PLANT, A COOLER, A PRINTER already has a glb (render.corp.CorpProps).
//     The computer cells are handed over so a workstation stands exactly where the old icon did,
//     which is what "put the new ones in their places" asks for literally.
//   * A CABINET and A WHITEBOARD are CASEWORK — an axis-aligned slab whose
//     read is a material, which docs/3d-models.md's triage sends to emitted quads and not to a glb.
//     They are emitted here, into CorpFurniture's OWN buffers, so the whole family costs ZERO extra
//     draw calls: they wear the desk carcass's three faces, which in a premium office is the truth
//     rather than a saving.
//
// THE FRIDGE AND THE VENDING MACHINE LEFT THIS FAMILY for render.corp.CorpKitchen's glbs: a vending
// machine's read is a LIT GLASS FRONT, which a box in desk laminate never had. The server room's
// MACHINERY is still suppressed with nothing put back: the rack it stood on already draws, and an
// icon standing inside a cabinet is worse than a cabinet with nothing on it.
class CorpDeco
{
  static inline var CELL = CityConfig.CELL;

  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // what a frame is drawn as. NONE is not "unknown" — it is "something else already draws this"
  public static inline var K_NONE = 0;
  public static inline var K_WORK = 1;
  public static inline var K_CABINET = 2;
  public static inline var K_FRIDGE = 3;
  public static inline var K_VENDING = 4;
  public static inline var K_BOARD = 5;
  public static inline var K_BIN = 6;
  // and the three the wall dressings used to draw NOTHING for. gen.corp.CorpRooms.decorateWalls
  // writes an unwalkable floor twin under every one of these, so a cell that draws nothing is a
  // cell the player cannot step on with nothing on it to say why — which is exactly what "corners
  // are impassable even if empty" was looking at. The plant and the cooler have glbs and go to
  // render.corp.CorpProps; the plant room's machinery is a box like the cabinet beside it
  public static inline var K_PLANT = 7;
  public static inline var K_COOLER = 8;
  public static inline var K_MACHINE = 9;
  // and the printer, which has a glb of its own in render.corp.CorpProps. Dealt onto a TABLE tile
  // in the copy room, where the bench under it draws it and this kind is ignored, and onto bare
  // floor in the cubicle farm, where the glb stands
  public static inline var K_PRINTER = 10;
  // and the exec office's furniture, on the four atlas cells rows 23-39 had left empty
  // (Const.CORP_EXEC_CHAIR, _ARMCHAIR, _SOFA, _TABLE_LOW). render.corp.CorpExec stands every one
  public static inline var K_EXEC_CHAIR = 11;
  public static inline var K_ARMCHAIR = 12;
  public static inline var K_SOFA = 13;
  public static inline var K_TABLE_LOW = 14;
  // and the staff kitchen's, which render.corp.CorpKitchen reads on Surf.KITCHEN alone: a dining
  // chair (the task chair's own frames), the sink's tap, and the three appliances gen.corp
  // .CorpKitchen deals onto a counter. The same frames dealt in other rooms stay drawn by nothing
  public static inline var K_CHAIR = 15;
  public static inline var K_TAP = 16;
  public static inline var K_MICROWAVE = 17;
  public static inline var K_KETTLE = 18;
  public static inline var K_COFFEE = 19;

  // the casework, as (width along the wall, depth off it, height). every one is a real piece of
  // office furniture at the compound's own scale, where a unit is half a metre: a 1.5 m credenza,
  // a 1.7 m fridge, a 2.1 m vending machine
  // THE CABINET'S ROW IS PUBLIC AND THE OTHERS ARE NOT, because it is the only one that stopped
  // being geometry: render.corp.CorpProps stands a glb on its cells and sizes the contact footprint
  // off THIS, so a second copy of the three numbers could drift from the model's own.
  //
  // its height was raised 1.30 -> 2.00 to land on the drawer art. corp/archive-drawers draws one
  // full-width drawer across the quadrant and three courses up, so a course is aspect 3.0, and a
  // glb face maps its cell 0..1. At 1.30 the front was aspect 2.31 and two clean courses wanted a
  // partial drawer, a 1.5x stretch or a re-rolled sheet; at 2.00 the modelsheet repeat is exactly
  // 1 x 0.667. 2.00 is a real 1 m filing unit. models-src/corp/case_build.py copies it verbatim
  public static final CASE_CABINET = [3.00, 1.20, 2.00];

  static final CASE:Map<Int, Array<Float>> = [
    K_CABINET => CASE_CABINET,
    K_MACHINE => [1.70, 1.15, 1.90],
  ];
  // and the whiteboard, which is a PANEL on the wall and not a box: sill to head, proud of the slab
  static inline var BOARD_W = 3.20;
  static inline var BOARD_Y0 = 2.20;
  static inline var BOARD_Y1 = 4.60;
  static inline var BOARD_PROUD = 0.08;

// is this corp area's object drawn as geometry (or as nothing) instead of as its atlas sprite?
//
// STATELESS, the contract render.facility.FacilityDoors.draws and FacilityDeco.draws both keep: the
// answer is a property of the object's frame and of the area kind, so render.Actors can ask it
// without a model and without this pass having run
  public static function draws(area:game.AreaGame, o:objects.AreaObject):Bool
    {
      return area != null &&
        area.typeID == AREA_CORP &&
        o.type == 'decoration' &&
        o.imageRow >= 23 &&
        o.imageRow <= 39;
    }

// which of the seven a frame is. the columns come straight off the Const.CORP_* lists, which are
// what the generator deals from
  public static function kindOf(row:Int, col:Int):Int
    {
      return switch (row)
        {
          // CORP_COMPUTERS, the first five of row 23
          case 23: (col < 5 ? K_WORK : K_NONE);
          // CORP_WHITEBOARD, then the cooler and the plant, which have glbs of their own
          case 31: (col < 8 ? K_BOARD : (col < 10 ? K_COOLER : K_PLANT));
          // CORP_TABLE_COFFEE, then CORP_TABLE_PRINTER, then CORP_TABLE_MISC_LARGE
          case 28: (col < 6 ? K_COFFEE : (col < 11 ? K_PRINTER : K_NONE));
          // CORP_CABINET, then CORP_TRASH, then a tap
          case 32: (col < 6 ? K_CABINET : (col < 11 ? K_BIN : K_TAP));
          // CORP_MACHINERY, then CORP_FRIDGE. the machinery in a SERVER room already has a rack
          // standing on its cell (CorpModel.fitOf), and `casework` skips a cell that is already
          // a fitting — everywhere else it is a plant-room unit and needs a box of its own
          case 33: (col < 7 ? K_MACHINE : K_FRIDGE);
          case 34: K_VENDING;
          // CORP_CHAIR, then two taps, then the exec chair
          case 30: (col < 9 ? K_CHAIR : (col < 11 ? K_TAP : K_EXEC_CHAIR));
          // CORP_TABLE_KETTLE, then CORP_TABLE_MICROWAVE
          case 37: (col < 8 ? K_KETTLE : K_MICROWAVE);
          case 25: (col == 10 ? K_ARMCHAIR : (col == 11 ? K_SOFA : K_NONE));
          case 26: (col == 11 ? K_TABLE_LOW : K_NONE);
          default: K_NONE;
        };
    }

// every decoration cell of one kind, in cells
  public static function cells(area:game.AreaGame, kind:Int):Array<{ col:Int, row:Int }>
    {
      var out = [];
      if (area == null)
        return out;
      for (o in area.getObjects())
        if (o.type == 'decoration' &&
            kindOf(o.imageRow, o.imageCol) == kind)
          out.push({ col: o.x, row: o.y });
      return out;
    }

// the casework, emitted into CorpFurniture's own buffers — so it must run while they are open.
//
// A PIECE STANDS AGAINST THE WALL IT WAS SPAWNED BESIDE, and the wall is re-derived rather than
// stored: gen.corp.CorpRooms.decorateWalls only ever puts one of these on a cell that has masonry
// on a hand, so the first hand that answers IS the hand it was dealt against
  public static function casework(m:Facility, area:game.AreaGame, n:CorpDecoSet):Void
    {
      if (area == null)
        return;
      for (o in area.getObjects())
        {
          if (o.type != 'decoration')
            continue;
          var k = kindOf(o.imageRow, o.imageCol);
          if (k != K_CABINET &&
              k != K_FRIDGE &&
              k != K_VENDING &&
              k != K_BOARD &&
              k != K_MACHINE)
            continue;
          // a cell that already carries a fitting draws it and not a second box on top — a server
          // room's machinery stands on the rack CorpModel.fitOf raised there
          if (FacilityModel.inside(m, o.x, o.y) &&
              (m.fit[o.y][o.x] != 0 || m.table[o.y][o.x]))
            continue;
          var dir = back(m, o.x, o.y);
          if (dir < 0)
            continue;
          if (k == K_BOARD)
            {
              board(m, o.x, o.y, dir);
              n.boards++;
              continue;
            }
          // THE CABINET IS NO LONGER A BOX. render.corp.CorpProps stands `corp/case-cabinet` on
          // this cell instead — a carcass with two proud drawers in it — because a credenza drawn
          // as `box` is a slab wearing desk laminate, which is what got reported. It is still
          // COUNTED here so __corp()'s readout means what it always did: CorpProps' own candidate
          // test is this loop's (`m.fit`/`m.table` clear, a masonry hand to back onto), so the two
          // passes see the same cells
          if (k == K_CABINET)
            {
              n.cabinets++;
              continue;
            }
          // AND NEITHER ARE THE FRIDGE AND THE VENDING MACHINE: render.corp.CorpKitchen stands a glb
          // on each, where this emitted a box in the office desk's laminate — reported off a face
          // pick as textures/corp/desk-front.png on a vending machine. Counted here all the same
          if (k == K_FRIDGE)
            {
              n.fridges++;
              continue;
            }
          if (k == K_VENDING)
            {
              n.vendings++;
              continue;
            }
          box(m, o.x, o.y, dir, CASE.get(k));
          n.cabinets++;
        }
    }

// one casework box: a front, two ends and a lid, and NO back and NO bottom — the piece stands
// against masonry and this camera never sees under it (docs/3d-geometry.md)
  static function box(m:Facility, col:Int, row:Int, dir:Int, d:Array<Float>):Void
    {
      var sl = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var w = CityConfig.cellToWorld(col, row);
      var half = d[0] / 2;
      var x0 = (dir < 2 ? w.x - half : (dir == 2 ? sl.x1 : sl.x0 - d[1]));
      var x1 = (dir < 2 ? w.x + half : x0 + d[1]);
      var z0 = (dir < 2 ? (dir == 0 ? sl.z1 : sl.z0 - d[1]) : w.z - half);
      var z1 = (dir < 2 ? z0 + d[1] : w.z + half);
      FacilityGeom.cap(CorpFurniture.buf(CorpStyle.DESK_TOP), x0, x1, z0, z1, d[2],
        CorpStyle.DESK_TILE);
      for (f in 0...4)
        {
          // THE BURIED HAND IS `dir` AND NOT `dir ^ 1`, which is the whole of "desk missing
          // polygons". `dir` points TOWARD the masonry and the box grows AWAY from it — x0/z0
          // above are taken off the wall slab's near face — so the plane at `dir` is the one
          // against the wall and the plane at `dir ^ 1` is the one the player looks at. Skipping
          // `dir ^ 1` left every cabinet, fridge and vending machine in the tower open-fronted
          // (the material is FrontSide, so you see straight through into nothing) and painted the
          // drawer-course art, corp/desk-front.png, on the face nobody can see. `board` five lines
          // down and render.facility.FacilityDetail.halo both already had it the right way round
          if (f == dir)
            continue;
          var isEnd = (f != (dir ^ 1));
          FacilityGeom.face(CorpFurniture.buf(isEnd ? CorpStyle.DESK_SIDE : CorpStyle.DESK_FRONT),
            x0, x1, z0, z1, f, 0, d[2],
            isEnd ? CorpStyle.DESK_TILE : CorpStyle.DESK_FRONT_TILE);
        }
      ContactMask.prop(x0, x1, z0, z1);
      FacilityDetail.stand({
        col: col,
        row: row,
        dir: dir,
        a0: (dir < 2 ? x0 : z0),
        a1: (dir < 2 ? x1 : z1),
        len: 1,
        y: 0.0,
        h: d[2],
      });
    }

// and the whiteboard, hung on the slab's own face the way CorpFurniture hangs a mirror
  static function board(m:Facility, col:Int, row:Int, dir:Int):Void
    {
      var f = FacilityGeom.plane(FacilityGeom.slab(m, col + DC[dir], row + DR[dir]), dir ^ 1,
        BOARD_PROUD);
      var w = CityConfig.cellToWorld(col, row);
      var half = BOARD_W / 2;
      var x0 = (dir < 2 ? w.x - half : f.x0);
      var x1 = (dir < 2 ? w.x + half : f.x1);
      var z0 = (dir < 2 ? f.z0 : w.z - half);
      var z1 = (dir < 2 ? f.z1 : w.z + half);
      FacilityGeom.face(CorpFurniture.buf(CorpStyle.DESK_SIDE), x0, x1, z0, z1, dir ^ 1,
        BOARD_Y0, BOARD_Y1, CorpStyle.DESK_TILE);
    }

// which hand this cell has masonry on, or -1. the same run test CorpProps.wall makes, and for the
// same reason: FacilityGeom.slab insets a face by a unit where the wall line stops, so a piece
// backed onto the END of a wall hangs off it
// which hand a dressed cell's masonry is on — `back` below, public for render.corp.CorpProps,
// which stands the plant and the cooler on exactly these cells
  public static inline function backHandOf(m:Facility, col:Int, row:Int):Int
    return back(m, col, row);

  static function back(m:Facility, col:Int, row:Int):Int
    {
      if (!FacilityModel.inside(m, col, row))
        return -1;
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.isSolidWall(m, c, r))
            continue;
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          if (FacilityGeom.carries(m, c - sc, r - sr) &&
              FacilityGeom.carries(m, c + sc, r + sr))
            return dir;
        }
      return -1;
    }

// the bins, as places for one instanced batch. a bin is ROUND, which is the one shape in this file
// that quads cannot state, so it is the only glb the pass owns.
//
// PUSHED ONTO EVERY MASONRY HAND, so a corner bin stands in its corner. The cell is WALKABLE now
// (gen.corp.CorpRooms.addDecorationExt hands it back), so the actor stands at its centre and the bin
// has to be out of the way — and the face is FacilityGeom.wallFace off the WALL cell's own centre,
// a unit past the cell edge at WALL_T 2. The old offset assumed the edge and stood every bin two
// units out in the room, which is what "put them near the walls" was
  public static function bins(m:Facility, area:game.AreaGame):Array<Models.PropPlace>
    {
      var out = [];
      for (c in cells(area, K_BIN))
        {
          if (!FacilityModel.inside(m, c.col, c.row))
            continue;
          var w = CityConfig.cellToWorld(c.col, c.row);
          var x = w.x;
          var z = w.z;
          // AN ARCHIVE BIN SOUTH OF A RANK stands against the rank's end, whatever walls the cell
          // has: gen.corp.CorpRooms.archive deals those slots, and the rank end is where they were
          // asked for
          if (CorpFurniture.archiveAt(m, c.col, c.row - 1) &&
              !area.isWalkable(c.col, c.row - 1))
            z = CorpFurniture.rankSouth(m, c.col, c.row - 1) + CorpStyle.PROP_GAP +
              CorpStyle.BIN_W / 2;
          else
            for (d in 0...4)
              {
                var wc = c.col + DC[d];
                var wr = c.row + DR[d];
                if (!FacilityModel.isWall(m, wc, wr))
                  continue;
                var off = CELL - FacilityGeom.wallFace(m, wc, wr, d ^ 1) - CorpStyle.BIN_W / 2 -
                  CorpStyle.PROP_GAP;
                x += DC[d] * off;
                z += DR[d] * off;
              }
          out.push({ x: x, z: z, yaw: 0.0 });
          FacilityDetail.ground(m, {
            col: c.col,
            row: c.row,
            len: 1,
            alongX: false,
            rect: {
              x0: x - CorpStyle.BIN_W / 2,
              x1: x + CorpStyle.BIN_W / 2,
              z0: z - CorpStyle.BIN_W / 2,
              z1: z + CorpStyle.BIN_W / 2,
            },
            h: CorpStyle.BIN_H,
          });
        }
      // AND A BIN BESIDE EVERY STANDING COPIER, in its own cell, asked for as "right in the same
      // tile directly adjacent". DRESSING and not a decoration, because a cell holds one object
      // (gen.GenCtx.addDecoration refuses a second) and a bin has no gameplay to lose. Always
      // while the copier's room holds no dealt bin; on COPIER_BIN_PCT once it does, rolled off the
      // cell so a floor comes back the same on every rebuild. Against the copier's own wall and
      // half a copier, the gap and half a bin along it — to whichever side does not meet a wall
      for (c in cells(area, K_PRINTER))
        {
          if (!FacilityModel.inside(m, c.col, c.row) ||
              m.table[c.row][c.col] ||
              m.fit[c.row][c.col] != 0)
            continue;
          var dir = back(m, c.col, c.row);
          if (dir < 0)
            continue;
          if (binned(m, area, c.col, c.row) &&
              FacilityModel.mix((c.col * 374761393) ^ (c.row * 668265263)) % 100 >=
                CorpStyle.COPIER_BIN_PCT)
            continue;
          var w = CityConfig.cellToWorld(c.col, c.row);
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          var side = (FacilityModel.isWall(m, c.col + sc, c.row + sr) ? -1 : 1);
          var along = side * (CorpStyle.PRINTER_W / 2 + CorpStyle.PROP_GAP + CorpStyle.BIN_W / 2);
          var off = CELL - FacilityGeom.wallFace(m, c.col + DC[dir], c.row + DR[dir], dir ^ 1) -
            CorpStyle.BIN_W / 2 - CorpStyle.PROP_GAP;
          var x = w.x + DC[dir] * off + sc * along;
          var z = w.z + DR[dir] * off + sr * along;
          out.push({ x: x, z: z, yaw: 0.0 });
          FacilityDetail.ground(m, {
            col: c.col,
            row: c.row,
            len: 1,
            alongX: false,
            rect: {
              x0: x - CorpStyle.BIN_W / 2,
              x1: x + CorpStyle.BIN_W / 2,
              z0: z - CorpStyle.BIN_W / 2,
              z1: z + CorpStyle.BIN_W / 2,
            },
            h: CorpStyle.BIN_H,
          });
        }
      return out;
    }

// does the room this cell is in hold a dealt bin already? off the model's room rects
  static function binned(m:Facility, area:game.AreaGame, col:Int, row:Int):Bool
    {
      for (r in m.rooms)
        {
          if (col < r.x1 ||
              col > r.x2 ||
              row < r.y1 ||
              row > r.y2)
            continue;
          for (b in cells(area, K_BIN))
            if (b.col >= r.x1 &&
                b.col <= r.x2 &&
                b.row >= r.y1 &&
                b.row <= r.y2)
              return true;
          return false;
        }
      return false;
    }

// how many sprites the suppression above is actually turning off, for the dump
  public static function silenced(area:game.AreaGame):Int
    {
      var n = 0;
      if (area == null)
        return n;
      for (o in area.getObjects())
        if (draws(area, o))
          n++;
      return n;
    }
}

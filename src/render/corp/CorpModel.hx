package render.corp;

import Const;
import game.AreaGame;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.particles.AtlasBox;

// how a saved CORP grid becomes a shell the facility's emitters can build.
//
// IT RETURNS A `Facility` AND THAT IS THE POINT. The record is not one compound's — it is one
// indoor building shell, derived from tiles and objects, and every emitter under render.facility
// takes it and nothing else. So the whole of the corp office's 3D geometry is this file plus an
// art table, rather than a second copy of a 1,400-line quad emitter.
//
// THE FLOOR TILE IS THE ROOM'S ROLE and `_Room.role` is only the refinement. gen.corp writes both,
// but role is a field on generatorInfo that a save made before the block-tree port does not carry,
// where the floor id is in the cell grid of every corp save there has ever been. So the surface
// grid is read first and the role is never consulted here at all.
class CorpModel
{
// build the model from an area's saved cells. `icon` is the atlas content box a bench decoration's
// contact pool is measured off — see FacilityModel.fromArea, which this delegates to
  public static function fromArea(area:AreaGame, ?icon:(Int, Int)->AtlasBox):Facility
    {
      var m = FacilityModel.fromArea(area, icon, CorpStyle.shell());
      loneWindows(m);
      return m;
    }

// a window cell with no window beside it becomes SOLID.
//
// gen.corp writes single-cell openings — the stub at the end of a side corridor, and the tail of a
// run that came out one cell long — and FacilityModel.findWindows is built on "an opening is never
// 1 cell": it picks the run's axis from whichever neighbour is also glass, so a lone cell is read
// as a vertical run of one and then dropped outright when the indoor side is not where it looked.
// The cell stays Wall.WINDOW, so the shell leaves a hole in the masonry with no pane in it.
//
// closing it here rather than teaching findWindows to guess an axis: a one-cell opening has no art
// of its own (FacilityGeom.paneTall knows 2 and 3, because there is one image per run length and
// nothing is ever stretched), so the honest answer until a corp window set is authored is that it
// is not an opening
  static function loneWindows(m:Facility):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW)
              continue;
            if (isWindow(m, col - 1, row) ||
                isWindow(m, col + 1, row) ||
                isWindow(m, col, row - 1) ||
                isWindow(m, col, row + 1))
              continue;
            m.wall[row][col] = Wall.SOLID;
          }
    }

  static inline function isWindow(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) && m.wall[row][col] == Wall.WINDOW;
    }

// the horizontal surface a corp tile id paints.
//
// EVERY ROOM KIND IS ITS OWN SURFACE, because that is what the art is keyed on: the floor and the
// interior wall face looking into it both come off this one value. The unwalkable twin of a floor
// (one tileset row below, gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET) is the cell under a piece of
// furniture and paints the SAME surface — the floor carries on under a filing cabinet.
//
// OUTSIDE THE TOWER IS `NONE`, which is what the 20th storey means: the alley and pavement ids the
// generator leaves round the plate paint no surface at all, so nothing is emitted there and the
// plate stands over a hole. The far street goes in later, in its own group and far below
  public static function surfOf(t:Int):Surf
    {
      if (t == Const.TILE_FLOOR_CARPET ||
          t == Const.TILE_FLOOR_CARPET + 16 ||
          // the lift DOOR cell, which is circulation like the corridor it opens onto
          t == Const.TILE_FLOOR_TILE_CANNOTSEE)
        return CARPET;
      if (t == Const.TILE_FLOOR_WOOD2 ||
          t == Const.TILE_FLOOR_WOOD2 + 16)
        return OPEN;
      if (t == Const.TILE_FLOOR_CUBICLE ||
          t == Const.TILE_FLOOR_CUBICLE + 16)
        return CUBICLE;
      if (t == Const.TILE_FLOOR_CARPET_MEETING ||
          t == Const.TILE_FLOOR_CARPET_MEETING + 16)
        return MEETING;
      if (t == Const.TILE_FLOOR_WOOD1 ||
          t == Const.TILE_FLOOR_WOOD1 + 16)
        return KITCHEN;
      if (t == Const.TILE_FLOOR_MARBLE1 ||
          t == Const.TILE_FLOOR_MARBLE1 + 16)
        return EXEC;
      if (t == Const.TILE_FLOOR_MARBLE2 ||
          t == Const.TILE_FLOOR_MARBLE2 + 16)
        return WASHROOM;
      if (t == Const.TILE_FLOOR_SERVER ||
          t == Const.TILE_FLOOR_SERVER + 16)
        return SERVER;
      if (t == Const.TILE_FLOOR_CONCRETE ||
          t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE)
        return LIFT;
      // every TABLE tile — the desks, the boardroom slab, the kitchen units — resolves to the
      // generic indoor floor, and FacilityModel.themeRooms then spreads its room's own surface
      // over it. A table is a thing standing ON a floor, so the cell still needs one
      if (t >= Const.OFFSET_ROW8)
        return TILE;
      return NONE;
    }

// what a corp tile id blocks. no shutter and no light well: a tower floor has neither
  public static function wallOf(t:Int):Wall
    {
      if (t == Const.TILE_BUILDING)
        return SOLID;
      if (t >= Const.TILE_CORP_WINDOW1 && t <= Const.TILE_CORP_WINDOWV3)
        return WINDOW;
      if (t >= Const.TILE_CORP_INNER_WINDOW1 && t <= Const.TILE_CORP_INNER_WINDOWV3)
        return WINDOW;
      return OPEN;
    }

// a small corp floor for the shader warm: one room of each surface behind one wall ring, with a
// window run and a door, so every material this kind will ever draw has something to emit
  public static function demo():Facility
    {
      var m = FacilityModel.blank(20, 12, CorpStyle.shell());
      for (row in 1...11)
        for (col in 1...19)
          m.surf[row][col] = CARPET;
      // one band of each themed surface, wide enough that the wall faces either side of it look
      // into two different finishes
      var bands = [ Surf.OPEN, Surf.CUBICLE, Surf.MEETING, Surf.KITCHEN,
        Surf.EXEC, Surf.WASHROOM, Surf.SERVER, Surf.LIFT ];
      for (i in 0...bands.length)
        for (row in 2...10)
          m.surf[row][2 + i * 2] = bands[i];
      // the ring, and a 3-cell window run in it so both pane materials compile
      for (col in 0...20)
        {
          m.wall[0][col] = SOLID;
          m.wall[11][col] = SOLID;
        }
      for (row in 0...12)
        {
          m.wall[row][0] = SOLID;
          m.wall[row][19] = SOLID;
        }
      m.wall[0][4] = WINDOW;
      m.wall[0][5] = WINDOW;
      m.wall[0][6] = WINDOW;
      m.wall[0][10] = WINDOW;
      m.wall[0][11] = WINDOW;
      FacilityModel.findStructures(m, false);
      FacilityModel.findWindows(m);
      m.doors.push({
        col: 15,
        row: 0,
        look: render.facility.FacilityModel.Look.GLASS,
        alongX: true,
        inDir: 1,
        front: true,
        structure: 0,
      });
      m.door[0][15] = true;
      return m;
    }
}

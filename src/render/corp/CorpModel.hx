package render.corp;

import Const;
import game.AreaGame;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Look;
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
      washroomWindows(m);
      loneWindows(m);
      // both passes above rewrite m.wall, and FacilityModel.fromArea grouped the runs BEFORE they
      // ran — so the runs are re-derived off the corrected grid rather than patched
      m.windows = [];
      FacilityModel.findWindows(m);
      doorLooks(m);
      wallFits(m);
      return m;
    }

// A RACK ROW NEVER TOUCHES THE ROOM'S EDGE COLUMN, so a rack that does is not one.
//
// gen.corp.CorpRooms.decorateWalls dresses a room's two long walls by writing the ROOM'S OWN
// unwalkable floor twin and standing a decoration on it — and in the server room and the cubicle
// farm that twin is the very id fitOf reads as a rack and as a partition spine (one tile is the
// floor, the surface AND the fitting, which is the whole trick and also this trap). So a corner
// of the server room came out as an isolated cabinet with a 2D machinery sprite inside it and a
// lid over nothing, reported from the game as "this server in the corner is unnecessary".
//
// THE SHAPE SAYS WHICH IS WHICH: `servers` runs its rack rows over x1+1...x2-1 and `cubicle` its
// spines inside the room likewise, where decorateWalls writes at x1 and x2 exactly. So a fitting
// standing in an edge COLUMN was put there by the wall dressing, and what it really is, is the
// decoration on the same cell — which render.corp.CorpDeco already draws.
//
// Here and not in the generator so it reaches every corp save that exists. The washroom is left
// alone: `toilet` lays its basin run along the y1 ROW and its stalls along y2, both of which run
// through the corners decorateCorners dresses, so there the two are not separable by shape — and
// a basin in the corner of a washroom is what a washroom looks like
  static function wallFits(m:Facility):Void
    {
      for (r in m.rooms)
        for (row in r.y1...r.y2 + 1)
          for (col in [r.x1, r.x2])
            {
              if (!FacilityModel.inside(m, col, row))
                continue;
              if (m.fit[row][col] == CorpFurniture.FIT_RACK ||
                  m.fit[row][col] == CorpFurniture.FIT_SPINE)
                m.fit[row][col] = 0;
            }
    }

// WHICH PAINTED PAIR EACH DOOR WEARS, off the rooms it joins.
//
// FacilityModel.lookOf reads the door OBJECT's own shut frame, and gen.corp deals exactly two of
// them — Const.FRAME_DOOR_CORP everywhere and FRAME_DOOR_ELEVATOR at the lift — both of which fall
// through its `return CABINET`. So the whole tower, boardrooms and washrooms and server room
// alike, hung one door.
//
// Derived from the SURFACE either side rather than fixed in the generator, for the reason
// washroomWindows above gives: a frame is a persisted field on a saved object, so a new one would
// only ever reach areas generated after it, where every save already carries the floor grid. A
// door joins two spaces and the ROOM's own surface is the one with an opinion — a corridor is
// CARPET, which asks for nothing, so the scan simply keeps whatever spoke
  static function doorLooks(m:Facility):Void
    {
      for (d in m.doors)
        {
          d.look = Look.CABINET;
          for (dir in 0...4)
            {
              var c = d.col + FacilityGeom.DC[dir];
              var r = d.row + FacilityGeom.DR[dir];
              if (!FacilityModel.isIndoor(m, c, r))
                continue;
              var l = lookOf(m.surf[r][c]);
              if (l != Look.CABINET)
                d.look = l;
            }
        }
    }

// what one surface asks its door to be. CABINET is "no opinion", i.e. the plain office leaf
  static function lookOf(s:Surf):Look
    {
      return switch (s)
        {
          case Surf.WASHROOM: Look.PRIVATE;
          // the lift is its OWN look and not the server room's steel, because the look is what
          // FacilityDoors reads to decide the leaf SLIDES rather than swings
          case Surf.LIFT: Look.LIFT;
          case Surf.SERVER: Look.METAL;
          case Surf.MEETING, Surf.EXEC: Look.GLASS;
          default: Look.CABINET;
        };
    }

// A WASHROOM IS NOT GLAZED, whatever the saved grid says.
//
// gen.corp.CorpBuilding.makeWindows runs BEFORE CorpBlocks.assign deals the room kinds, so it
// cannot know what a room is and glazes every exterior wall run unconditionally — which puts a
// full-height window behind every WC cubicle on an outside wall. Reported from the game, and
// exactly right as a complaint.
//
// FIXED HERE AND NOT IN THE GENERATOR, deliberately: the renderer derives the whole shell from the
// saved grid every load, so demoting it here fixes every corp save that already exists as well as
// every one still to be made. The tile stays what it was written as; a window nobody can see
// through is a wall
  static function washroomWindows(m:Facility):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW)
              continue;
            for (d in 0...4)
              {
                var c = col + FacilityGeom.DC[d];
                var r = row + FacilityGeom.DR[d];
                if (FacilityModel.isIndoor(m, c, r) &&
                    m.surf[r][c] == Surf.WASHROOM)
                  {
                    m.wall[row][col] = Wall.SOLID;
                    break;
                  }
              }
          }
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
          t == Const.TILE_FLOOR_CARPET + 16)
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
          t == Const.TILE_FLOOR_CONCRETE_UNWALKABLE ||
          // AND THE LIFT DOOR CELL, which used to answer CARPET on the grounds that it is
          // circulation like the corridor it opens onto. It is, but ShellTex.wallInto is indexed
          // by the surface a face LOOKS INTO — so every wall face looking at the lift door took
          // CorpStyle's catch-all office board, and the car side of a wall whose other side is the
          // lobby was painted in the corridor's own finish. The doorway's REVEAL is still
          // circulation: FacilityGeom paints that from m.tex.circ and never from this
          t == Const.TILE_FLOOR_TILE_CANNOTSEE)
        return LIFT;
      // every TABLE tile — the desks, the boardroom slab, the kitchen units — resolves to the
      // generic indoor floor, and FacilityModel.themeRooms then spreads its room's own surface
      // over it. A table is a thing standing ON a floor, so the cell still needs one
      if (t >= Const.OFFSET_ROW8)
        return TILE;
      return NONE;
    }

// which piece of furniture a corp tile id stands, as one of CorpFurniture's codes.
//
// THREE IDS AND NOTHING ELSE, and every one of them is a floor tile's UNWALKABLE TWIN (one tileset
// row down, gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET). That is the whole trick the corp generator
// uses to say "something stands here" without a tile of its own, and it is why the surface grid
// cannot answer: a spine cell, a rack cell and a basin cell all paint their room's own floor.
//
// the WORKTOPS are not here — those are ordinary table tiles and `Facility.table` already holds
// them; what separates a desk from a kitchen counter is the room's Surf and not the tile
  public static function fitOf(t:Int):Int
    {
      if (t == Const.TILE_FLOOR_CUBICLE + 16)
        return CorpFurniture.FIT_SPINE;
      if (t == Const.TILE_FLOOR_SERVER + 16)
        return CorpFurniture.FIT_RACK;
      if (t == Const.TILE_FLOOR_MARBLE2 + 16)
        return CorpFurniture.FIT_FIXTURE;
      return 0;
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
      // one of EVERY fitting, because a material with nothing to emit in the warm scene compiles
      // its program on the first real area entry instead. a worktop cell per finish (the finish is
      // the room's Surf, so one on each band is one of each), a three-cell cubicle spine, two rack
      // cells and a washroom pair — one fixture with a neighbour (a basin) and one standing alone
      // (a WC cubicle), which is the contiguity test CorpFurniture runs
      for (i in 0...bands.length)
        m.table[5][2 + i * 2] = true;
      for (col in 6...9)
        m.fit[7][col] = CorpFurniture.FIT_SPINE;
      m.fit[3][12] = CorpFurniture.FIT_RACK;
      m.fit[3][13] = CorpFurniture.FIT_RACK;
      m.fit[8][15] = CorpFurniture.FIT_FIXTURE;
      m.fit[8][16] = CorpFurniture.FIT_FIXTURE;
      m.fit[8][3] = CorpFurniture.FIT_FIXTURE;
      FacilityModel.findStructures(m, false);
      FacilityModel.findWindows(m);
      // ONE DOOR OF EVERY LOOK, because a look is an image: render.facility.FacilityDoors builds a
      // batch per look and they all compile the same program, so what the extra four buy is the
      // 512 sheet DECODED here rather than on the frame the first washroom door comes into view
      for (li in 0...5)
        {
          m.doors.push({
            col: 15 + li,
            row: 0,
            look: li,
            alongX: true,
            inDir: 1,
            front: li == 0,
            structure: 0,
          });
          m.door[0][15 + li] = true;
        }
      return m;
    }
}

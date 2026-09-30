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
// grid is read first and the role is consulted in ONE place, `securityRoom`: a security room lays
// the server room's own floor and there is no free corp floor id left to split it off with, and
// every save that holds a security room also carries its role (the kind came after the field).
class CorpModel
{
// the security room this cell is in, or null. See the header: the one reader of _Room.role
  public static function securityRoom(m:Facility, col:Int, row:Int):_Room
    {
      if (m.surf[row][col] != Surf.SERVER)
        return null;
      for (r in m.rooms)
        if (r.role == gen.corp.CorpTemp.ROLE_SECURITY &&
            col >= r.x1 &&
            col <= r.x2 &&
            row >= r.y1 &&
            row <= r.y2)
          return r;
      return null;
    }

// is this worktop a cell of a security room's console? Seated and manned like an open-plan desk
// (render.corp.CorpProps.desks), on the bench glb (CorpFurniture.deskCell)
  public static function securityDesk(m:Facility, col:Int, row:Int):Bool
    {
      return m.table[row][col] &&
        securityRoom(m, col, row) != null;
    }

// is this the console cell the guard stands in front of? No chair goes there. The same cell
// gen.corp.CorpRooms.securityPost picks, the middle of the room's first row of worktop
  public static function securityPostDesk(m:Facility, col:Int, row:Int):Bool
    {
      var r = securityRoom(m, col, row);
      if (r == null)
        return false;
      for (y in r.y1...r.y2 + 1)
        {
          var run = [];
          for (x in r.x1...r.x2 + 1)
            if (m.table[y][x])
              run.push(x);
          if (run.length > 0)
            return y == row &&
              run[Std.int(run.length / 2)] == col;
        }
      return false;
    }

// build the model from an area's saved cells. `icon` is the atlas content box a bench decoration's
// contact pool is measured off — see FacilityModel.fromArea, which this delegates to
  public static function fromArea(area:AreaGame, ?icon:(Int, Int)->AtlasBox):Facility
    {
      var m = FacilityModel.fromArea(area, icon, CorpStyle.shell());
      washroomWindows(m);
      doorWindows(m);
      runsOfThree(m);
      loneWindows(m);
      // both passes above rewrite m.wall, and FacilityModel.fromArea grouped the runs BEFORE they
      // ran — so the runs are re-derived off the corrected grid rather than patched
      m.windows = [];
      FacilityModel.findWindows(m);
      doorLooks(m);
      wallFits(area, m);
      archiveWalls(area, m);
      return m;
    }

// THE ARCHIVE'S WALL CABINETS ARE A DECORATION ON WALKABLE FLOOR, not a twin: a 1.2-deep cabinet
// sealing a 4.0 cell cost the room its whole wall ring (gen.corp.CorpRooms.archive). So the
// fitting is read off the decoration here — a cabinet on the archive's own walkable floor with
// masonry on a hand, which is what render.corp.CorpFurniture.archives backs a wall run onto
  static function archiveWalls(area:AreaGame, m:Facility):Void
    {
      for (o in area.getObjects())
        {
          if (o.type != 'decoration' ||
              !FacilityModel.inside(m, o.x, o.y) ||
              area.getCellType(o.x, o.y) != Const.TILE_FLOOR_ARCHIVE ||
              CorpDeco.kindOf(o.imageRow, o.imageCol) != CorpDeco.K_CABINET)
            continue;
          for (dir in 0...4)
            if (FacilityModel.isSolidWall(m, o.x + FacilityGeom.DC[dir], o.y + FacilityGeom.DR[dir]))
              m.fit[o.y][o.x] = CorpFurniture.FIT_ARCHIVE;
        }
    }

// PUT THE DEMOTIONS BACK INTO THE GRID, because a window nobody can see through must not be one
// the player can see through either.
//
// the four passes above rewrite `m.wall` and deliberately leave the TILE alone, so an existing
// save gets the corrected shell for free. What that missed is that tiles/Default marks EVERY id in
// tileset rows 12 and 13 see-through — every corp window id is in them — so a cell drawn as solid
// curtain wall blocked no sightline at all: game.AreaGame.isVisible walks the tile grid, and
// render.world.VisionMask.polygon casts against area.canSeeThrough rather than against the `solid`
// predicate it is handed. Reported from the game as a room fully visible through its own wall.
//
// so this is a REPAIR of the saved grid, the same shape as AreaGame.repairGeneratorInfo: run once
// where the model is built for a LIVE area, idempotent (a repaired cell is TILE_BUILDING and no
// longer a window), and it reaches every save rather than only newly generated ones.
// setCellType re-derives the tile's walkable/see-through flags for us
  public static function sealWindows(area:AreaGame, m:Facility):Int
    {
      var n = 0;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.SOLID)
              continue;
            var t = area.getCellType(col, row);
            if (wallOf(t) != Wall.WINDOW)
              continue;
            area.setCellType(col, row, Const.TILE_BUILDING);
            n++;
          }
      if (n > 0)
        area.visRev++;
      return n;
    }

// A RACK ROW NEVER TOUCHES THE ROOM'S EDGE COLUMN, so a rack that does is not one.
//
// gen.corp.CorpRooms.decorateWalls dresses a room's two long walls by writing the ROOM'S OWN
// unwalkable floor twin and standing a decoration on it — and in the server room that twin is the
// very id fitOf reads as a rack (one tile is the floor, the surface AND the fitting, which is the
// whole trick and also this trap). So a corner of the server room came out as an isolated cabinet
// with a 2D machinery sprite inside it and a lid over nothing, reported from the game as "this
// server in the corner is unnecessary".
//
// THE SHAPE SAYS WHICH IS WHICH: `servers` runs its rack rows over x1+1...x2-1, where
// decorateWalls writes at x1 and x2 exactly. So a fitting standing in an edge COLUMN was put there
// by the wall dressing, and what it really is, is the decoration on the same cell — which
// render.corp.CorpDeco already draws.
//
// THE ARCHIVE IS NOT CLEARED ANY MORE, and it used to be for the same reason: its wall dressing
// wrote the archive twin, and clearing it here was what let CorpDeco.casework draw a low credenza
// there instead of nothing. gen.corp.CorpRooms.archive lays a RING of casework on every wall now and
// render.corp.CorpFurniture.archives stands full-height file cabinets on it, so an edge-column
// archive cell is exactly the fitting it says it is.
//
// THE CUBICLE FARM USED TO BE THE OTHER HALF OF THIS and no longer has a dog in it: its partitions
// take no cell and it dresses no wall.
//
// Here and not in the generator so it reaches every corp save that exists. The washroom is left
// alone: `toilet` lays its basin run along the y1 ROW and its stalls along y2, both of which run
// through the corners decorateCorners dresses, so there the two are not separable by shape — and
// a basin in the corner of a washroom is what a washroom looks like
//
// A RACK ON Const.TILE_RACK_HIGH IS NEVER DRESSING: that id is laid only by the server room's ranks
// and the security room's rack column, which runs down its east wall ON PURPOSE, so only the
// see-through twin is demoted
  static function wallFits(area:AreaGame, m:Facility):Void
    {
      for (r in m.rooms)
        for (row in r.y1...r.y2 + 1)
          for (col in [r.x1, r.x2])
            {
              if (!FacilityModel.inside(m, col, row))
                continue;
              if (m.fit[row][col] == CorpFurniture.FIT_RACK &&
                  area.getCellType(col, row) != Const.TILE_RACK_HIGH &&
                  area.getCellType(col, row) != Const.TILE_CORP_WALL_RACK)
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
          case Surf.MEETING, Surf.EXEC, Surf.RECEPTION: Look.GLASS;
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

// A PANE NEVER TOUCHES A DOORWAY.
//
// gen.corp.CorpBuilding.makeWindows breaks its run at a door and then deliberately glazes the cell
// right before it — `cells[x - delta.x][y - delta.y] = windowTiles[2]`, the closing frame — so
// every opening on a glazed wall has curtain wall butted straight onto its jamb. Reported from the
// game with the two faces beside each other: a window-2bay at x 1.367 and the door cell's own
// floor at 5.333, one cell apart.
//
// ALONG THE WALL LINE AND NOT ALL FOUR HANDS: a door in the perpendicular wall of the room behind
// is not adjacent to this pane in any sense a player can see, and demoting on it would strip
// glazing for a door round the corner.
//
// HERE AND NOT IN THE GENERATOR, washroomWindows' reason exactly: the shell is derived from the
// saved grid on every load, so a correction here reaches every corp save that already exists
// where a generator change reaches none of them
  static function doorWindows(m: Facility):Void
    {
      var hit = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW)
              continue;
            // the run's axis is the hand its own glazing carries on down, the same test
            // FacilityModel.findWindows picks it with
            var alongX = (isWindow(m, col - 1, row) || isWindow(m, col + 1, row));
            var dc = (alongX ? 1 : 0);
            var dr = (alongX ? 0 : 1);
            if (FacilityModel.isDoor(m, col - dc, row - dr) ||
                FacilityModel.isDoor(m, col + dc, row + dr))
              hit.push({ col: col, row: row });
          }
      for (c in hit)
        m.wall[c.row][c.col] = Wall.SOLID;
    }

// A RUN IS A WHOLE NUMBER OF THREE-BAY PANES, and what is left over is masonry.
//
// there is one image per run length and nothing is ever stretched, so FacilityModel.findWindows
// chops a corp run greedily into 3s with 2s to finish — and a 2-cell opening in a wall that is
// four or five cells long reads as half a wall rather than as a window. Asked for as exactly that.
// So the run is trimmed to floor(len / 3) * 3 first and the splitter then only ever sees a
// multiple of three: the two-bay art goes unused on a tower and stays for the compound.
//
// CENTRED, so the leftover is shared between the two ends and a run keeps a pier at each. And
// COLLECTED BEFORE IT IS APPLIED, because demoting a cell mid-scan makes the next cell of the same
// run look like the head of a new one and it would be trimmed twice
  static function runsOfThree(m: Facility):Void
    {
      var runs = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.wall[row][col] != Wall.WINDOW)
              continue;
            var alongX = (isWindow(m, col - 1, row) || isWindow(m, col + 1, row));
            if (alongX && isWindow(m, col - 1, row))
              continue;
            if (!alongX && isWindow(m, col, row - 1))
              continue;
            var len = 1;
            while (isWindow(m, col + (alongX ? len : 0), row + (alongX ? 0 : len)))
              len++;
            runs.push({ col: col, row: row, alongX: alongX, len: len });
          }
      for (r in runs)
        {
          var keep = Std.int(r.len / 3) * 3;
          var lead = Std.int((r.len - keep) / 2);
          for (i in 0...r.len)
            {
              if (i >= lead &&
                  i < lead + keep)
                continue;
              m.wall[r.row + (r.alongX ? 0 : i)][r.col + (r.alongX ? i : 0)] = Wall.SOLID;
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
          t == Const.TILE_FLOOR_MARBLE1 + 16 ||
          t == Const.TILE_FLOOR_EXEC_RUG ||
          t == Const.TILE_FLOOR_EXEC_RUG + 16)
        return EXEC;
      // AND ITS COUNTER, which stands in the wall line on the reception's own floor: a fitting
      // (see `fitOf`) and not a wall, so the corner posts either side end in faces of their own
      if (t == Const.TILE_FLOOR_RECEPTION ||
          t == Const.TILE_FLOOR_RECEPTION + 16 ||
          t == Const.TILE_CORP_RECEPTION_COUNTER)
        return RECEPTION;
      if (t == Const.TILE_FLOOR_MARBLE2 ||
          t == Const.TILE_FLOOR_MARBLE2 + 16)
        return WASHROOM;
      // AND THE ARCHIVE ANSWERS THE SERVER ROOM'S OWN SURFACE, which is the whole economy of its
      // floor id: no new Surf means no row in ShellTex's `floor` or `wallInto`, no new label, no
      // new material and no new draw call. The two rooms are told apart by their FITTINGS -- see
      // `fitOf` -- and not by their finish, because a records room and a computer room really do
      // both stand on sealed concrete
      if (t == Const.TILE_FLOOR_SERVER ||
          t == Const.TILE_FLOOR_SERVER + 16 ||
          t == Const.TILE_FLOOR_ARCHIVE ||
          t == Const.TILE_FLOOR_ARCHIVE + 16 ||
          t == Const.TILE_ARCHIVE_HIGH ||
          t == Const.TILE_RACK_HIGH ||
          t == Const.TILE_CORP_WALL_RACK ||
          t == Const.TILE_CORP_LOCKER)
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
// SEVEN IDS AND NOTHING ELSE, and all but the reception counter, the locker and the sight-blocking
// ranks are a floor tile's UNWALKABLE TWIN (one tileset row down,
// gen.corp.CorpTemp.UNWALKABLE_TILE_OFFSET). That is the whole trick the corp generator
// uses to say "something stands here" without a tile of its own, and it is why the surface grid
// cannot answer: a spine cell, a rack cell, a basin cell and an archive rank cell all paint their
// room's own floor.
//
// the WORKTOPS are not here — those are ordinary table tiles and `Facility.table` already holds
// them; what separates a desk from a kitchen counter is the room's Surf and not the tile
  public static function fitOf(t:Int):Int
    {
      // TILE_FLOOR_CUBICLE's own twin answers NOTHING. It used to answer a partition spine, and a
      // cubicle farm has none: the panels stand on cell BOUNDARIES now. Saves still carry the id —
      // the old solo office dressed its corners with it — and a corner is a cell with a decoration
      // on it, which is exactly what a fitting of 0 leaves CorpDeco to draw
      if (t == Const.TILE_FLOOR_SERVER + 16 ||
          t == Const.TILE_RACK_HIGH ||
          t == Const.TILE_CORP_WALL_RACK)
        return CorpFurniture.FIT_RACK;
      if (t == Const.TILE_FLOOR_MARBLE2 + 16)
        return CorpFurniture.FIT_FIXTURE;
      // AND THE ARCHIVE'S OWN TWIN, which is the whole reason Const.TILE_FLOOR_ARCHIVE exists: its
      // floor and its walls answer the server room's Surf (see `surfOf`) and only this tells the two
      // rooms apart. Before the id was split the archive wrote TILE_FLOOR_SERVER + 16 and a paper
      // records room built steel server cabinets with blinking LEDs and cable drapes over them
      if (t == Const.TILE_FLOOR_ARCHIVE + 16)
        return CorpFurniture.FIT_ARCHIVE;
      // and its full-height rank, which blocks sight (Const.TILE_ARCHIVE_HIGH) and so is the
      // generator's word on which family stands there: the arch-shelf
      if (t == Const.TILE_ARCHIVE_HIGH)
        return CorpFurniture.FIT_ARCHIVE_HIGH;
      // and the reception counter, which is a tile of its own and not a twin: it stands where a
      // wall stood, on no room's floor, so there was no floor id to take a twin of
      if (t == Const.TILE_CORP_RECEPTION_COUNTER)
        return CorpFurniture.FIT_COUNTER;
      // and a security room's locker, a tile of its own for the counter's reason: its room's floor
      // twin is already the rack
      if (t == Const.TILE_CORP_LOCKER)
        return CorpFurniture.FIT_LOCKER;
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
        Surf.EXEC, Surf.WASHROOM, Surf.SERVER, Surf.LIFT, Surf.RECEPTION ];
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
      // and a SECOND cubicle worktop under the first, so the pair is back to back: `divider`
      // emits a panel on every boundary a pod owns, and only an adjacent twin exercises the BACK
      // one. The cubicle band is column 4 — bands[1] at 2 + 1 * 2
      m.table[6][4] = true;
      // and a second MEETING cell, so the boardroom band is a SLAB and not a lone desk: a lone
      // table is a desk glb and emits nothing, and the slab's top is its own PHONG program
      // (CorpFurniture.glossy), which would otherwise compile on first sight of a boardroom. The
      // meeting band is column 6 — bands[2] at 2 + 2 * 2
      m.table[6][6] = true;
      m.fit[3][12] = CorpFurniture.FIT_RACK;
      m.fit[3][13] = CorpFurniture.FIT_RACK;
      m.fit[8][15] = CorpFurniture.FIT_FIXTURE;
      m.fit[8][16] = CorpFurniture.FIT_FIXTURE;
      m.fit[8][3] = CorpFurniture.FIT_FIXTURE;
      // AND TWO ADJACENT ARCHIVE CELLS ON EACH OF THREE ROWS, because the family is dealt off the
      // ROW (CorpFurniture.archive) and each one is its own glb with its own material — a family
      // with nothing here compiles its program on the frame the first archive comes into view. The
      // rows are not arbitrary and they MOVED when the racking became a third entry: with
      // CorpFurniture.ARCH.length 3, FacilityModel.mix(row * 668265263) % 3 is 0 at row 1, 2 at
      // row 4 and 1 at row 6, so between them the three cover every entry. Rows 4 and 9 both
      // answer 2 under the new modulus, which is why the old pair is not simply extended.
      // ADJACENT because `rect` insets a hand only where the rank really stops, so a lone cell
      // never exercises the uninset case, and NON-ADJACENT ROWS because a real rank sits
      // RACK_PITCH 2 apart and the aisle search wants a clear hand
      m.fit[1][12] = CorpFurniture.FIT_ARCHIVE;
      m.fit[1][13] = CorpFurniture.FIT_ARCHIVE;
      m.fit[4][12] = CorpFurniture.FIT_ARCHIVE;
      m.fit[4][13] = CorpFurniture.FIT_ARCHIVE;
      m.fit[6][12] = CorpFurniture.FIT_ARCHIVE;
      m.fit[6][13] = CorpFurniture.FIT_ARCHIVE;
      // and a reception counter on the reception band (column 18), for its two marbles and the
      // top's PHONG program
      m.fit[10][1] = CorpFurniture.FIT_LOCKER;
      m.fit[8][18] = CorpFurniture.FIT_COUNTER;
      m.fit[9][18] = CorpFurniture.FIT_COUNTER;
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

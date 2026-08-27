package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.facility.FacilityModel.Wall;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// what one structure's roof fades. ONLY the roof: the walls used to fade with it, and a wall face
// was picked for that by its NORMAL, which cannot answer the question it was being asked. see the
// header of render.facility.FacilityArea.ease
typedef Shell = {
  roof:Array<Mesh>,
};

// an axis-aligned footprint in world units, used for both a wall cell's slab and its roof band
typedef Rect = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
};

// one floor strip a slab leaves uncovered inside its own cell, plus the cell whose surface it
// continues. half-thickness walls do not fill their cell, so the remainder is floor — and it is the
// NEIGHBOUR's floor, because the strip is the last unit of the room (or of the car park) and not a
// surface of its own
typedef Strip = {
  x0:Float,
  x1:Float,
  z0:Float,
  z1:Float,
  col:Int,
  row:Int,
};

// one corner square inside a wall cell's bounding slab that its RUNS do not fill. a Strip with the
// two directions the wall line carries into, because the same square is three things at once: the
// diagonal room's floor, its ceiling, and two standing faces of masonry looking back at it
typedef Notch = {
  > Strip,
  dx:Int,   // 2 = west, 3 = east: the horizontal run's direction, and the way one face looks
  dz:Int,   // 0 = north, 1 = south: the vertical run's, and the way the other looks
};

// the static shell of every facility structure: indoor floors, walls, window openings and the roof,
// built from the saved cell grid. one merged mesh per (structure, surface) — a structure is the unit
// because the roof fade is per building, so a mesh may never span two of them.
//
// nothing here is a citygen Building, so render.Occlusion never runs on a facility: the shell fades
// on the player being INSIDE it rather than on blocking a sightline, which is a different question
// with a different answer (see FacilityArea.reveal)
class FacilityGeom
{
  static inline var CELL = CityConfig.CELL;

  // cell offsets of the neighbour each wall face looks at. 0 = north (-z), 1 = south (+z),
  // 2 = west (-x), 3 = east (+x) — the same order render.sewer.SewerGeom winds
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// build every structure's shell, and hand back what fades
  public static function build(scene:Scene, m:Facility):Array<Shell>
    {
      // the vertical band a window opening occupies on its own run's cells, so the wall emitter can
      // leave a hole rather than paint over the pane. keyed per cell because a face is emitted per
      // cell while a pane is emitted per RUN
      var sill = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      var head = [for (_ in 0...m.h) [for (_ in 0...m.w) -1.0]];
      var doorAt = [for (_ in 0...m.h) [for (_ in 0...m.w) -1]];
      for (i in 0...m.doors.length)
        doorAt[m.doors[i].row][m.doors[i].col] = i;
      for (w in m.windows)
        {
          var wide = w.len * CELL;
          var tall = wide / FacilityStyle.WINDOW_ASPECT;
          var lo = (FacilityStyle.WALL_H - tall) / 2;
          if (lo < 0)
            lo = 0;
          var hi = lo + tall;
          if (hi > FacilityStyle.WALL_H)
            hi = FacilityStyle.WALL_H;
          for (i in 0...w.len)
            {
              var c = w.col + (w.alongX ? i : 0);
              var r = w.row + (w.alongX ? 0 : i);
              sill[r][c] = lo;
              head[r][c] = hi;
            }
        }

      var g:FacilityShellOpts = {
        sill: sill,
        head: head,
        doorAt: doorAt,
      };
      var out = [];
      for (si in 0...m.structures.length)
        out.push(structure(scene, m, si, g));
      return out;
    }

// does the wall LINE carry on through this cell?
//
// a wall does, and so does a DOOR cell. that second half is not a nicety: a doorway is a hole IN
// the line, not the end of it, and reading it as an end pulls both flanking slabs back by the
// inset and opens a 4-unit opening out to 6
  public static inline function carries(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.isWall(m, col, row) || FacilityModel.isDoor(m, col, row);
    }

// how thick a cell's masonry is: HALF a cell for solid wall and a QUARTER for glazing
  public static inline function thick(m:Facility, col:Int, row:Int):Float
    {
      return FacilityModel.inside(m, col, row) && m.wall[row][col] == Wall.WINDOW ?
        FacilityStyle.GLASS_T : FacilityStyle.WALL_T;
    }

// the BOUNDING BOX of a wall cell's masonry, in world units — reaching the cell boundary only on the
// sides where the wall line carries on, and inset by half the leftover elsewhere. two things fall
// out of that one rule and neither needs a case of its own:
//   - a straight run comes out 2 units thick, so a doorway is a 2-unit reveal and not a 4-unit tunnel
//   - a window slab sits strictly INSIDE its neighbour's cross-section, so the neighbour's own butt
//     cap is the jamb reveal and the hole that used to be there closes for free
// also correct for a DOOR cell, which is not a wall: its wall-line neighbours carry, so it comes
// back as exactly the lintel planes.
//
// it is the BOX and not the masonry. where the line turns or branches, the runs through the cell
// form an L, a T or a cross and the box is strictly bigger than their union — see notches()
  public static function slab(m:Facility, col:Int, row:Int):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = (CELL - thick(m, col, row)) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// the corner squares a cell's slab box holds that its masonry does not: one per PAIR of adjacent
// directions the wall line carries into.
//
// a wall cell is the union of the RUNS through it and never their bounding box. a corner is an L of
// two 2-thick runs and the box is a 3x3 pier — the extra 1x1 sits in the angle between them, poking
// into the room past both wall lines, which is the full-cell wall this phase exists to have removed.
// a T leaves two of these and a crossing four, so it is not a corner case in either sense.
//
// the square belongs to the DIAGONAL cell: it is the last unit of that room's corner, and it takes
// that room's floor, its fading ceiling and its paint, exactly as strips() hands a run's leftover to
// the neighbour beside it
  public static function notches(m:Facility, col:Int, row:Int):Array<Notch>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = (CELL - thick(m, col, row)) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      var out = [];
      for (dz in 0...2)
        for (k in 0...2)
          {
            var dx = 2 + k;
            if (!carries(m, col + DC[dz], row + DR[dz]) ||
                !carries(m, col + DC[dx], row + DR[dx]))
              continue;
            var nx = (dx == 2 ? x0 : x0 + CELL - e);
            var nz = (dz == 0 ? z0 : z0 + CELL - e);
            out.push({
              x0: nx,
              x1: nx + e,
              z0: nz,
              z1: nz + e,
              dx: dx,
              dz: dz,
              col: col + DC[dx],
              row: row + DR[dz],
            });
          }
      return out;
    }

// the floor strips a cell's slab leaves uncovered — the cell rect minus the slab rect, decomposed
// so nothing overlaps: north and south span the full cell width and own the corners, west and east
// take what is left. a side whose wall line carries on is degenerate and never appears
  public static function strips(m:Facility, col:Int, row:Int):Array<Strip>
    {
      return stripsOf(m, col, row, slab(m, col, row));
    }

// and the same decomposition the FLOOR takes, which differs at exactly one kind of cell: a DOORWAY.
//
// a door cell's slab is its LINTEL — masonry above head height with nothing under it — so the floor
// there is not the door cell's own surface but the two spaces the opening joins, meeting at the wall
// line. an exterior door had 2 units of corridor lino laid out past the building line; it takes
// pavement now, off the same neighbour rule every other strip uses. collapsing the slab to the wall
// line and re-running the same decomposition IS the two halves, so there is no second rule
  public static function floorStrips(m:Facility, col:Int, row:Int):Array<Strip>
    {
      if (!FacilityModel.isDoor(m, col, row))
        return strips(m, col, row);
      var half = (CityConfig.GRID * CELL) / 2;
      var s = slab(m, col, row);
      var c = (carries(m, col - 1, row) ? row : col) * CELL - half + CELL / 2;
      return stripsOf(m, col, row, carries(m, col - 1, row) ?
        {
          x0: s.x0,
          x1: s.x1,
          z0: c,
          z1: c,
        } :
        {
          x0: c,
          x1: c,
          z0: s.z0,
          z1: s.z1,
        });
    }

// the cell rect minus `s`, in up to four rects plus the corner squares
  static function stripsOf(m:Facility, col:Int, row:Int, s:Rect):Array<Strip>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var x0 = col * CELL - half, x1 = x0 + CELL;
      var z0 = row * CELL - half, z1 = z0 + CELL;
      var out = [];
      function add(ax0:Float, ax1:Float, az0:Float, az1:Float, nc:Int, nr:Int):Void
        {
          if (ax1 - ax0 < 0.01 ||
              az1 - az0 < 0.01 ||
              !FacilityModel.inside(m, nc, nr) ||
              m.surf[nr][nc] == Surf.NONE)
            return;
          out.push({
            x0: ax0,
            x1: ax1,
            z0: az0,
            z1: az1,
            col: nc,
            row: nr,
          });
        }
      add(x0, x1, z0, s.z0, col, row - 1);
      add(x0, x1, s.z1, z1, col, row + 1);
      add(x0, s.x0, s.z0, s.z1, col - 1, row);
      add(s.x1, x1, s.z0, s.z1, col + 1, row);
      // and the corner squares INSIDE the box, where the wall line turns or branches
      for (n in notches(m, col, row))
        add(n.x0, n.x1, n.z0, n.z1, n.col, n.row);
      return out;
    }

// the cell a butt cap looks into.
//
// it is DIAGONAL from the cap's own cell: one step along the wall line into the neighbour it butts
// against, then one step off the line toward the side the excess sits on. reading the neighbour
// itself instead gets a window jamb right and a corner pier wrong, because a corner's shoulder looks
// past the run it meets and into the room behind it
  static inline function diagCol(col:Int, dir:Int, side:Int):Int
    {
      return col + DC[dir] + (dir < 2 ? side : 0);
    }

  static inline function diagRow(row:Int, dir:Int, side:Int):Int
    {
      return row + DR[dir] + (dir < 2 ? 0 : side);
    }

// one structure: its floors, its walls, its window panes, its door lintels and its roof
  static function structure(scene:Scene, m:Facility, si:Int, g:FacilityShellOpts):Shell
    {
      var st = m.structures[si];
      var half = (CityConfig.GRID * CELL) / 2;
      // floors, one buffer per surface. a hangar rolls no lab tile and a lab building no concrete,
      // so most of these come back empty and emit no mesh at all
      var fTile = MeshBufTools.make();
      var fLino = MeshBufTools.make();
      var fConcrete = MeshBufTools.make();
      // walls. NOT split by facing any more — see the Shell header. the two INTERIOR buffers are
      // split by the SPACE a face looks into instead: a corridor is painted board and a lab room is
      // tiled, and they are 218 faces against 538 in a generated area, so the corridor is a real
      // third of what the player sees indoors rather than a detail
      var wOut = MeshBufTools.make();
      var wRoom = MeshBufTools.make();
      var wCorr = MeshBufTools.make();
      // the hangar's roll-up shutter strips. their own buffer because they take their own texture:
      // painted in plain cladding they were a door you could not see
      var shut = MeshBufTools.make();
      // the roof, split by whether it is over floor (fades) or over the wall ring (never does). the
      // rim is what keeps the building's outline on screen once you are inside it
      var roof = MeshBufTools.make();
      var rim = MeshBufTools.make();
      // window panes, and the aluminium capping that tops a run and closes its reveal
      var panes = MeshBufTools.make();
      var head = MeshBufTools.make();
      // which wall buffer a face looking into (c,r) belongs in. the hangar wears its cladding on
      // both sides, so it never reaches the interior pair; a corridor is Surf.LINO, the surface the
      // generator floors every corridor and every door cell with, so the split needs no
      // generatorInfo and works on a saved grid
      function look(c:Int, r:Int):MeshBuf
        {
          if (st.hangar || !FacilityModel.isIndoor(m, c, r))
            return wOut;
          return m.surf[r][c] == Surf.LINO ? wCorr : wRoom;
        }

      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            var di = g.doorAt[row][col];
            // a wall and a doorway both fill only PART of their cell, and what the slab leaves is
            // the neighbour's cell reaching into this one: it takes the neighbour's floor, and the
            // neighbour's ceiling with it. the ceiling has to be the FADING roof and not the rim, or
            // the ledge rimRect's header measures comes straight back in a second place. the outdoor
            // half of the same strips is emitted by render.facility.FacilityGround, which is where
            // the ground buffers live
            if (carries(m, col, row))
              {
                // the CEILING follows the masonry and the FLOOR does not, and they part company at a
                // doorway: the lintel's own top is the rim, so the fading roof takes only what the
                // slab leaves, while under it there is no masonry at all and the floor runs right
                // through (see floorStrips). identical at every other cell
                for (sp in strips(m, col, row))
                  if (FacilityModel.isIndoor(m, sp.col, sp.row))
                    cap(roof, sp.x0, sp.x1, sp.z0, sp.z1, FacilityStyle.ROOF_Y,
                      FacilityStyle.ROOF_TILE);
                for (sp in floorStrips(m, col, row))
                  if (FacilityModel.isIndoor(m, sp.col, sp.row))
                    cap(floorBuf(m, sp.col, sp.row, fTile, fLino, fConcrete),
                      sp.x0, sp.x1, sp.z0, sp.z1, 0.0, FacilityStyle.FLOOR_TILE_SZ);
                // a corner square is floor and ceiling like any other strip — the loop above has
                // just laid both — and the two runs it sits in the angle of stand at its edges. one
                // face each, looking the way that run's line carries, into the room the square is a
                // corner of
                for (n in notches(m, col, row))
                  {
                    var b = look(n.col, n.row);
                    butt(b, false, n.dx == 3 ? n.x0 : n.x1, n.z0, n.z1, n.dx);
                    butt(b, true, n.dz == 1 ? n.z0 : n.z1, n.x0, n.x1, n.dz);
                  }
              }
            if (FacilityModel.isWall(m, col, row))
              {
                var s = slab(m, col, row);
                var e = (CELL - thick(m, col, row)) / 2;
                var glazed = (m.wall[row][col] == Wall.WINDOW);
                var shutter = (m.wall[row][col] == Wall.SHUTTER);
                capTop(rim, head, m, col, row, glazed);
                for (dir in 0...4)
                  {
                    var nc = col + DC[dir];
                    var nr = row + DR[dir];
                    if (carries(m, nc, nr))
                      {
                        // the line carries on, so the two runs meet in the cell boundary plane and
                        // the only thing that can be exposed there is a difference in THICKNESS:
                        // glazing sits strictly inside the solid wall that bounds its run, and the
                        // wall's excess either side is the run's JAMB REVEAL.
                        //
                        // the slabs' own extents used to be compared instead, and that answered a
                        // different question: at a corner the box reaches the boundary on the side
                        // the OTHER run leaves through, so the difference read as an exposed end and
                        // capped a shoulder that notches() has now taken away
                        var en = (CELL - thick(m, nc, nr)) / 2;
                        if (en < e + 0.005)
                          continue;
                        var flat = (dir < 2);
                        var pl = flat ? (dir == 0 ? s.z0 : s.z1) : (dir == 2 ? s.x0 : s.x1);
                        var p0 = (flat ? col : row) * CELL - half;
                        butt(look(diagCol(col, dir, -1), diagRow(row, dir, -1)),
                          flat, pl, p0 + e, p0 + en, dir);
                        butt(look(diagCol(col, dir, 1), diagRow(row, dir, 1)),
                          flat, pl, p0 + CELL - en, p0 + CELL - e, dir);
                        continue;
                      }
                    // the shutter is chosen off THIS cell rather than off the neighbour, unlike
                    // `look` beside it: a roll-up door reads as a door from both sides
                    var b = shutter ? shut : look(nc, nr);
                    var t = shutter ? FacilityStyle.SHUTTER_TILE : FacilityStyle.WALL_TILE;
                    if (g.sill[row][col] < 0)
                      {
                        face(b, s.x0, s.x1, s.z0, s.z1, dir, 0.0, FacilityStyle.WALL_H, t);
                        continue;
                      }
                    // a window run: leave the opening and carry the wall above and below it
                    face(b, s.x0, s.x1, s.z0, s.z1, dir, 0.0, g.sill[row][col], t);
                    face(b, s.x0, s.x1, s.z0, s.z1, dir, g.head[row][col], FacilityStyle.WALL_H, t);
                  }
                continue;
              }
            // a door cell carries FLOOR and no wall — the generator finalises one to plain corridor
            // lino — so without this the building has a hole in it at every doorway. the head closes
            // BOTH faces of the reveal, and the reveal is now WALL_T deep rather than a whole cell
            if (di >= 0)
              {
                var s = slab(m, col, row);
                // above DOOR_H the opening is masonry like any other wall, so its roof belongs to
                // the RIM. left in the fading roof with the rest of the cell — which is where it was
                // — all 30 doorways took their piece of the wall-top ring away with the ceiling, and
                // the building read as a ring with a notch cut out of it at every door. the full
                // cell was wrong in the other direction too: at the 7 exterior doors it hung 28
                // square units of roof, and the same again of corridor lino, out over the pavement
                capTop(rim, head, m, col, row, false);
                // the reveal — soffit and both jambs — is painted as CORRIDOR whichever way the
                // opening faces. it used to take whichever of the two flanking spaces the loop below
                // happened to read first, so an interior door was painted in the room's tile half
                // the time and an exterior one in the outside cladding. a doorway is a piece of the
                // circulation and not of either space it joins, which is the same reason the
                // generator floors every door cell in corridor lino
                var soffit = (st.hangar ? wOut : wCorr);
                for (k in 0...2)
                  {
                    var dir = (m.doors[di].alongX ? k : 2 + k);
                    face(look(col + DC[dir], row + DR[dir]), s.x0, s.x1, s.z0, s.z1, dir,
                      FacilityStyle.DOOR_H, FacilityStyle.WALL_H, FacilityStyle.WALL_TILE);
                  }
                // and the head from UNDERNEATH. the two faces above sit on the slab's own planes
                // while the leaves hang between them, so without this the reveal over a door is open
                // to the sky. verified before adding, by putting the free cam on the floor and
                // looking up: a black void over every doorway. the game camera pitches DOWN 51
                // degrees and never sees it, which is exactly why it would have shipped
                capDown(soffit, s.x0, s.x1, s.z0, s.z1, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
                // and the two JAMBS, the opening's side reveals, floor to lintel.
                //
                // NOTHING else emits these. the flanking wall cell sees `carries` on this cell and
                // takes the butt-cap branch, where the two cross-sections are identical — which is
                // true of the MASONRY and false of the hole underneath it, so the reveal came out
                // as two open slots you could see straight through. each jamb sits in a cell
                // boundary plane looking INTO the cell, i.e. wound the opposite way from a wall
                // face at the same place, which is what makes it `face` with one axis collapsed
                jamb(soffit, m.doors[di].alongX, s);
                continue;
              }
            cap(roof, x0, x1, z0, z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
            cap(floorBuf(m, col, row, fTile, fLino, fConcrete),
              x0, x1, z0, z1, 0.0, FacilityStyle.FLOOR_TILE_SZ);
          }

      // one pane per RUN and not per cell, so the art's three panes span the whole opening exactly
      // once. both faces get one: a window read only from outside would vanish the moment the roof
      // faded and the player was standing next to it
      for (w in m.windows)
        {
          if (w.structure != si)
            continue;
          var wide = w.len * CELL;
          var tall = wide / FacilityStyle.WINDOW_ASPECT;
          var lo = (FacilityStyle.WALL_H - tall) / 2;
          if (lo < 0)
            lo = 0;
          // the run's own footprint: full length along its axis and the GLAZING slab's one unit
          // across it. the first cell's slab already reaches the cell boundary on the run axis
          // (its neighbour there is the wall that bounds the run), so the length is just `wide`
          var s = slab(m, w.col, w.row);
          var x0 = s.x0;
          var z0 = s.z0;
          var x1 = w.alongX ? x0 + wide : s.x1;
          var z1 = w.alongX ? s.z1 : z0 + wide;
          // the exterior face is the one AWAY from the interior, and the interior face its opposite
          var outDir = w.alongX ? (w.inDir > 0 ? 0 : 1) : (w.inDir > 0 ? 2 : 3);
          var inFace = w.alongX ? (w.inDir > 0 ? 1 : 0) : (w.inDir > 0 ? 3 : 2);
          pane(panes, x0, x1, z0, z1, outDir, lo, lo + tall);
          pane(panes, x0, x1, z0, z1, inFace, lo, lo + tall);
          // the reveal, top and bottom. the jambs at the run's ends are already closed by the
          // flanking wall cells' butt caps, because a glazing slab is thinner than the wall it sits
          // in — these two are the only sides with nothing on the far end to cap them
          capDown(head, x0, x1, z0, z1, lo + tall, FacilityStyle.HEAD_TILE);
          if (lo >= 0.05)
            cap(head, x0, x1, z0, z1, lo, FacilityStyle.HEAD_TILE);
        }

      var wallTex = st.hangar ? FacilityStyle.WALL_HANGAR : FacilityStyle.WALL_EXTERIOR;
      var shell:Shell = {
        roof: [],
      };
      add(scene, fTile, FacilityStyle.FLOOR_TILE, true, false);
      add(scene, fLino, FacilityStyle.FLOOR_LINO, true, false);
      add(scene, fConcrete, FacilityStyle.FLOOR_CONCRETE, true, false);
      add(scene, wOut, wallTex, true, true);
      add(scene, wRoom, FacilityStyle.WALL_ROOM, true, false);
      add(scene, wCorr, FacilityStyle.WALL_CORRIDOR, true, false);
      add(scene, shut, FacilityStyle.DOOR_SHUTTER, true, true);
      add(scene, head, FacilityStyle.WINDOW_HEAD, true, false);
      addPane(scene, panes);
      // the roof takes NO vision mask. it is the one surface whose visibility is decided by where the
      // player STANDS rather than by what they can see: masked, a roof over cells the sweep never
      // reached would sink to the fog colour and the building would read as a hole in its own lot
      // from every angle outside it
      addRoof(scene, rim, false, shell);
      addRoof(scene, roof, true, shell);
      return shell;
    }

// the indoor floor buffer a cell's surface asks for. `Surf.GRATE` is deliberately absent and falls
// to room floor: a drain is a fitting IN the floor and not a floor of its own, so it is the
// objects.FloorDrain standing on the cell that paints it, one centred decal — see the atlas note on
// `facility/floor-grate` in textures.json. Painted as a cell-wide surface here instead, a 2 m square
// of grating read as a vehicle pit, and tiled down it read as four of them
  static function floorBuf(m:Facility, col:Int, row:Int, tile:MeshBuf, lino:MeshBuf,
      concrete:MeshBuf):MeshBuf
    {
      return switch (m.surf[row][col])
        {
          case Surf.LINO: lino;
          case Surf.CONCRETE: concrete;
          default: tile;
        };
    }

// the top of one wall or door cell's masonry — permanent roof, and over glazing the aluminium
// capping instead of it, because a window run capped in plain roof read as a strip of bitumen and
// gravel lying on the glass.
//
// emitted as the UNION OF THE RUNS and not as the slab box: the run along x across the middle band,
// and the run along z's two arms, each degenerate and self-skipping where that line does not carry.
// the box would hang a permanent 1x1 patch of rim over the room in every corner's angle, which is
// the notch — the FADING roof's, laid by the strips loop in structure().
//
// the band no longer overhangs on an OUTDOOR side either. it used to stop at WALL_T's inset rather
// than the cell's own, which was a no-op on solid wall and left half a unit of roof out over the
// glass at every window run: the straight roof line it bought was not worth the bitumen sitting on
// the outside of the pane, and the run now notches in with the glazing
  static function capTop(rim:MeshBuf, head:MeshBuf, m:Facility, col:Int, row:Int,
      glazed:Bool):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var s = slab(m, col, row);
      var e = (CELL - thick(m, col, row)) / 2;
      var xa = col * CELL - half + e, xb = xa + CELL - 2 * e;
      var za = row * CELL - half + e, zb = za + CELL - 2 * e;
      var b = glazed ? head : rim;
      var t = glazed ? FacilityStyle.HEAD_TILE : FacilityStyle.ROOF_TILE;
      // with no run along x there is nothing to split around, and the run along z is one rect. worth
      // the branch: without it every cell of every vertical wall in the area emitted its band as
      // three quads that abut, ~900 triangles of roof for no pixel's difference
      if (!carries(m, col - 1, row) &&
          !carries(m, col + 1, row))
        {
          cap(b, xa, xb, s.z0, s.z1, FacilityStyle.ROOF_Y, t);
          return;
        }
      cap(b, s.x0, s.x1, za, zb, FacilityStyle.ROOF_Y, t);
      cap(b, xa, xb, s.z0, za, FacilityStyle.ROOF_Y, t);
      cap(b, xa, xb, zb, s.z1, FacilityStyle.ROOF_Y, t);
    }

// the two side reveals of a door opening, from the floor up to the lintel. both lie in the cell
// boundary planes the wall line runs through, and both look INWARD — the opposite way round from a
// wall face at the same place — so each is emitted for the direction pointing at the other jamb
  static function jamb(b:MeshBuf, alongX:Bool, s:Rect):Void
    {
      if (alongX)
        {
          face(b, s.x0, s.x0, s.z0, s.z1, 3, 0.0, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
          face(b, s.x1, s.x1, s.z0, s.z1, 2, 0.0, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
          return;
        }
      face(b, s.x0, s.x1, s.z0, s.z0, 1, 0.0, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
      face(b, s.x0, s.x1, s.z1, s.z1, 0, 0.0, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
    }

// one exposed end of a slab where its neighbour's cross-section falls short of it. the quad lives
// in the cell boundary plane, so it is `face` with both coordinates of one axis collapsed onto it
  static function butt(b:MeshBuf, flat:Bool, plane:Float, a0:Float, a1:Float, dir:Int):Void
    {
      if (flat)
        face(b, a0, a1, plane, plane, dir, 0.0, FacilityStyle.WALL_H, FacilityStyle.WALL_TILE);
      else
        face(b, plane, plane, a0, a1, dir, 0.0, FacilityStyle.WALL_H, FacilityStyle.WALL_TILE);
    }

// one horizontal cell quad at height y, world-aligned UVs (never stretched)
  static function cap(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0],
        [x0 / t, z1 / t, x1 / t, z1 / t, x1 / t, z0 / t, x0 / t, z0 / t]);
    }

// the same quad wound the other way, so it is seen from BELOW — a door head's soffit
  static function capDown(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, y:Float, t:Float):Void
    {
      if (x1 - x0 < 0.01 ||
          z1 - z0 < 0.01)
        return;
      MeshBufTools.quad(b, [x0, y, z0], [x1, y, z0], [x1, y, z1], [x0, y, z1],
        [x0 / t, z0 / t, x1 / t, z0 / t, x1 / t, z1 / t, x0 / t, z1 / t]);
    }

// the run endpoints of a cell-edge face, wound so the FRONT face looks at the neighbour in `dir`.
// derived rather than hand-cased: for a run direction d the quad's normal is (-dz, 0, dx), so each
// direction fixes which end of the edge is wound first. getting this backwards is invisible until a
// whole axis of faces disappears — the failure render.wild.WildRoad's dashes recorded
  static inline function ends(x0:Float, x1:Float, z0:Float, z1:Float, dir:Int):Array<Float>
    {
      return switch (dir)
        {
          case 0: [x1, z0, x0, z0];
          case 1: [x0, z1, x1, z1];
          case 2: [x0, z0, x0, z1];
          default: [x1, z1, x1, z0];
        };
    }

// one vertical wall face spanning y0..y1, UVs world-aligned along the run and up the wall so
// neighbouring faces of one long wall carry a continuous course. `t` is the repeat period, which the
// shutter runs take at their own value so their slat pitch is independent of the wall course
  static function face(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float, t:Float):Void
    {
      if (y1 - y0 < 0.01)
        return;
      var e = ends(x0, x1, z0, z1, dir);
      var us = (dir < 2 ? e[0] : e[1]) / t;
      var ue = (dir < 2 ? e[2] : e[3]) / t;
      if (Math.abs(ue - us) < 0.0001)
        return;
      MeshBufTools.quad(b, [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [us, y0 / t, ue, y0 / t, ue, y1 / t, us, y1 / t]);
    }

// one window pane over a whole run: the same face winding, but the texture maps 0..1 across it
// rather than tiling.
//
// FLUSH with the wall plane. it used to stand a hundredth of a unit proud of it "so nothing depends
// on polygonOffset" — but the emitter cuts the opening OUT of the wall rather than painting the pane
// over it, so the two are never coplanar-and-overlapping and there was nothing to fight with. All
// the offset bought was a seam of open air along the head and the sill, where the reveal's own caps
// stop at the masonry and the glass no longer did
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float):Void
    {
      var e = ends(x0, x1, z0, z1, dir);
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [0, 0, 1, 0, 1, 1, 0, 1]);
    }

// merge a buffer into one lit mesh. every one of these is OPAQUE now: the walls stopped fading with
// the roof, so nothing here needs `transparent` and nothing here pays for the sorted pass
  static function add(scene:Scene, b:MeshBuf, tex:String, recv:Bool, casts:Bool):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = recv;
      mesh.castShadow = casts;
      scene.add(mesh);
    }

// the lit window pane, frame and glass in ONE draw.
//
// the alpha does the splitting and it comes out of the texture, not the shader: tools/textures.py's
// `glass_alpha` key takes the bright half of the art down to 128 and leaves the dark frame at 255,
// which the source's own luma histogram separates outright (frame 16-127 at 30.6%, glass 144-207 at
// 58.8%, a 0.2% valley between). so the frame stays solid, the glass is half see-through, and there
// is no second mesh and no second material. alphaTest is only there to kill the transparent margin
// the API's cut leaves, so it never writes depth.
//
// the texture is cropped to its own ALPHA BBOX rather than to a pair of hand-fitted fractions. those
// fractions are only right for the exact drop they were measured on and are centred by construction,
// and the art's bbox need not be: the last one sat 9px high of its image, so the crop shaved the top
// rail off the frame and left an empty strip under the glass for alphaTest to throw away.
//
// `transparent` is set AFTER VisionMask.patch on purpose: the mask reads that flag to choose which
// branch it compiles, and set first it would pick the alpha-scaling branch and fade a hidden window
// OUT instead of sinking it toward the fog (see render.wild.WildRoad)
  static function addPane(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadAlphaCropped(FacilityStyle.WINDOW_LIT);
      var mat = VisionMask.patch(new MeshLambertMaterial({
        map: tex,
        emissiveMap: tex,
        emissive: new Color(0xffffff),
        emissiveIntensity: FacilityStyle.WINDOW_EMISSIVE,
        alphaTest: 0.02,
        side: THREE.FrontSide,
      }));
      mat.transparent = true;
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
    }

// the roof. no vision mask (see the call site) and no shadow casting: the moon box follows the
// player, so a roof casting over its own lot would put the whole building in shadow the moment the
// player walked past it
  static function addRoof(scene:Scene, b:MeshBuf, fades:Bool, shell:Shell):Void
    {
      if (b.idx.length == 0)
        return;
      var mat = new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.ROOF, 'roof', 1),
        side: THREE.FrontSide,
      });
      if (fades)
        {
          mat.transparent = true;
          mat.opacity = 1.0;
        }
      var mesh = new Mesh(geom(b), mat);
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      if (fades)
        shell.roof.push(mesh);
    }

// one merged buffer as a BufferGeometry
  static function geom(b:MeshBuf):BufferGeometry
    {
      var g = new BufferGeometry();
      g.setAttribute('position', new Float32BufferAttribute(b.pos, 3));
      g.setAttribute('uv', new Float32BufferAttribute(b.uv, 2));
      g.setIndex(b.idx);
      g.computeVertexNormals();
      return g;
    }
}

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

// the footprint a wall cell's masonry actually occupies, in world units.
//
// HALF a cell thick for solid wall and a QUARTER for glazing, reaching the cell boundary only on
// the sides where the wall line carries on. three things fall out of that one rule and none of them
// needs a case of its own:
//   - a straight run comes out 2 units thick, so a doorway is a 2-unit reveal and not a 4-unit tunnel
//   - a corner comes out a 3x3 pier: FLUSH on the outside, because both outer faces sit at the same
//     inset as the runs meeting there, and a shoulder on the inside that reads as a pilaster
//   - a window slab sits strictly INSIDE its neighbour's cross-section, so the neighbour's own butt
//     cap is the jamb reveal and the hole that used to be there closes for free
// also correct for a DOOR cell, which is not a wall: its wall-line neighbours carry, so it comes
// back as exactly the lintel planes
  public static function slab(m:Facility, col:Int, row:Int):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var t = (FacilityModel.inside(m, col, row) && m.wall[row][col] == Wall.WINDOW ?
        FacilityStyle.GLASS_T : FacilityStyle.WALL_T);
      var e = (CELL - t) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// the roof band over one wall cell. clipped to the OUTER slab face on any side that faces outdoors,
// so the building's roof outline is its own outer wall and there is no floating eave; everywhere
// else it runs to the cell boundary and meets the roof over the floor. the inset is WALL_T's on
// every cell, glazing included, or the roof line would notch in half a unit at every window run
  static function rimRect(m:Facility, col:Int, row:Int):Rect
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var e = (CELL - FacilityStyle.WALL_T) / 2;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      function open(c:Int, r:Int):Float
        {
          return carries(m, c, r) || FacilityModel.isIndoor(m, c, r) ? 0.0 : e;
        }
      return {
        x0: x0 + open(col - 1, row),
        x1: x0 + CELL - open(col + 1, row),
        z0: z0 + open(col, row - 1),
        z1: z0 + CELL - open(col, row + 1),
      };
    }

// the floor strips a cell's slab leaves uncovered — the cell rect minus the slab rect, decomposed
// so nothing overlaps: north and south span the full cell width and own the corners, west and east
// take what is left. a side whose wall line carries on is degenerate and never appears
  public static function strips(m:Facility, col:Int, row:Int):Array<Strip>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var s = slab(m, col, row);
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
      return out;
    }

// which side of a butt cap looks at indoor floor.
//
// the space a cap actually faces is DIAGONAL from its own cell: one step along the wall line into
// the neighbour it butts against, then one step off the line toward the side the excess sits on.
// reading the neighbour itself instead gets a window jamb right and a corner pier wrong, because a
// corner's shoulder looks past the run it meets and into the room behind it
  static inline function diagIndoor(m:Facility, col:Int, row:Int, dir:Int, side:Int):Bool
    {
      return FacilityModel.isIndoor(m,
        col + DC[dir] + (dir < 2 ? side : 0),
        row + DR[dir] + (dir < 2 ? 0 : side));
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
      var fGrate = MeshBufTools.make();
      var fConcrete = MeshBufTools.make();
      // walls. NOT split by facing any more — see the Shell header
      var wOut = MeshBufTools.make();
      var wIn = MeshBufTools.make();
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

      for (row in st.oy1...st.oy2 + 1)
        for (col in st.ox1...st.ox2 + 1)
          {
            if (!FacilityModel.inside(m, col, row) ||
                m.owner[row][col] != si)
              continue;
            var x0 = col * CELL - half, x1 = x0 + CELL;
            var z0 = row * CELL - half, z1 = z0 + CELL;
            if (FacilityModel.isWall(m, col, row))
              {
                var s = slab(m, col, row);
                var glazed = (m.wall[row][col] == Wall.WINDOW);
                var shutter = (m.wall[row][col] == Wall.SHUTTER);
                capTop(rim, head, m, col, row, s, glazed);
                for (dir in 0...4)
                  {
                    var nc = col + DC[dir];
                    var nr = row + DR[dir];
                    if (carries(m, nc, nr))
                      {
                        // the line carries on, so the two slabs meet in the cell boundary plane.
                        // wherever MY cross-section is wider than my neighbour's, the difference is
                        // a real exposed end and a hole if it is not capped: at a corner it is the
                        // pier's shoulder, and at a window run's end it is the JAMB REVEAL — which
                        // is the whole of item (e), closed here by arithmetic rather than by a case
                        var n = slab(m, nc, nr);
                        var flat = (dir < 2);
                        var pl = flat ? (dir == 0 ? s.z0 : s.z1) : (dir == 2 ? s.x0 : s.x1);
                        var a0 = flat ? s.x0 : s.z0, a1 = flat ? s.x1 : s.z1;
                        var b0 = flat ? n.x0 : n.z0, b1 = flat ? n.x1 : n.z1;
                        if (a0 < b0 - 0.005)
                          butt(diagIndoor(m, col, row, dir, -1) && !st.hangar ? wIn : wOut,
                            flat, pl, a0, b0, dir);
                        if (a1 > b1 + 0.005)
                          butt(diagIndoor(m, col, row, dir, 1) && !st.hangar ? wIn : wOut,
                            flat, pl, b1, a1, dir);
                        continue;
                      }
                    // a face looking at indoor floor is an inside face; anything else — the lot, the
                    // grass, the walkway, or off the grid entirely — is the outside of the building
                    var inner = FacilityModel.isIndoor(m, nc, nr);
                    // the shutter is chosen off THIS cell rather than off the neighbour, unlike the
                    // interior/exterior split below it: a roll-up door reads as a door from both sides
                    var b = shutter ? shut : (st.hangar || !inner ? wOut : wIn);
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
                // whatever the slab does not cover is floor, and it is the neighbour's floor. the
                // outdoor half of this is emitted by render.facility.FacilityGround off the same
                // strips(), because that is where the ground buffers live
                for (sp in strips(m, col, row))
                  {
                    if (!FacilityModel.isIndoor(m, sp.col, sp.row))
                      continue;
                    cap(floorBuf(m, sp.col, sp.row, fTile, fLino, fGrate, fConcrete),
                      sp.x0, sp.x1, sp.z0, sp.z1, 0.0, floorTile(m, sp.col, sp.row));
                  }
                continue;
              }
            cap(roof, x0, x1, z0, z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
            // a door cell carries FLOOR and no wall — the generator finalises one to plain corridor
            // lino — so without this the building has a hole in it at every doorway. the head closes
            // BOTH faces of the reveal, and the reveal is now WALL_T deep rather than a whole cell
            var di = g.doorAt[row][col];
            if (di >= 0)
              {
                var s = slab(m, col, row);
                var soffit = null;
                for (k in 0...2)
                  {
                    var dir = (m.doors[di].alongX ? k : 2 + k);
                    var inner = FacilityModel.isIndoor(m, col + DC[dir], row + DR[dir]);
                    var b = st.hangar || !inner ? wOut : wIn;
                    face(b, s.x0, s.x1, s.z0, s.z1, dir, FacilityStyle.DOOR_H, FacilityStyle.WALL_H,
                      FacilityStyle.WALL_TILE);
                    if (soffit == null)
                      soffit = b;
                  }
                // and the head from UNDERNEATH. the two faces above sit on the slab's own planes
                // while the leaves hang between them, so without this the reveal over a door is open
                // to the sky. verified before adding, by putting the free cam on the floor and
                // looking up: a black void over every doorway. the game camera pitches DOWN 51
                // degrees and never sees it, which is exactly why it would have shipped
                capDown(soffit, s.x0, s.x1, s.z0, s.z1, FacilityStyle.DOOR_H, FacilityStyle.WALL_TILE);
              }
            cap(floorBuf(m, col, row, fTile, fLino, fGrate, fConcrete),
              x0, x1, z0, z1, 0.0, floorTile(m, col, row));
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
          pane(panes, x0, x1, z0, z1, outDir, lo, lo + tall, FacilityStyle.WINDOW_EPS);
          pane(panes, x0, x1, z0, z1, inFace, lo, lo + tall, FacilityStyle.WINDOW_EPS);
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
      add(scene, fGrate, FacilityStyle.FLOOR_GRATE, true, false);
      add(scene, fConcrete, FacilityStyle.FLOOR_CONCRETE, true, false);
      add(scene, wOut, wallTex, true, true);
      add(scene, wIn, FacilityStyle.WALL_INTERIOR, true, false);
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

// the indoor floor buffer a cell's surface asks for
  static function floorBuf(m:Facility, col:Int, row:Int, tile:MeshBuf, lino:MeshBuf,
      grate:MeshBuf, concrete:MeshBuf):MeshBuf
    {
      return switch (m.surf[row][col])
        {
          case Surf.LINO: lino;
          case Surf.GRATE: grate;
          case Surf.CONCRETE: concrete;
          default: tile;
        };
    }

// and its repeat period. the drain grate is ONE cell of art and maps across the cell rather than
// tiling by world position, so it is the one surface that cannot take the shared value
  static inline function floorTile(m:Facility, col:Int, row:Int):Float
    {
      return m.surf[row][col] == Surf.GRATE ?
        FacilityStyle.GRATE_TILE : FacilityStyle.FLOOR_TILE_SZ;
    }

// the roof band over a wall cell, and — over glazing — the frame cap that replaces it. capped in
// plain roof, a window run read as a strip of bitumen and gravel lying on the glass, which is
// item (d). three bands across the run: roof outboard of the glazing, the cap ON it, roof inboard
  static function capTop(rim:MeshBuf, head:MeshBuf, m:Facility, col:Int, row:Int, s:Rect,
      glazed:Bool):Void
    {
      var r = rimRect(m, col, row);
      if (!glazed)
        {
          cap(rim, r.x0, r.x1, r.z0, r.z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
          return;
        }
      if (carries(m, col - 1, row) || carries(m, col + 1, row))
        {
          cap(rim, r.x0, r.x1, r.z0, s.z0, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
          cap(head, r.x0, r.x1, s.z0, s.z1, FacilityStyle.ROOF_Y, FacilityStyle.HEAD_TILE);
          cap(rim, r.x0, r.x1, s.z1, r.z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
          return;
        }
      cap(rim, r.x0, s.x0, r.z0, r.z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
      cap(head, s.x0, s.x1, r.z0, r.z1, FacilityStyle.ROOF_Y, FacilityStyle.HEAD_TILE);
      cap(rim, s.x1, r.x1, r.z0, r.z1, FacilityStyle.ROOF_Y, FacilityStyle.ROOF_TILE);
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
// rather than tiling, and it stands `eps` off the wall plane so nothing depends on polygonOffset
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float,
      dir:Int, y0:Float, y1:Float, eps:Float):Void
    {
      var e = ends(x0, x1, z0, z1, dir);
      var ox = (dir == 2 ? -eps : (dir == 3 ? eps : 0.0));
      var oz = (dir == 0 ? -eps : (dir == 1 ? eps : 0.0));
      MeshBufTools.quad(b,
        [e[0] + ox, y0, e[1] + oz], [e[2] + ox, y0, e[3] + oz],
        [e[2] + ox, y1, e[3] + oz], [e[0] + ox, y1, e[1] + oz],
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
// which the source's own luma histogram separates outright (frame 16-127, glass 144-207, a 0.7%
// valley between). so the frame stays solid, the glass is half see-through, and there is no second
// mesh and no second material. alphaTest is only there to kill the 1px transparent margin the API's
// cut leaves, so it never writes depth.
//
// `transparent` is set AFTER VisionMask.patch on purpose: the mask reads that flag to choose which
// branch it compiles, and set first it would pick the alpha-scaling branch and fade a hidden window
// OUT instead of sinking it toward the fog (see render.wild.WildRoad)
  static function addPane(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var tex = Textures.loadCroppedTexture(FacilityStyle.WINDOW_LIT, 0.895, 0.446);
      tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
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

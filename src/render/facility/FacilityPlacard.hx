package render.facility;

import three.Three;
import citygen.CityConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the safety placards on a lab ROOM's walls, one per run of masonry.
//
// this is the surface the whole interior phase was aimed at. measured on a pinned pose, a room wall
// is 10.25% of the frame and a room floor 12.05%, and of the two the wall carried NOTHING but the
// damp band: the exit signage is Surf.LINO-gated so it is corridors only, the notice board is one per
// front entrance, and the fire points and panels are corridor fittings too. Every family in the
// compound was hung in the circulation and none of them ever reached a room.
//
// A TEXTURE AND NOT A PROP, which is the silhouette-vs-surface guard read the way the notice board
// reads it: a sign plate's outline is a rectangle and there is no silhouette in it to pay triangles
// for, while everything that says "hazard placard" rather than "grey square" is a PICTOGRAM on its
// face. So it is one quad and one atlas cell, and the family costs one draw call however many stand.
//
// ONE PER RUN AND NEVER PER CELL. a run here is a stretch of room floor hugging unbroken solid
// masonry, and the sign goes on its MIDDLE cell — a placard every cell turns a wall into a strip of
// stickers, and one at a run's end lands beside the doorway that broke the run. The doorway is what
// ends a run at all: a door cell is not isSolidWall, so a wall with an opening in it is two runs and
// takes two signs, which is where a real pair is.
//
// AND IT NEEDS NO CLAIMED-CELL LIST, which is the one thing separating it from every other family
// that stands against a wall. FacilityStyle.PLACARD_Y hangs it clear of the tallest thing that can
// share the cell (FacilityStyle.DECO_CABINET_H 3.43), so the collision question the fire points had
// to answer against FacilityTables.runs simply does not arise up here
class FacilityPlacard
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every placard in the compound, merged into one mesh. returns how many went in, for __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      var seen = new Map<Int, Bool>();
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x —
          // FacilityTables.runs' own walk, which this cannot call: that one is LINO-gated and rolls
          // the casework's CASE_PCT, and a room is exactly what it refuses
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          for (row in 0...m.h)
            for (col in 0...m.w)
              {
                if (seen.exists(key(m, col, row, dir)) ||
                    !hangs(m, col, row, dir))
                  continue;
                var len = 0;
                while (hangs(m, col + sc * len, row + sr * len, dir))
                  {
                    seen.set(key(m, col + sc * len, row + sr * len, dir), true);
                    len++;
                  }
                if (len < FacilityStyle.PLACARD_RUN_MIN)
                  continue;
                var k = len >> 1;
                quad(b, m, col + sc * k, row + sr * k, dir);
                n++;
              }
        }
      FacilityGeom.add(scene, b, FacilityStyle.PLACARD_TEX, true, false);
      return n;
    }

// can a placard hang on the `dir` wall of this cell: ROOM floor looking at plain masonry whose wall
// line carries on past it both ways.
//
// Surf.TILE and not isIndoor is the whole gate, and it is the one FacilityKit already runs on: lino
// is the corridor, where the signage and the fittings live, and concrete is the hangar. that split is
// also what keeps this family off every corridor family's wall with no check against any of them.
//
// the carries-both-ways half is FacilityKit.wall's rule and is here for FacilityPoint's reason:
// FacilityGeom.slab insets a face by a unit wherever the wall line STOPS at that cell, so on the last
// cell of a run the masonry shows 3 units of a 4-unit cell and a PLACARD_W quad centred on the cell
// would hang past the end of the wall it is bolted to
  static function hangs(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          m.surf[row][col] != Surf.TILE ||
          !FacilityModel.isSolidWall(m, col + DC[dir], row + DR[dir]))
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// one cell's slot in a claimed-cell set, PER DIRECTION — FacilityTables.key's own layout, and claimed
// per direction for its reason: a cell in a corner of a room has masonry on two hands and each is its
// own run
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one placard on the masonry beside cell (col,row), MOUNT_PROUD clear of the wall face and centred on
// the cell. the plane is the SLAB's face and never the cell boundary, the same trap FacilityExit.quad,
// FacilityPoint.quad and FacilityTables.unit all take.
//
// no clamp to the slab along the wall, where the fire points need one: `hangs` has already rejected
// every cell the wall line stops at, so the masonry here always spans the full cell
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.PLACARD_W / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = FacilityStyle.PLACARD_Y - FacilityStyle.PLACARD_H / 2;
      var y1 = FacilityStyle.PLACARD_Y + FacilityStyle.PLACARD_H / 2;
      // which of the four pictograms, rolled off the cell. NOT (col * A) ^ (row * B), which collapses
      // on row 0 and col 0 — FacilityTables.runs' own three-term mix, with `dir` in it so the two
      // walls meeting in a room's corner cannot come back as the same sign
      var i = FacilityModel.mix((col * 374761393) ^ (row * 668265263) ^ (dir * 83492791)) %
        FacilityStyle.PLACARD_CELLS;
      // the face looks BACK at the cell the placard stands on, so it is the opposite of the side the
      // masonry is on
      var d = dir ^ 1;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - h, c.x + h, z, z, d, y0, y1, i);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - h, c.z + h, d, y0, y1, i);
    }

// FacilityGeom.pane with the uv opened up to one cell of the 2x2 sheet. three flips y, so the
// source's TOP row is v 0.5..1: cell 0 biohazard and 1 laser are the top pair, 2 no-entry and 3 eye
// protection the bottom one. derived from the index rather than named constant by constant because
// the sheet is a regular grid — see FacilityStyle.PLACARD_CELLS. everything else about the winding is
// that function's, through its own `ends`
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, i:Int):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u0 = (i & 1) * 0.5;
      var v0 = (i < 2 ? 0.5 : 0.0);
      var u1 = u0 + 0.5;
      var v1 = v0 + 0.5;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, v0, u1, v0, u1, v1, u0, v1]);
    }
}

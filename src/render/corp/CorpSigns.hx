package render.corp;

import three.Three;
import citygen.CityConfig;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the four things hanging on a corp tower's walls: a fire-exit sign, a wayfinding directory, a room
// plate and a framed print.
//
// A TEXTURE AND NOT A PROP, the silhouette-vs-surface guard read the way render.facility
// .FacilityPlacard reads it: a sign's outline is a rectangle and there is nothing in that outline
// to pay triangles for, while everything that says "fire exit" rather than "grey square" is a
// PICTOGRAM on its face. So the whole family is one quad each off one atlas and costs ONE draw
// call however many hang.
//
// ONE PER RUN AND NEVER PER CELL, and the doorway is what ends a run: a door cell is not
// isSolidWall, so a wall with an opening in it is two runs and takes two signs — which is where a
// real pair is. A sign every cell turns a wall into a strip of stickers.
//
// FOUR ASPECTS ON ONE SHEET, which is the one place this differs from the compound's placards and
// the reason it has an ASPECT table at all. The compound's eight plates are all square, so
// PLACARD_W == PLACARD_H and a quad needs no arithmetic. A landscape exit sign, a portrait
// directory, a square plate and a landscape print are not, and drawing any of them on a square quad
// is the stretch docs/3d-geometry.md's aspect lock exists to forbid. So the LONGEST edge is
// CorpStyle.SIGN_MAX and the other comes off the art's own measured ratio.
class CorpSigns
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the atlas, in reading order: 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
  static inline var SIGN_EXIT = 0;       // green running man, circulation only
  static inline var SIGN_DIRECTORY = 1;  // smoked-glass floor listing, circulation only
  static inline var SIGN_PLATE = 2;      // brushed room plate, every other room
  static inline var SIGN_ART = 3;        // framed print, the rooms that would have one

  // each panel's own width:height, MEASURED off the built sheet's crops and not chosen — see the
  // class header and art/textures.json's note on corp/signs
  static var ASPECT = [1.6553, 0.7038, 1.0400, 1.5034];

// every sign on the plate, merged into one mesh. returns how many hang, for __corp()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      var seen = new Map<Int, Bool>();
      for (dir in 0...4)
        {
          // a run follows the WALL, so it advances along x for a wall in z and along z for one in x
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
                if (len < CorpStyle.SIGN_RUN_MIN)
                  continue;
                // the MIDDLE of the run, which is where a sign centred on a wall belongs — the
                // compound picks its cell by what stands under the plate instead, and that is a
                // hazard-signage rule: a triangle is placed AT its hazard. None of these four names
                // a thing, so none of them has anywhere it would rather be
                var at = Std.int(len / 2);
                quad(b, m, col + sc * at, row + sr * at, dir,
                  pick(m, col + sc * at, row + sr * at));
                n++;
              }
        }
      FacilityGeom.add(scene, b, CorpStyle.SIGN_TEX, true, false);
      return n;
    }

// which sign this run earns, off the surface it hangs in
  static function pick(m:Facility, col:Int, row:Int):Int
    {
      var s = m.surf[row][col];
      // the two rooms a premium tower hangs ART in, and the only two: a print over a desk farm is
      // an office-supplies catalogue, over a boardroom table it is what the room is for
      if (s == Surf.EXEC ||
          s == Surf.MEETING)
        return SIGN_ART;
      // and CIRCULATION takes the wayfinding, alternating so a corridor does not read as a row of
      // one thing. The lift lobby counts as circulation here — it is where somebody arriving looks
      if (s == Surf.CARPET ||
          s == Surf.LIFT)
        return (FacilityModel.mix((col * 668265263) ^ (row * 1103515245)) % 2 == 0 ?
          SIGN_EXIT : SIGN_DIRECTORY);
      return SIGN_PLATE;
    }

// can a sign hang on the `dir` wall of this cell: INDOOR floor looking at plain masonry whose wall
// line carries on past it both ways.
//
// the carries-both-ways half is FacilityKit.wall's rule and is here for its reason: FacilityGeom
// .slab insets a face by a unit wherever the wall line STOPS at that cell, so on the last cell of a
// run the masonry shows three units of a four-unit cell and a quad centred on the cell would hang
// past the end of the wall it is bolted to.
//
// AND NO CLAIMED-CELL LIST, the one thing separating this from every family that STANDS against a
// wall: CorpStyle.SIGN_Y 4.6 hangs it clear of the tallest thing that can share the cell (a server
// rack at RACK_H 4.0), so the collision question simply does not arise up here
  static function hangs(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row) ||
          !FacilityModel.isInterior(m, col, row) ||
          FacilityModel.isWall(m, col, row) ||
          m.table[row][col] ||
          m.fit[row][col] != 0)
        return false;
      var c = col + DC[dir];
      var r = row + DR[dir];
      if (!FacilityModel.isSolidWall(m, c, r))
        return false;
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// one cell's slot in a claimed-cell set, PER DIRECTION: a cell in a room corner has masonry on two
// hands and each is its own run
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one sign on the masonry beside (col,row), SIGN_PROUD clear of the wall face and centred on the
// cell. the plane is the SLAB's face and never the cell boundary — a corp wall slab is a unit
// inside its cell, and a quad on the boundary hangs in mid-air
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, dir:Int, sign:Int):Void
    {
      var s = FacilityGeom.slab(m, col + DC[dir], row + DR[dir]);
      var a = ASPECT[sign];
      var w = (a >= 1 ? CorpStyle.SIGN_MAX : CorpStyle.SIGN_MAX * a) / 2;
      var hh = (a >= 1 ? CorpStyle.SIGN_MAX / a : CorpStyle.SIGN_MAX) / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y0 = CorpStyle.SIGN_Y - hh;
      var y1 = CorpStyle.SIGN_Y + hh;
      // the face looks BACK at the cell the sign is read from, so it is the opposite of the side
      // the masonry is on
      var d = dir ^ 1;
      var e = CorpStyle.SIGN_PROUD;
      if (d < 2)
        {
          var z = (d == 0 ? s.z0 - e : s.z1 + e);
          pane(b, c.x - w, c.x + w, z, z, d, y0, y1, sign);
          return;
        }
      var x = (d == 2 ? s.x0 - e : s.x1 + e);
      pane(b, x, x, c.z - w, c.z + w, d, y0, y1, sign);
    }

// one upright quad wearing one 2x2 quadrant
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

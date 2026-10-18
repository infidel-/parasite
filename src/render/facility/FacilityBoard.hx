package render.facility;

import three.Three;
import citygen.CityConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Wall;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the notice board in each lobby: one quad carrying its own art, hung on the INTERIOR face of the
// entrance wall.
//
// a texture and not a prop, which is the SILHOUETTE vs SURFACE guard read from the other side. a
// corkboard's outline is a rectangle — there is no silhouette in it to pay triangles for — and
// everything that says "notice board" rather than "grey panel" is a RHYTHM on its face: pinned
// sheets at slightly different angles. so it is one quad and one image, the way a window pane is.
// it must also be its OWN image and never the wall's: a fitting painted in the wall's own texture is
// a lump of wall, which is what the door hood was reported as before it got art of its own.
//
// finding the entrance is the work, and `look` cannot answer it: FacilityModel.lookOf collapses
// Const.FRAME_DOOR_DOUBLE and _GLASS onto one painted pair, so by the time the shell is built the
// front entrance is indistinguishable from a side door. DoorCell.front carries the raw frame instead
class FacilityBoard
{
// one board per structure that has a front entrance, merged into a single mesh. returns how many
// went in, for __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var done = new Map<Int, Bool>();
      var n = 0;
      // pass 0 takes the MULLION and nothing else, pass 1 takes whatever is left. the generator cuts
      // the entrance three cells wide and puts the centre cell back as wall, so the mullion is a
      // 4-unit pier dead ahead of anyone walking in — and it is the one candidate that does not
      // depend on what the rest of the facade happens to hold. a single-leaf entrance has none, and
      // falls to the flanking masonry rather than going without
      for (pass in 0...2)
        for (d in m.doors)
          {
            if (!d.front ||
                done.exists(d.structure))
              continue;
            for (s in [-1, 1])
              {
                var col = d.col + (d.alongX ? s : 0);
                var row = d.row + (d.alongX ? 0 : s);
                if (pass == 0 &&
                    !front(m, col + (d.alongX ? s : 0), row + (d.alongX ? 0 : s)))
                  continue;
                if (!hangs(m, col, row, d.alongX))
                  continue;
                quad(b, m, col, row, d.alongX);
                done.set(d.structure, true);
                n++;
                break;
              }
          }
      FacilityGeom.add(scene, b, FacilityStyle.BOARD_TEX, true, false);
      return n;
    }

// is this cell one of the two leaves of a front entrance? linear over the door list, which is ~20
// openings and is read a handful of times per area build
  static function front(m:Facility, col:Int, row:Int):Bool
    {
      for (d in m.doors)
        if (d.col == col &&
            d.row == row &&
            d.front)
          return true;
      return false;
    }

// can a board hang on this cell: plain masonry — a doorway carries no wall down here and glazing is
// see-through — with indoor floor behind one of its two faces
  static function hangs(m:Facility, col:Int, row:Int, alongX:Bool):Bool
    {
      return FacilityModel.isWall(m, col, row) &&
        m.wall[row][col] != Wall.WINDOW &&
        inward(m, col, row, alongX) >= 0;
    }

// which face of an entrance wall cell looks INTO the building, as a FacilityGeom `dir`, or -1 for
// neither. only the two faces PERPENDICULAR to the wall line are candidates — along the line there
// is nothing but more wall
  static function inward(m:Facility, col:Int, row:Int, alongX:Bool):Int
    {
      if (alongX)
        return FacilityModel.isIndoor(m, col, row - 1) ? 0 :
          (FacilityModel.isIndoor(m, col, row + 1) ? 1 : -1);
      return FacilityModel.isIndoor(m, col - 1, row) ? 2 :
        (FacilityModel.isIndoor(m, col + 1, row) ? 3 : -1);
    }

// one board, centred on the cell and MOUNT_PROUD clear of the masonry — the same nudge the vent
// grille takes and for the same reason: a coplanar quad z-fights the wall behind it, and this repo
// has lost three times to polygonOffset instead.
//
// the plane is the SLAB's face and never the cell boundary: a wall cell is 2 units of masonry
// centred in a 4-unit cell, so a board on the boundary would hang a unit inside the room
  static function quad(b:MeshBuf, m:Facility, col:Int, row:Int, alongX:Bool):Void
    {
      var dir = inward(m, col, row, alongX);
      var s = FacilityGeom.slab(m, col, row);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.BOARD_W / 2;
      var c = CityConfig.cellToWorld(col, row);
      var y = FacilityStyle.BOARD_Y;
      if (alongX)
        {
          var z = (dir == 0 ? s.z0 - e : s.z1 + e);
          FacilityGeom.pane(b, c.x - h, c.x + h, z, z, dir, y - h, y + h);
          return;
        }
      var x = (dir == 2 ? s.x0 - e : s.x1 + e);
      FacilityGeom.pane(b, x, x, c.z - h, c.z + h, dir, y - h, y + h);
    }
}

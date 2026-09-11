package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// one wall fitting, as `places` derives it off the grid
typedef Point = {
  // the CORRIDOR FLOOR cell it stands on — not the wall cell, which is this plus `dir`
  col:Int,
  row:Int,
  // which of that cell's four sides the masonry is on, in render.facility.FacilityGeom.face's
  // numbering (0 = -z, 1 = +z, 2 = -x, 3 = +x)
  dir:Int,
  // true for the ELECTRICAL PANEL, false for a FIRE POINT. one bool and not an enum because there
  // are two kinds and the only thing anything asks is which atlas cell to take
  panel:Bool,
};

// the two corridor wall fittings a keep-clear zone actually belongs to: the FIRE POINT and the
// ELECTRICAL PANEL. render.facility.FacilityPaint strikes the hatch on the floor and this file
// stands the thing the hatch is for — a zone with nothing over it is a stain, which is the whole
// reason this exists as a second step rather than as more paint.
//
// BOTH ARE WALL QUADS AND NEITHER IS A PROP. A distribution panel is a flat door with a label: pure
// surface, no silhouette, and the box-is-not-a-prop guard answers it outright. A fire point reads
// from this camera as its red backboard and its floor zone and not as the cylinder — at the measured
// 65.6 degree gameplay pitch a 0.9-unit extinguisher on a bracket is a few pixels of edge. So the
// family is two cells of ONE atlas on ONE mesh, which is render.facility.FacilityExit's shape
// verbatim and costs one draw call however many are built.
//
// THE PLACEMENT IS COMPUTED TWICE AND SHARED NOWHERE. `places` is a pure function of the saved grid,
// so FacilityPaint calls it to strike the zones and `build` calls it to stand the fittings, and
// neither builder has to run before the other — which matters, because FacilityPaint runs inside
// FacilityGround.build and this runs a dozen lines later. The same discipline FacilityTables.hugs
// and FacilityGround.bins already keep between the casework and the litter bins.
//
// AND IT READS THE CASEWORK'S OWN RUN LIST rather than inventing a clearance, which is the one real
// collision in this family and the first in the compound that needed a check against another
// builder at all: a cabinet and a fitting want the same wall face, and FacilityStyle.MARK_WALL_CLEAR
// cannot separate them the way it separated the aisle from the casework — that number works because
// a lane runs down the MIDDLE of a corridor, and a fitting is bolted to the same masonry a cabinet
// is. The litter bins need no test of their own: FacilityTables.hugs rejects the dead-end and inside
// -corner cells, which are exactly the bins' cells
class FacilityPoint
{
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every fitting in the compound, merged into one mesh. returns how many went in, for __facility()
  public static function build(scene:Scene, m:Facility):Int
    {
      var b = MeshBufTools.make();
      var list = places(m);
      for (p in list)
        quad(b, m, p);
      add(scene, b);
      return list.length;
    }

// every fitting the compound stands: which corridor cell, which wall of it, and which of the two
// kinds.
//
// ONE PANEL PER STRUCTURE and fire points for the rest, and the SORT is what decides which is which
// rather than a second rule: candidates are ordered by how far they are from their own structure's
// nearest exterior door, so the first one kept inside a structure is the one by its entrance and
// that is the panel — where a distribution board actually is. Everything after it in that structure
// is a fire point.
//
// the thinning is greedy over that order and measured between CELLS rather than along one wall, so a
// two-wide corridor cannot take a fitting on each hand of the same stretch — the failure the exit
// signage's own EXIT_APPROACH exists to stop, arrived at here from the other side
  public static function places(m:Facility):Array<Point>
    {
      var taken = new Map<Int, Bool>();
      for (r in FacilityTables.runs(m))
        {
          var sc = (r.dir < 2 ? 1 : 0);
          var sr = (r.dir < 2 ? 0 : 1);
          for (i in 0...r.len)
            taken.set(key(m, r.col + sc * i, r.row + sr * i, r.dir), true);
        }
      // every free corridor wall face, with its distance to its own structure's way out
      var cand = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          for (dir in 0...4)
            {
              if (!FacilityTables.hugs(m, col, row, dir) ||
                  taken.exists(key(m, col, row, dir)) ||
                  !runsOn(m, col, row, dir))
                continue;
              cand.push({
                col: col,
                row: row,
                dir: dir,
                d: toDoor(m, col, row),
              });
            }
      // nearest the entrance first, and the CELL INDEX breaks a tie so the order cannot depend on
      // the sort's own stability
      cand.sort(function(a, b) return a.d != b.d ? a.d - b.d :
        (a.row * m.w + a.col) * 4 + a.dir - ((b.row * m.w + b.col) * 4 + b.dir));
      var out:Array<Point> = [];
      var owned = new Map<Int, Bool>();
      for (c in cand)
        {
          var clear = true;
          for (p in out)
            if (Std.int(Math.abs(p.col - c.col)) < FacilityStyle.POINT_SPACING &&
                Std.int(Math.abs(p.row - c.row)) < FacilityStyle.POINT_SPACING)
              clear = false;
          if (!clear)
            continue;
          var st = m.owner[c.row][c.col];
          out.push({
            col: c.col,
            row: c.row,
            dir: c.dir,
            panel: !owned.exists(st),
          });
          owned.set(st, true);
        }
      return out;
    }

// how many cells this corridor cell is from the nearest exterior door of its OWN structure, or a
// number bigger than any grid distance for a structure with no way out at all.
//
// straight-line cells and not a flood, which is enough for what it decides: the answer only orders
// the candidates inside one building, and a fitting a corner further round the same lobby is not a
// different decision. FacilityExit's flood is the real distance and is not worth a second walk here
  static function toDoor(m:Facility, col:Int, row:Int):Int
    {
      var best = m.w + m.h;
      for (d in m.doors)
        {
          if (FacilityGlow.outward(m, d) == 0 ||
              m.owner[d.row][d.col] != m.owner[row][col])
            continue;
          var v = Std.int(Math.abs(d.col - col) + Math.abs(d.row - row));
          if (v < best)
            best = v;
        }
      return best;
    }

// does the wall line this face belongs to RUN ON past the cell BOTH ways?
//
// FacilityKit.wall's own test, and it is here for the same reason it is there: FacilityGeom.slab
// insets a face by a unit wherever the wall line STOPS at that cell, so on the last cell of a run the
// masonry shows 3 units of a 4-unit cell and a POINT_W quad centred on the cell lands flush against
// that inset end — which is the corner. Reported from the game as "we have an extinguisher right on
// the corner where i'm standing", measured at cell (34,31): the wall at row 30 runs cols 32..34 and
// col 35 is the mouth of a passage, so the fitting sat on the run's last cell at the opening.
//
// FacilityTables.hugs does NOT ask this and should not — a casework RUN answers the same fact by
// CLAMPING itself to the slab, which shortens the last cabinet and looks right. A single fixed-width
// quad has nothing to clamp to, so like the kit props it rejects the cell instead.
//
// a DOOR cell carries, which is correct and not an oversight: the wall LINE runs on through a
// doorway, so a fitting beside one is standing on masonry that continues — and `hugs` has already
// refused the door's own neighbours through nearDoor
  public static inline function runsOn(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      var c = col + DC[dir];
      var r = row + DR[dir];
      var sc = (dir < 2 ? 1 : 0);
      var sr = (dir < 2 ? 0 : 1);
      return FacilityGeom.carries(m, c - sc, r - sr) &&
        FacilityGeom.carries(m, c + sc, r + sr);
    }

// one cell's slot in a claimed-cell set, PER DIRECTION — FacilityTables.key's own layout, and
// claimed per direction for its reason: a corridor two cells wide has a wall on either hand, and a
// cell carrying a cabinet on its north wall is still a candidate on its south
  static inline function key(m:Facility, col:Int, row:Int, dir:Int):Int
    {
      return ((dir * m.h + row) * m.w) + col;
    }

// one fitting on the masonry beside cell (col,row), MOUNT_PROUD clear of the wall face and centred
// on the cell.
//
// the plane is the SLAB's face and never the cell boundary, the same trap FacilityExit.quad and
// FacilityTables.unit both take: a straight run insets its room face a whole unit into the wall cell.
// and the span ALONG the wall is clamped to that slab too, for FacilityTables.unit's own reason —
// slab() insets a side wherever the wall line stops there, so a quad centred on the cell at a run's
// end would hang past the end of the masonry it is bolted to
  static function quad(b:MeshBuf, m:Facility, p:Point):Void
    {
      var s = FacilityGeom.slab(m, p.col + DC[p.dir], p.row + DR[p.dir]);
      var e = FacilityStyle.MOUNT_PROUD;
      var h = FacilityStyle.POINT_W / 2;
      var c = CityConfig.cellToWorld(p.col, p.row);
      var y0 = FacilityStyle.POINT_Y - FacilityStyle.POINT_H / 2;
      var y1 = FacilityStyle.POINT_Y + FacilityStyle.POINT_H / 2;
      var u0 = (p.panel ? FacilityStyle.POINT_U_PANEL : FacilityStyle.POINT_U_FIRE);
      // the face looks BACK at the cell the fitting stands on, so it is the opposite of the side the
      // masonry is on
      var dir = p.dir ^ 1;
      if (dir < 2)
        {
          var z = (dir == 0 ? s.z0 - e : s.z1 + e);
          var x0 = Math.max(c.x - h, s.x0), x1 = Math.min(c.x + h, s.x1);
          pane(b, x0, x1, z, z, dir, y0, y1, u0);
          return;
        }
      var x = (dir == 2 ? s.x0 - e : s.x1 + e);
      var z0 = Math.max(c.z - h, s.z0), z1 = Math.min(c.z + h, s.z1);
      pane(b, x, x, z0, z1, dir, y0, y1, u0);
    }

// FacilityGeom.pane with u opened up: u picks one of the atlas's two side-by-side cells and v runs
// the full 0..1 up the fitting. everything else about the winding is that function's, through its
// own `ends`
  static function pane(b:MeshBuf, x0:Float, x1:Float, z0:Float, z1:Float, dir:Int, y0:Float,
      y1:Float, u0:Float):Void
    {
      var e = FacilityGeom.ends(x0, x1, z0, z1, dir);
      var u1 = u0 + 0.5;
      MeshBufTools.quad(b,
        [e[0], y0, e[1]], [e[2], y0, e[3]], [e[2], y1, e[3]], [e[0], y1, e[1]],
        [u0, 0, u1, 0, u1, 1, u0, 1]);
    }

// merge the buffer into one lit mesh. the plain interior pair — receives the moon's shadow, casts
// none — and NOT the exit signage's both-off, because these are fittings and not lights: nothing
// here has an emissiveMap and the art is opaque, so there is no alphaTest to set and no sorted pass
// to order against anything
  static function add(scene:Scene, b:MeshBuf):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(new MeshLambertMaterial({
        map: Textures.loadTexture(FacilityStyle.POINT_TEX, 'wall', 1),
        side: THREE.FrontSide,
      })));
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}

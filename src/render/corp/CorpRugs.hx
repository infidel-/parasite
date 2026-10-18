package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;
import render.world.VisionMask;

// THE EXEC OFFICE'S RUG: one oval, alpha-cut quad per room over the cells gen.corp laid as
// Const.TILE_FLOOR_EXEC_RUG (and its twin, under the lounge's furniture).
//
// AN OVERLAY AND NOT A FLOOR SWAP, which is the whole brief: the floor under it stays the office's
// dark marble and the rug lies on top with its own oval edge, its border band and the tower's
// eye-in-ring medallion in the middle. A floor texture can only ever tile a cell's square.
//
// SIZED AT THE ART'S OWN ASPECT AND NEVER STRETCHED: corp/exec-rug is 1024 x 640, so the quad is
// the biggest 1.6:1 that fits the rug's rect less RUG_INSET, its long axis turned onto the rect's.
//
// ONE MESH FOR EVERY RUG ON THE PLATE, the hangar floor litter's shape (FacilityHangar.add): an
// opaque alphaTest quad is one pass and writes depth. It lies at RUG_Y, over the floor and under
// render.corp.CorpLamps' additive pools at GLOW_Y — separated by HEIGHT, never polygonOffset, the
// standing rule in docs/3d-render.md — and takes ContactMask.patch like the floor it lies on, so the
// sofa and the chairs standing on it keep their contact shadow
class CorpRugs
{
  static inline var CELL = CityConfig.CELL;

// every rug on the plate as one mesh. returns how many were laid. With no area (the warm's demo
// model) every EXEC cell counts as rug, so the material still compiles its program
  public static function build(scene:Scene, m:Facility, ?area:game.AreaGame):Int
    {
      var b = MeshBufTools.make();
      var n = 0;
      // the warm's demo model has no rooms, so there the whole plate is one
      var rects = (area == null ? [{ x1: 0, y1: 0, x2: m.w - 1, y2: m.h - 1 }] :
        [for (r in m.rooms) { x1: r.x1, y1: r.y1, x2: r.x2, y2: r.y2 }]);
      for (r in rects)
        {
          var c0 = m.w, r0 = m.h, c1 = -1, r1 = -1;
          for (row in r.y1...r.y2 + 1)
            for (col in r.x1...r.x2 + 1)
              {
                if (!rug(m, area, col, row))
                  continue;
                if (col < c0)
                  c0 = col;
                if (col > c1)
                  c1 = col;
                if (row < r0)
                  r0 = row;
                if (row > r1)
                  r1 = row;
              }
          if (c1 < 0)
            continue;
          lay(b, c0, r0, c1, r1);
          n++;
        }
      if (b.idx.length == 0)
        return n;
      var mesh = new Mesh(FacilityGeom.geom(b), VisionMask.patch(ContactMask.patch(
        new MeshLambertMaterial({
          map: Textures.loadTexture(CorpStyle.RUG_TEX, 'wall', 1),
          alphaTest: CorpStyle.CLUTTER_CUT,
          side: THREE.DoubleSide,
        }))));
      mesh.name = 'corp rugs';
      mesh.receiveShadow = true;
      mesh.castShadow = false;
      scene.add(mesh);
      return n;
    }

// is this cell under a rug?
  static function rug(m:Facility, area:game.AreaGame, col:Int, row:Int):Bool
    {
      if (!FacilityModel.inside(m, col, row))
        return false;
      if (area == null)
        return m.surf[row][col] == Surf.EXEC;
      var t = area.getCellType(col, row);
      return t == Const.TILE_FLOOR_EXEC_RUG ||
        t == Const.TILE_FLOOR_EXEC_RUG + 16;
    }

// one rug over the cells c0..c1 x r0..r1: the biggest RUG_ASPECT oval that fits the rect less its
// inset, its long axis on the rect's
  static function lay(b:MeshBuf, c0:Int, r0:Int, c1:Int, r1:Int):Void
    {
      var w = (c1 - c0 + 1) * CELL - 2 * CorpStyle.RUG_INSET;
      var h = (r1 - r0 + 1) * CELL - 2 * CorpStyle.RUG_INSET;
      var alongX = (w >= h);
      var long = (alongX ? w : h);
      var short = (alongX ? h : w);
      if (long > short * CorpStyle.RUG_ASPECT)
        long = short * CorpStyle.RUG_ASPECT;
      else
        short = long / CorpStyle.RUG_ASPECT;
      var c = CityConfig.cellToWorld((c0 + c1) / 2, (r0 + r1) / 2);
      var hx = (alongX ? long : short) / 2;
      var hz = (alongX ? short : long) / 2;
      var x0 = c.x - hx, x1 = c.x + hx, z0 = c.z - hz, z1 = c.z + hz;
      var y = CorpStyle.RUG_Y;
      // the art's u runs along its long axis, so a rug lying down z takes its uv turned a quarter
      // CorpClutter.emit's corner order and winding, so the face looks UP
      var uv = (alongX ? [0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0] :
        [1.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0]);
      MeshBufTools.quad(b, [x0, y, z1], [x1, y, z1], [x1, y, z0], [x0, y, z0], uv);
    }
}

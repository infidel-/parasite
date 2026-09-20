package render.corp;

import three.Three;
import citygen.CityConfig;
import render.Textures;
import render.facility.FacilityGeom;
import render.facility.FacilityGeom.Rect;
import render.facility.FacilityModel;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityStyle;
import render.world.MeshBuf.MeshBuf;
import render.world.MeshBuf.MeshBufTools;

// the nineteen storeys UNDER the floor plate, and the soffit that closes it from below.
//
// THIS IS WHAT MAKES IT THE TWENTIETH FLOOR. Up to here a corp area was a floor plate sitting in
// the dark with a parapet round it: walk to the edge, look over, and there is nothing — no tower,
// and the plate's own underside open to the sky. Two merged meshes fix both, and neither costs a
// per-frame anything.
//
// UNLIT, WHICH IS THE ONE DECISION IN THE FILE. The facade is a MeshBasicMaterial and not the
// lambert every other shell surface here uses, because the plate's lighting rig has nothing to do
// with a wall 114 units below it: under the scene's ambient a lambert takes the art's lit window
// bays to nothing, which is the whole read gone. Unlit means the AUTHORED value is the RENDERED
// value, so the amber bays clear CorpStyle.BLOOM_THRESHOLD 0.72 on their own. It still takes the
// scene fog — a basic material is fogged like any other — and that is what makes the drop fade out
// with distance rather than stop at a line.
//
// AND NO VISION MASK ON EITHER, unlike everything on the plate: the mask's rim channel sinks a
// surface to the fog colour at the area border, and the border IS the tower's edge. Patched, the
// facade would be cut to nothing exactly where the player leans over the parapet to see it. It is
// outside the building in the sense the mask means, so it is simply never patched — the same rule
// the street below it follows.
class CorpFacade
{
  static inline var CELL = CityConfig.CELL;

  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// the tower below and the soffit under the plate. returns the two quad counts, for __corp()
  public static function build(scene:Scene, m:Facility):{ clad:Int, soffit:Int }
    {
      var clad = MeshBufTools.make();
      var soff = MeshBufTools.make();
      var half = (CityConfig.GRID * CELL) / 2;
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // the SOFFIT covers every cell of the building, masonry and floor alike: the underside
            // of a floor plate is one continuous slab and the walls stand on it. Per cell and not
            // one rect over the whole footprint, because a plate is not guaranteed rectangular —
            // the generator draws rings today and a flood fill that ever merged two footprints
            // would leave an L, and one rect over an L is a soffit hanging in the air
            var inb = FacilityModel.isIndoor(m, col, row) ||
              FacilityGeom.carries(m, col, row);
            if (!inb)
              continue;
            var x0 = col * CELL - half;
            var z0 = row * CELL - half;
            FacilityGeom.capDown(soff, x0, x0 + CELL, z0, z0 + CELL, CorpStyle.SOFFIT_Y,
              FacilityStyle.WALL_TILE);
            if (!FacilityGeom.carries(m, col, row))
              continue;
            // and the CLADDING drops off every outward face of the perimeter. `ring` is the
            // parapet's own plane and not the cell's masonry slab, for the parapet's own reason:
            // a glazed cell's slab is GLASS_T where its neighbours' are WALL_T, so a facade
            // following the slab would jog half a unit in and out at every window run's two ends.
            // Taking the ring plane puts the drop dead flush with the parapet band 6 units over it
            var r = ring(m, col, row, half);
            for (dir in 0...4)
              {
                if (!outward(m, col, row, dir))
                  continue;
                var alongX = (dir < 2);
                var p = alongX ? (dir == 0 ? r.z0 : r.z1) : (dir == 2 ? r.x0 : r.x1);
                if (alongX)
                  FacilityGeom.face(clad, r.x0, r.x1, p, p, dir, CorpStyle.STREET_Y, 0.0,
                    CorpStyle.FACADE_TILE);
                else
                  FacilityGeom.face(clad, p, p, r.z0, r.z1, dir, CorpStyle.STREET_Y, 0.0,
                    CorpStyle.FACADE_TILE);
              }
          }
      add(scene, clad, CorpStyle.FACADE_TEX);
      add(scene, soff, CorpStyle.CAP);
      return {
        clad: Std.int(clad.idx.length / 6),
        soffit: Std.int(soff.idx.length / 6),
      };
    }

// does this cell's `dir` face look OUT of the building? FacilityGeom's own `outward`, which is
// private there — three lines, and re-deriving them is cheaper than widening that file's surface
  static inline function outward(m:Facility, col:Int, row:Int, dir:Int):Bool
    {
      return FacilityGeom.carries(m, col, row) &&
        !FacilityGeom.carries(m, col + DC[dir], row + DR[dir]) &&
        !FacilityModel.isIndoor(m, col + DC[dir], row + DR[dir]);
    }

// the parapet's plane on this cell: the cell rect pulled in by PARAPET_INSET on every hand where
// the wall line stops. FacilityGeom.ringRect, which is private there for the same reason
  static function ring(m:Facility, col:Int, row:Int, half:Float):Rect
    {
      var e = FacilityStyle.PARAPET_INSET;
      var x0 = col * CELL - half;
      var z0 = row * CELL - half;
      return {
        x0: x0 + (FacilityGeom.carries(m, col - 1, row) ? 0.0 : e),
        x1: x0 + CELL - (FacilityGeom.carries(m, col + 1, row) ? 0.0 : e),
        z0: z0 + (FacilityGeom.carries(m, col, row - 1) ? 0.0 : e),
        z1: z0 + CELL - (FacilityGeom.carries(m, col, row + 1) ? 0.0 : e),
      };
    }

// one merged UNLIT mesh. nothing down here casts or receives: there is no moon over a tower's own
// flank and nothing below the plate to catch a shadow
  static function add(scene:Scene, b:MeshBuf, tex:String):Void
    {
      if (b.idx.length == 0)
        return;
      var mesh = new Mesh(FacilityGeom.geom(b), new MeshBasicMaterial({
        map: Textures.loadTexture(tex, 'wall', 1),
        side: THREE.FrontSide,
      }));
      mesh.receiveShadow = false;
      mesh.castShadow = false;
      scene.add(mesh);
    }
}

package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.VisionMask;

// the cars parked in the compound's lot, standing in the bays nearest the gate.
//
// A CAR IS THE ONE THING HERE THE SILHOUETTE-VS-SURFACE TEST SAYS YES TO WITHOUT ARGUMENT. the two
// pieces of furniture ten units away — the guard booth and the boom barrier — were both generated
// props and are both hand-modelled meshes now, because a kiosk is four clad faces and a boom is its
// hazard bands, and neither is carried by its outline (see the header of
// render.facility.FacilityEntry). a car is nothing BUT its outline: the roof line, the glasshouse
// taper, the wheel arches. there is no pattern on it a tiling texture could hold, and no way to
// state its shape as boxes.
//
// AND IT IS NO LONGER RENDER-ONLY, which is the one thing about this pass that changed. The bays,
// the ranking and the roll all used to live here and nothing was stamped, so a car was decoration
// the player walked straight through. gen.facility.FacilityBays deals them now and marks each one's
// whole footprint on the grid (Const.TILE_PARKING_CAR), so a car is solid; this pass stands a model
// on every ORIGIN mark it finds and derives nothing but the pose. A compound saved before that mark
// existed simply has no cars in it — savegames are scratch, and the alternative was keeping a second
// copy of the deal here to draw cars the game does not know about.
class FacilityCars
{
  static inline var CELL = CityConfig.CELL;
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering. `dir ^ 1` is the
  // opposite of a direction, which is how a bay marches away from the kerb it hangs off
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every car in the lot, one instanced batch. an empty batch costs nothing (render.Models.instanced
// returns before it loads anything), which is what a compound with no marks and one with no gate
// both come back as
  public static function build(scene:Scene, m:Facility):Models.InstancedProp
    {
      var places:Array<Models.PropPlace> = [];
      for (c in m.cars)
        {
          var p = pose(m, c.col, c.row);
          if (p != null)
            places.push(p);
        }
      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityCar, places,
        FacilityStyle.CAR_H, SOLID);
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityCar, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// where the car standing on this origin mark goes, or null if the mark has no pavement beside it any
// more — which a saved grid can always say and the generator never writes.
//
// THE MARK IS THE BAY'S LOW CORNER AGAINST THE KERB, so the kerb direction is the only thing to
// find: the bay runs BAY_SPACING cells along that kerb from here and BAY_CELLS away from it, which
// is the rect FacilityPaint.bayLine draws and the footprint FacilityStyle.CAR_H is sized for
  static function pose(m:Facility, col:Int, row:Int):Models.PropPlace
    {
      var dir = -1;
      for (d in 0...4)
        if (isSurf(m, col + DC[d], row + DR[d], Surf.WALKWAY))
          {
            dir = d;
            break;
          }
      if (dir < 0)
        return null;
      var ac = (dir < 2 ? 1 : 0);   // one step along the kerb
      var ar = (dir < 2 ? 0 : 1);
      var ic = DC[dir ^ 1];         // and one away from it, into the lot
      var ir = DR[dir ^ 1];
      // the bay's own centre: half a bay along the kerb and half a bay into the lot, off the cell its
      // leading divider is struck on
      var p = CityConfig.cellToWorld(col, row);
      var h = FacilityModel.mix((col * 68171) ^ (row * 3010349));
      return {
        x: p.x + (ac * (FacilityStyle.BAY_SPACING - 1) + ic * (FacilityStyle.BAY_CELLS - 1))
          * CELL / 2,
        z: p.z + (ar * (FacilityStyle.BAY_SPACING - 1) + ir * (FacilityStyle.BAY_CELLS - 1))
          * CELL / 2,
        // the glb lies along its own local z (see its note in art/models.json), so a bay whose depth
        // runs in z needs no turn at all and one whose depth runs in x takes a quarter — plus a half
        // turn on half of them, which is the only variety one model has left once a size spread is
        // out (a car park where the cars are visibly different sizes reads as broken)
        yaw: (dir < 2 ? 0.0 : Math.PI / 2) + (h % 2) * Math.PI,
        // the lot lies a kerb below the pavement, like everything else standing on the asphalt
        y: FacilityGround.surfY(Surf.LOT),
      };
    }

// does this cell hold that ground surface? false off the grid
  static inline function isSurf(m:Facility, col:Int, row:Int, s:Surf):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == s;
}

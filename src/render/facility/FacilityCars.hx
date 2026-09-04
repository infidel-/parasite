package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityEntry.Gate;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.VisionMask;

// one parking bay a car could stand in: where it would stand, which way it would lie, the cell the
// bay is opened on (so the two rolls below are stable), and how far the bay is from the gate
typedef Bay = {
  x:Float,
  z:Float,
  yaw:Float,
  col:Int,
  row:Int,
  d:Float,
};

// the cars parked in the compound's lot, standing in the bays nearest the gate.
//
// A CAR IS THE ONE THING HERE THE SILHOUETTE-VS-SURFACE TEST SAYS YES TO WITHOUT ARGUMENT. the two
// pieces of furniture ten units away — the guard booth and the boom barrier — were both generated
// props and are both merged geometry now, because a kiosk is four clad faces and a boom is its
// hazard bands, and neither is carried by its outline (see the header of
// render.facility.FacilityEntry). a car is nothing BUT its outline: the roof line, the glasshouse
// taper, the wheel arches. there is no pattern on it a tiling texture could hold, and no way to
// state its shape as boxes.
//
// RENDER-ONLY, like the booth and the barrier: nothing is stamped on the tiles, so a car is walked
// straight through and every compound already saved gets its cars the moment it is drawn again. the
// bays are not stored either — they fall back out of the tile grid the same way
// render.facility.FacilityPaint strikes the lines round them, off the same `runStart` phase, so the
// cars stand INSIDE the painted spots rather than beside them
class FacilityCars
{
  static inline var CELL = CityConfig.CELL;
  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering. `dir ^ 1` is the
  // opposite of a direction, which is how a bay marches away from the kerb it hangs off
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// every car in the lot, one instanced batch. no gate means no entry to park near, and an empty batch
// costs nothing (render.Models.instanced returns before it loads anything)
  public static function build(scene:Scene, m:Facility):Models.InstancedProp
    {
      var places:Array<Models.PropPlace> = [];
      var gate = FacilityEntry.find(m);
      if (gate != null)
        fill(m, gate, places);
      var prop = Models.instanced(scene, RenderConfig.MODELS.facilityCar, places,
        FacilityStyle.CAR_H, SOLID);
      if (places.length > 0)
        Models.get(RenderConfig.MODELS.facilityCar, function(_) VisionMask.patchMesh(prop.mesh));
      return prop;
    }

// pick the bays and fill them. NEAREST THE GATE FIRST, which is the whole placement rule: a compound
// deals dozens of bays and a lot parked solid reads as a showroom, while the spots by the barrier
// are the ones a camera following the player through the entry actually looks at
  static function fill(m:Facility, gate:Gate, places:Array<Models.PropPlace>):Void
    {
      var bays = spots(m, gate);
      bays.sort(function(a, b) return (a.d < b.d ? -1 : (a.d > b.d ? 1 : 0)));
      var n = 0;
      for (b in bays)
        {
          if (n >= FacilityStyle.CAR_COUNT)
            break;
          var h = FacilityModel.mix((b.col * 68171) ^ (b.row * 3010349));
          // one bay in CAR_EMPTY is left open. there is ONE car model, so a solid run of them is one
          // car repeated — the obituary render.facility.FacilityGround.GreenProp.scaleJit carries for
          // 163 identical bushes, and a size spread is not available here: a car park where the cars
          // are visibly different sizes reads as broken, the same reason the bench takes 0
          if (h % FacilityStyle.CAR_EMPTY == 0)
            continue;
          places.push({
            x: b.x,
            z: b.z,
            // and half of them park nose in. that is the only variety one glb has left once the size
            // spread is out, and it is free: the model is symmetric enough end to end that a half
            // turn reads as a different car rather than as the same one mirrored
            yaw: b.yaw + ((h >> 8) % 2) * Math.PI,
            // the lot lies a kerb below the pavement, like everything else standing on the asphalt
            y: FacilityGround.surfY(Surf.LOT),
          });
          n++;
        }
    }

// every whole bay in the lot, measured from the gate's mouth. the rhythm is FacilityPaint's own, read
// off the same `runStart`, so a car lands centred in a painted spot and never straddles a divider
  static function spots(m:Facility, gate:Gate):Array<Bay>
    {
      var g = CityConfig.cellToWorld(gate.col + (gate.w - 1) / 2, gate.mouthRow);
      var bays:Array<Bay> = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (m.surf[row][col] != Surf.LOT)
              continue;
            // the FIRST pavement this cell finds, so a cell in a corner belongs to one run only —
            // the same claim FacilityPaint makes when it stripes it
            for (dir in 0...4)
              {
                if (!isSurf(m, col + DC[dir], row + DR[dir], Surf.WALKWAY))
                  continue;
                if (((dir < 2 ? col : row) - FacilityPaint.runStart(m, col, row, dir))
                    % FacilityStyle.BAY_SPACING == 0)
                  {
                    var bay = spot(m, gate, col, row, dir, g);
                    if (bay != null)
                      bays.push(bay);
                  }
                break;
              }
          }
      return bays;
    }

// where a car stands in the bay this cell opens, or null if the bay is not whole open asphalt. the
// bay is BAY_SPACING cells along the kerb by BAY_CELLS deep — exactly the rect FacilityPaint.bayLine
// draws round — and every one of its cells has to be lot the player could have driven onto: the gate
// mouth is the way in and never a spot, and the booth stands on the one bay FacilityPaint already
// leaves unstriped for it
  static function spot(m:Facility, gate:Gate, col:Int, row:Int, dir:Int,
      g:{x:Float, z:Float}):Bay
    {
      var ac = (dir < 2 ? 1 : 0);   // one step along the kerb
      var ar = (dir < 2 ? 0 : 1);
      var ic = DC[dir ^ 1];         // and one away from it, into the lot
      var ir = DR[dir ^ 1];
      for (a in 0...FacilityStyle.BAY_SPACING)
        for (i in 0...FacilityStyle.BAY_CELLS)
          {
            var c = col + ac * a + ic * i;
            var r = row + ar * a + ir * i;
            if (!isSurf(m, c, r, Surf.LOT) ||
                FacilityPaint.isEntry(m, c, r) ||
                (c == gate.boothCol && r == gate.mouthRow))
              return null;
          }
      // the bay's own centre: half a bay along the kerb and half a bay into the lot, off the cell
      // its leading divider is struck on
      var p = CityConfig.cellToWorld(col, row);
      var x = p.x + (ac * (FacilityStyle.BAY_SPACING - 1) + ic * (FacilityStyle.BAY_CELLS - 1))
        * CELL / 2;
      var z = p.z + (ar * (FacilityStyle.BAY_SPACING - 1) + ir * (FacilityStyle.BAY_CELLS - 1))
        * CELL / 2;
      return {
        x: x,
        z: z,
        // the glb lies along its own local z (see its note in art/models.json), so a bay whose
        // depth runs in z needs no turn at all and one whose depth runs in x takes a quarter
        yaw: (dir < 2 ? 0.0 : Math.PI / 2),
        col: col,
        row: row,
        d: (x - g.x) * (x - g.x) + (z - g.z) * (z - g.z),
      };
    }

// does this cell hold that ground surface? false off the grid
  static inline function isSurf(m:Facility, col:Int, row:Int, s:Surf):Bool
    return FacilityModel.inside(m, col, row) && m.surf[row][col] == s;
}

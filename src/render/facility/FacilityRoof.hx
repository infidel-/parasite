package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityGeom.Shell;
import render.facility.FacilityModel.Facility;
import render.world.MeshBuf.MeshBufTools;

// one thing standing on a roof: where it is, what it is, and which structure's deck it stands on.
// the structure is what drives its visibility — see `mask` — and it is in __facility().roof because
// an instanced batch carries no userData.cls, so render.Debug.find cannot reach a condenser
typedef RoofProp = {
  col:Int,
  row:Int,
  kind:String,      // 'ac' | 'dish'
  structure:Int,
};

// the two instanced batches, what they stand on, and how many hatches were built
typedef Roof = {
  ac:Models.InstancedProp,
  dish:Models.InstancedProp,
  // index-aligned with each batch's own placements: which structure that instance stands on
  acOf:Array<Int>,
  dishOf:Array<Int>,
  props:Array<RoofProp>,
  hatches:Int,
};

// what stands on a facility building's roof: condenser units, one comms dish and one access hatch
// per building, inside the parapet.
//
// the CITY answers this question with top-down sprite decals (render.world.roofs.RoofDetails) and
// this deliberately does not: a decal is flat, and the facility's roofs are the one place in the
// game the camera looks down ONTO rather than past, so a condenser lying flat on the deck reads as a
// stain. two of these are real props and the third is merged geometry, which is the same
// silhouette-vs-surface split every other object in this compound was decided on (see the header of
// render.facility.FacilityEntry).
//
// RENDER-ONLY and derived, like the cars and the gate: nothing is stamped on the tiles, so every
// compound already saved grows its plant the moment it is drawn again.
//
// NO VISION MASK on any of it, and that is the roof's own rule rather than an oversight. the roof is
// the one surface whose visibility is decided by where the player STANDS and not by what they can
// see (FacilityGeom.structure's call to addDeck says why); a masked condenser over cells the LOS
// sweep never reached would sink to the fog colour while the deck under it stayed solid
class FacilityRoof
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// everything on every non-hangar roof. the hangar is skipped whole — its roofline is a job of its
// own and the parapet skips it for the same reason
  public static function build(scene:Scene, m:Facility, shells:Array<Shell>):Roof
    {
      var acPlaces:Array<Models.PropPlace> = [];
      var dishPlaces:Array<Models.PropPlace> = [];
      var out:Roof = {
        ac: null,
        dish: null,
        acOf: [],
        dishOf: [],
        props: [],
        hatches: 0,
      };
      for (si in 0...m.structures.length)
        {
          if (m.structures[si].hangar)
            continue;
          // the hatch housing rides the structure's OWN buffer so it can be pushed into Shell.roof
          // and fade with the deck it stands on
          var hatch = MeshBufTools.make();
          fill(m, si, acPlaces, dishPlaces, hatch, out);
          if (hatch.idx.length > 0)
            {
              FacilityGeom.addDeck(scene, hatch, FacilityStyle.COPING, true, shells[si]);
              out.hatches++;
            }
        }
      out.ac = Models.instanced(scene, RenderConfig.MODELS.facilityRoofAc, acPlaces,
        FacilityStyle.ROOF_AC_H, SOLID);
      out.dish = Models.instanced(scene, RenderConfig.MODELS.facilityRoofDish, dishPlaces,
        FacilityStyle.ROOF_DISH_H, SOLID);
      return out;
    }

// one building's roof. the candidates are picked first and the assignment runs over that list, so
// the hatch can take the one nearest the middle without a second pass over the grid
  static function fill(m:Facility, si:Int, acPlaces:Array<Models.PropPlace>,
      dishPlaces:Array<Models.PropPlace>, hatch:render.world.MeshBuf.MeshBuf, out:Roof):Void
    {
      var st = m.structures[si];
      var cand = candidates(m, si);
      if (cand.length == 0)
        return;
      // thin the list to what one roof should carry, by a STRIDE over the whole of it and not by
      // taking the first N. the scan is row-major, so a cap alone spends a big roof's entire
      // allowance on its first two rows: measured on the 31x24 building, all seven objects came
      // back at rows 8 and 9 and the rest of the deck was bare
      var step = Std.int(Math.ceil(cand.length / (FacilityStyle.ROOF_PROP_MAX + 2)));
      if (step > 1)
        cand = [for (i in 0...cand.length) if (i % step == 0) cand[i]];
      // the hatch goes nearest the middle of the roof, where a stair core comes up
      var cx = (st.x1 + st.x2) / 2.0;
      var cy = (st.y1 + st.y2) / 2.0;
      var mid = 0;
      var best = 1e9;
      for (i in 0...cand.length)
        {
          var dx = cand[i].col - cx;
          var dy = cand[i].row - cy;
          if (dx * dx + dy * dy < best)
            {
              best = dx * dx + dy * dy;
              mid = i;
            }
        }
      var dishDone = false;
      for (i in 0...cand.length)
        {
          var col = cand[i].col;
          var row = cand[i].row;
          var h = FacilityModel.mix((col * 70001) ^ (row * 30011));
          var c = CityConfig.cellToWorld(col, row);
          if (i == mid)
            {
              box(hatch, c.x, c.z, h);
              continue;
            }
          // ONE dish per building. it is the roof's silhouette, and two of them read as a repeated
          // prop rather than as the thing this building has on it
          if (h % 3 == 2 &&
              !dishDone)
            {
              dishDone = true;
              dishPlaces.push({
                x: c.x,
                z: c.z,
                yaw: (h >> 8) % 6283 / 1000.0,
                y: FacilityStyle.ROOF_Y,
              });
              out.dishOf.push(si);
              out.props.push({ col: col, row: row, kind: 'dish', structure: si });
              continue;
            }
          acPlaces.push({
            x: c.x,
            z: c.z,
            // a quarter turn and not a free one: a condenser is a manufactured box and stands
            // square to the building, exactly as the parked cars do
            yaw: ((h >> 8) % 4) * (Math.PI / 2),
            y: FacilityStyle.ROOF_Y,
          });
          out.acOf.push(si);
          out.props.push({ col: col, row: row, kind: 'ac', structure: si });
        }
    }

// the cells of this structure's roof something may stand on: interior floor whose four neighbours
// are ALSO this structure's interior floor, thinned to one cell in ROOF_PROP_STEP.
//
// the neighbour test is what keeps everything clear of the wall ring, so nothing can foul the
// parapet standing on it, and it means a prop is always over solid deck rather than over the rim
  static function candidates(m:Facility, si:Int):Array<{ col:Int, row:Int }>
    {
      var st = m.structures[si];
      var out = [];
      for (row in st.y1...st.y2 + 1)
        for (col in st.x1...st.x2 + 1)
          {
            if (!owns(m, si, col, row) ||
                (col * 3 + row) % FacilityStyle.ROOF_PROP_STEP != 0)
              continue;
            var clear = true;
            for (dir in 0...4)
              if (!owns(m, si, col + DC[dir], row + DR[dir]))
                {
                  clear = false;
                  break;
                }
            if (clear)
              out.push({ col: col, row: row });
          }
      return out;
    }

// is this cell this structure's own indoor floor?
  static inline function owns(m:Facility, si:Int, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.owner[row][col] == si &&
        FacilityModel.isIndoor(m, col, row);
    }

// the access hatch housing: four clad faces and a lid, standing on the deck. `h` turns it a quarter
// by swapping its two plan dimensions, which is the whole of a yaw for an axis-aligned box.
//
// no underside. it stands ON the deck, and the mesh it goes into does not cast (see addDeck), so
// there is no ray to leak through the bottom the way the guard booth's roof slab had
  static function box(b:render.world.MeshBuf.MeshBuf, x:Float, z:Float, h:Int):Void
    {
      var turn = (h % 2 == 0);
      var w = (turn ? FacilityStyle.HATCH_W : FacilityStyle.HATCH_D) / 2;
      var d = (turn ? FacilityStyle.HATCH_D : FacilityStyle.HATCH_W) / 2;
      var y1 = FacilityStyle.ROOF_Y + FacilityStyle.HATCH_H;
      for (dir in 0...4)
        FacilityGeom.face(b, x - w, x + w, z - d, z + d, dir, FacilityStyle.ROOF_Y, y1,
          FacilityStyle.COPING_TILE);
      FacilityGeom.cap(b, x - w, x + w, z - d, z + d, y1, FacilityStyle.COPING_TILE);
    }

// which instances may draw this frame: an instance goes when the deck it stands on has faded far
// enough that it would be left hanging in the air.
//
// a hard cut and not a fade — the roof takes REVEAL_MULT * BASE_MS to go, so a prop pops partway
// through it. cross-fading an InstancedMesh needs a per-instance alpha attribute and its own shader
// patch, which is a lot of machinery for a prop the player is walking under at the time
// (ponytail: add it if the pop reads badly)
  public static function mask(of:Array<Int>, reveal:Array<Float>):Array<Bool>
    {
      return [for (si in of) reveal[si] < 0.5];
    }
}

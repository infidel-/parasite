package render.facility;

import Const;
import three.Three;
import citygen.CityConfig;
import citygen.CityGen;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.Debris;
import render.world.Debris.DebrisSpot;
import render.world.VisionMask;

// one kind of standing junk and the model that draws it
typedef LotProp = {
  // RenderConfig.MODELS entry
  path:String,
  // world height, and with it the width: render.Models.instanced scales by HEIGHT alone
  h:Float,
};

// what is lying about in the compound's parking lot: ground litter, and junk standing on it.
//
// TWO PASSES OVER ONE SURFACE and neither is the other's fallback. the litter is flat sprite decals
// on the shared render.decals.DecalBatch, so it costs NO draw call and can cover the whole lot; but
// the atlas rows it draws from are the only alpha-capped block in entities64 (Const.STREET_DEBRIS_*
// peak at 127 where every other row peaks at 255), so it draws at ~43% opacity and can never read as
// more than scraps. the standing props are three real glbs at one batch each, which is what actually
// reads at a camera pitched 51 degrees down onto asphalt.
//
// BOTH ARE RENDER-ONLY AND UNSTAMPED, the contract render.facility.FacilityCars and
// render.facility.FacilityRoof already run on: nothing is written to the tiles, so a piece of litter
// is walked straight through and every compound already saved gets all of it the moment it is drawn
// again. named FacilityDebris so it never shadows render.world.Debris at an import, which is the
// convention render.sewer.SewerDebris and render.wild.WildDebris set
class FacilityDebris
{
  static inline var CELL = CityConfig.CELL;
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the junk that stands up. all three are DROPPED objects rather than placed ones, which is why
  // none of them takes the quarter-turn the parked cars and the roof condensers do — see `place`
  public static final PROPS:Array<LotProp> = [
    {
      path: (FacilityStyle.LOT_BLENDER ?
        RenderConfig.MODELS.facilityLotConeHand : RenderConfig.MODELS.facilityLotCone),
      h: FacilityStyle.LOT_CONE_H,
    },
    // the TYRE STACK IS THE ONE PROP IN THIS FAMILY THAT STAYS GENERATED, and it is not an
    // oversight: it is the only glb in the whole compound that PASSES its own propstat gate at 1
    // component / 100%, and three touching toroids with real see-through holes is a silhouette a
    // (radius, z) lathe would have to fake rather than state
    {
      path: RenderConfig.MODELS.facilityLotTyres,
      h: FacilityStyle.LOT_TYRES_H,
    },
    {
      path: (FacilityStyle.LOT_BLENDER ?
        RenderConfig.MODELS.facilityLotReelHand : RenderConfig.MODELS.facilityLotReel),
      h: FacilityStyle.LOT_REEL_H,
    },
  ];

// the ground litter, as render-only decal spots. the shape render.wild.WildDebris arrived at, with
// its distance falloff replaced by an EDGE test — see FacilityStyle.LITTER_EDGE_PCT
  public static function build(m:Facility):Array<DebrisSpot>
    {
      var spots:Array<DebrisSpot> = [];
      // litter lands on the asphalt and nowhere else. the GATEWAY is cut out of it because that is
      // the one stretch of lot the compound keeps clear — nothing else is struck or stood there
      // either (render.facility.FacilityPaint.isEntry, FacilityCars.spot)
      var ok = function(col:Int, row:Int):Bool
        {
          return isLot(m, col, row) &&
            !FacilityPaint.isEntry(m, col, row);
        };
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!ok(col, row))
              continue;
            var h = FacilityModel.mix((col * 15485863) ^ (row * 32452843));
            var chance = (edge(m, col, row)
              ? FacilityStyle.LITTER_EDGE_PCT : FacilityStyle.LITTER_PCT);
            if (h % 1000 >= chance * 1000)
              continue;
            var rng = CityGen.mulberry32(h);
            if (rng() < 0.35)
              Debris.spawnCluster(spots, ok, col, row, 1 + Std.int(rng() * 2), rng);
            else
              Debris.addFragment(spots, col, row, Const.STREET_DEBRIS_STATIC, false, rng, ok);
          }
      dress(spots);
      return spots;
    }

// the same two fixes render.sewer.SewerDebris and render.wild.WildDebris both make to the shared
// placer, and for the same reasons — a cluster fragment can roll a scale too small to see, and a
// STATIC fragment comes back with no offset and no rotation at all, which reads as a grid. kept
// local rather than pushed into render.world.Debris because that one is the city's too and is
// already at 7 positional args
  static function dress(spots:Array<DebrisSpot>):Void
    {
      for (s in spots)
        {
          if (s.scale < FacilityStyle.LITTER_MIN_SCALE)
            s.scale = FacilityStyle.LITTER_MIN_SCALE;
          if (s.dx == 0.0 &&
              s.dy == 0.0 &&
              s.angle == 0.0)
            {
              var h = FacilityModel.mix((s.col * 49979687) ^ (s.row * 86028121));
              s.dx = ((h % 1000) / 1000 - 0.5) * 2 * FacilityStyle.LITTER_JITTER;
              s.dy = (((h >>> 10) % 1000) / 1000 - 0.5) * 2 * FacilityStyle.LITTER_JITTER;
              s.angle = ((h >>> 20) % 628) / 100;
            }
        }
    }

// the standing junk, one instanced batch per model, index-aligned with PROPS
  public static function props(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var places = [for (_ in PROPS) new Array<Models.PropPlace>()];
      place(m, places);
      var out = [];
      for (i in 0...PROPS.length)
        {
          var p = Models.instanced(scene, PROPS[i].path, places[i], PROPS[i].h, SOLID);
          out.push(p);
          // behind the loader callback, because the mesh does not exist until the glb resolves —
          // and only for a batch that placed something, or an empty one is patched for nothing
          if (places[i].length > 0)
            Models.get(PROPS[i].path, function(_) VisionMask.patchMesh(p.mesh));
        }
      return out;
    }

// pick the cells and fill them. junk collects where something STOPS it, so a candidate is a lot cell
// against an edge — a kerb, a wall, the park railing — rather than any cell at all: a drum standing
// in the middle of an open aisle reads as placed, and one against the hangar wall reads as left
  static function place(m:Facility, places:Array<Array<Models.PropPlace>>):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var cand = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            if (!isLot(m, col, row) ||
                FacilityPaint.isEntry(m, col, row) ||
                !edge(m, col, row) ||
                (col * 3 + row) % FacilityStyle.LOT_PROP_STEP != 0)
              continue;
            cand.push({ col: col, row: row });
          }
      // thin by a STRIDE over the whole list and not by capping a counter: the scan is row-major, so
      // a cap spends the lot's entire allowance along its northern kerb (FacilityRoof.fill measured
      // exactly that on a roof — all seven objects on two adjacent rows)
      var step = Std.int(Math.ceil(cand.length / FacilityStyle.LOT_PROP_MAX));
      if (step > 1)
        cand = [for (i in 0...cand.length) if (i % step == 0) cand[i]];
      for (c in cand)
        {
          var h = FacilityModel.mix((c.col * 27644437) ^ (c.row * 67867979));
          places[h % PROPS.length].push({
            x: (c.col + 0.5) * CELL - half,
            z: (c.row + 0.5) * CELL - half,
            // a FREE turn, where the parked cars and the roof condensers both take a quarter. those
            // are manufactured objects standing square to something; a cone knocked over by a wheel
            // and a drum rolled against a wall are dropped, and dropped things lie any way up
            yaw: ((h >> 8) % 6283) / 1000.0,
            // the lot lies a kerb below the pavement, like everything else standing on the asphalt
            y: FacilityGround.surfY(Surf.LOT),
          });
        }
    }

// is this cell asphalt the compound would let junk lie on?
  static inline function isLot(m:Facility, col:Int, row:Int):Bool
    {
      return FacilityModel.inside(m, col, row) &&
        m.surf[row][col] == Surf.LOT;
    }

// does this lot cell back onto something — a kerb, a wall, the park railing, the area border?
  static function edge(m:Facility, col:Int, row:Int):Bool
    {
      for (dir in 0...4)
        if (!isLot(m, col + DC[dir], row + DR[dir]))
          return true;
      return false;
    }
}

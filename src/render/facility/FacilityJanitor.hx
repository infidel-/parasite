package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityKit.KitProp;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.VisionMask;

// the cleaner's kit left standing in a CORRIDOR or a WASHROOM: a broom and a mop bucket.
//
// RENDER-ONLY AND UNSTAMPED, the contract render.facility.FacilityKit, FacilityCars, FacilityDebris
// and the indoor litter bins all run on — nothing is written to the tiles, so neither prop needs a
// _FittingKind, an entities64 frame, a Const.FACILITY_DECO row or a generator call site, an actor
// walks straight through one, and every compound already in a save gets them the moment it is drawn
// again. That matters more here than for the lab kit: the generator places NOTHING in a corridor at
// all (the deco grid is stamped inside _Rooms only), so a fitting could not have reached half of
// what this pass is for.
//
// AND IT IS THE OTHER HALF OF THE WASHROOM'S CLUTTER. gen.blocks.RoomBlock.slot used to fill a
// washroom's leftover bays out of the LABORATORY's block list, which is how a compound came back
// with a bank of machines next to the cubicles; that arm places nothing now, and what a washroom
// gets instead is this pair plus the bin FacilityGround.indoorBins stands in its corner.
//
// Surf.LINO AND Surf.WASH, and the two never collide with the lab kit: FacilityKit is gated on
// Surf.TILE, so the compound's interior divides between them by surface with no shared list and no
// ordering between builders — the same discipline FacilityKit's own header sets out
class FacilityJanitor
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // both meshes are built AT world size with their backs at +y, which glTF's y-up export puts at +z
  // — the hand FacilityKit's `yaw0` exists to correct on a TRELLIS bake and a hand-modelled prop
  // simply holds, so neither needs a turn of its own
  public static final PROPS:Array<KitProp> = [
    {
      path: RenderConfig.MODELS.facilityBroom,
      h: FacilityStyle.JAN_BROOM_H,
      d: FacilityStyle.JAN_BROOM_D,
      w: FacilityStyle.JAN_BROOM_W,
      yaw0: 0.0,
      jit: 0.0,
    },
    {
      path: RenderConfig.MODELS.facilityBucket,
      h: FacilityStyle.JAN_BUCKET_H,
      d: FacilityStyle.JAN_BUCKET_D,
      w: FacilityStyle.JAN_BUCKET_W,
      yaw0: 0.0,
      jit: 0.0,
    },
  ];

// one instanced batch per model, index-aligned with PROPS
  public static function props(scene:Scene, m:Facility):Array<Models.InstancedProp>
    {
      var places = [for (_ in PROPS) new Array<Models.PropPlace>()];
      place(m, places);
      var out = [];
      for (i in 0...PROPS.length)
        {
          var p = Models.instanced(scene, PROPS[i].path, places[i], PROPS[i].h, SOLID);
          out.push(p);
          if (places[i].length > 0)
            Models.get(PROPS[i].path, function(_)
              {
                VisionMask.patchMesh(p.mesh);
                render.world.PropEnv.apply(p.mesh.material);
                // NOT CASTING, the indoor bins' and the lab kit's own finding: an instanced batch is
                // drawn into the moon's shadow map as many times as into the frame, and these stand
                // under a roof that fades before the player can see either of them
                p.mesh.castShadow = false;
              });
        }
      return out;
    }

// pick the cells and fill them
  static function place(m:Facility, places:Array<Array<Models.PropPlace>>):Void
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var cand = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var dir = wall(m, col, row);
            // THE LATTICE HAS TO BE COPRIME WITH THE STEP or it is not a lattice: `col * 5` under a
            // step of 5 is 0 for every column, so the first cut selected whole ROWS of a corridor and
            // missed every cell of the ones between. 3 and 2 against 5 walk the grid diagonally, the
            // same shape FacilityKit.place's own (col * 3 + row) takes
            if (dir < 0 ||
                (col * 3 + row * 2) % FacilityStyle.JAN_STEP != 0)
              continue;
            cand.push({
              col: col,
              row: row,
              dir: dir,
            });
          }
      // strided down over the WHOLE list rather than capped by a counter — the scan is row-major, so
      // a cap spends the whole allowance on the northernmost corridor (FacilityKit.place's own note)
      var step = Std.int(Math.ceil(cand.length / FacilityStyle.JAN_MAX));
      if (step > 1)
        cand = [for (i in 0...cand.length) if (i % step == 0) cand[i]];
      for (c in cand)
        {
          var h = FacilityModel.mix((c.col * 990395017) ^ (c.row * 340573321));
          var i = h % PROPS.length;
          var p = PROPS[i];
          // off the WALL FACE and not off the cell, which is a unit away: FacilityGeom.slab insets a
          // straight run, so the floor carries on under the masonry's overhang
          var s = FacilityGeom.slab(m, c.col + DC[c.dir], c.row + DR[c.dir]);
          var off = p.d / 2 + FacilityStyle.JAN_GAP;
          var px = (c.dir == 2 ? s.x1 + off :
            (c.dir == 3 ? s.x0 - off : (c.col + 0.5) * CELL - half));
          var pz = (c.dir == 0 ? s.z1 + off :
            (c.dir == 1 ? s.z0 - off : (c.row + 0.5) * CELL - half));
          places[i].push({
            x: px,
            z: pz,
            // back to the wall, which aims the prop's front at the opposite hand of the same axis.
            // THE BROOM'S LEAN IS BUILT INTO ITS MESH and leans toward its own +z, so this one turn
            // both faces it and stands it against the masonry
            yaw: p.yaw0 + Math.atan2(DC[c.dir ^ 1], DR[c.dir ^ 1]),
            y: FacilityGround.surfY(m.surf[c.row][c.col]),
          });
          // the floor pool under it: width along the wall, depth across it
          var pw = (c.dir < 2 ? p.w : p.d) / 2;
          var pd = (c.dir < 2 ? p.d : p.w) / 2;
          ContactMask.prop(px - pw, px + pw, pz - pd, pz + pd);
          // and the shadow on the wall behind, which the top-down field cannot reach
          FacilityDetail.stand({
            col: c.col,
            row: c.row,
            dir: c.dir,
            a0: (c.dir < 2 ? px : pz) - p.w / 2,
            a1: (c.dir < 2 ? px : pz) + p.w / 2,
            len: 1,
            y: FacilityGround.surfY(m.surf[c.row][c.col]),
            h: p.h,
          });
        }
    }

// may a broom stand on this cell, and against which wall?
//
// the same three refusals FacilityKit.wall makes — one fitting to a tile, nothing on a worktop and
// nothing beside a doorway — plus the surface test that divides the compound's interior between the
// two passes. The wall line also has to RUN ON past the cell both ways, or FacilityGeom.slab insets
// that face by a unit and the prop stands off the end of the wall it is leaning on
  static function wall(m:Facility, col:Int, row:Int):Int
    {
      if (!FacilityModel.inside(m, col, row) ||
          (m.surf[row][col] != Surf.LINO &&
           m.surf[row][col] != Surf.WASH) ||
          FacilityModel.isTable(m, col, row) ||
          FacilityModel.isFitting(m, col, row) ||
          FacilityModel.nearDoor(m, col, row))
        return -1;
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.isSolidWall(m, c, r))
            continue;
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          if (FacilityGeom.carries(m, c - sc, r - sr) &&
              FacilityGeom.carries(m, c + sc, r + sr))
            return dir;
        }
      return -1;
    }
}

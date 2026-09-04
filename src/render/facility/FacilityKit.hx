package render.facility;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.RenderConfig;
import render.facility.FacilityModel.Facility;
import render.facility.FacilityModel.Surf;
import render.world.ContactMask;
import render.world.VisionMask;

// one kind of lab kit and the model that draws it
typedef KitProp = {
  // RenderConfig.MODELS entry
  path:String,
  // world height, and with it the width: render.Models.instanced scales by HEIGHT alone
  h:Float,
  // and its depth ACROSS the wall it stands against, world units
  d:Float,
  // and its width ALONG that wall — the other half of the footprint the contact field darkens
  w:Float,
  // the turn that puts THIS glb's back at local -z, radians. it is per model and not a constant
  // because TRELLIS does not hold orientation across runs — the amber rack came back with its frame
  // at +z where the grey bake it replaced had it at -z, off the same reference composition
  yaw0:Float,
  // a free turn either side of square, radians. 0 for a thing that is bolted down
  jit:Float,
};

// the lab kit standing about in the ROOMS: a gas cylinder rack and a two-shelf trolley.
//
// ROOMS AND NOT CORRIDORS, and that is not a taste call — it is what keeps this pass from having to
// know about any other. The corridor already carries three families and every one of them is gated
// on Surf.LINO (the casework in render.facility.FacilityTables, the dead-end bins in
// FacilityGround.indoorBins, the directional signs in FacilityExit), so a pass gated on Surf.TILE
// cannot collide with any of them however they are tuned later. No shared claimed-cell list, no
// ordering between builders, nothing to keep in step.
//
// It is also where the objects belong: a compressed-gas rack and a trolley are LABORATORY kit, and
// the generator furnishes a room with benches under its window wall and leaves every other wall in
// it bare.
//
// WALL-HUGGING, like every standing prop indoors: an actor may clip one only by walking into a wall,
// never by walking down the middle of a room. The placement is taken off FacilityGeom.slab's own
// face and not off the cell boundary, which is a unit away — the trap the corridor casework records
// (FacilityTables.unit) and the litter bins take the same way out.
//
// RENDER-ONLY AND UNSTAMPED, the contract render.facility.FacilityCars, FacilityDebris and the
// indoor bins all run on: nothing is written to the tiles, so a rack is walked straight through and
// every compound already saved gets its kit the moment it is drawn again
class FacilityKit
{
  static inline var CELL = CityConfig.CELL;

  // the four cell-edge directions, in render.facility.FacilityGeom's own numbering:
  // 0 = -z, 1 = +z, 2 = -x, 3 = +x
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // both props run long in local x, and `yaw0` is which way round each one's BACK faces — measured
  // off each built mesh by binning triangle area along the axes rather than read off the reference.
  // see the notes in models-src/models.json
  public static final PROPS:Array<KitProp> = [
    {
      path: RenderConfig.MODELS.facilityKitGas,
      h: FacilityStyle.KIT_GAS_H,
      d: FacilityStyle.KIT_GAS_D,
      w: FacilityStyle.KIT_GAS_W,
      yaw0: Math.PI,
      jit: 0.0,
    },
    {
      path: RenderConfig.MODELS.facilityKitTrolley,
      h: FacilityStyle.KIT_TROLLEY_H,
      d: FacilityStyle.KIT_TROLLEY_D,
      w: FacilityStyle.KIT_TROLLEY_W,
      yaw0: 0.0,
      jit: FacilityStyle.KIT_YAW_JIT,
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
          // behind the loader callback, because the mesh does not exist until the glb resolves — and
          // only for a batch that placed something, or an empty one is patched for nothing
          if (places[i].length > 0)
            Models.get(PROPS[i].path, function(_)
              {
                VisionMask.patchMesh(p.mesh);
                // and the room, for the metal to reflect. a no-op unless the prop stayed
                // MeshStandard, which is the `roughness` key in models.json — see PropEnv's header
                // for why that number is unsafe to set without this call beside it
                render.world.PropEnv.apply(p.mesh.material);
                // and NEITHER BATCH CASTS, which is the indoor litter bin's own finding (see
                // FacilityGround.bins): an instanced batch is drawn into the moon's shadow map as
                // many times as it is drawn into the frame, so the second draw is a second call the
                // moment the batch is in view at all — and these two stand under a roof that fades
                // off before the player can see either of them
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
            if (dir < 0 ||
                (col * 3 + row) % FacilityStyle.KIT_STEP != 0)
              continue;
            cand.push({
              col: col,
              row: row,
              dir: dir,
            });
          }
      // thin by a STRIDE over the whole list and not by capping a counter, for the reason
      // FacilityDebris.place and FacilityRoof.fill both record: the scan is row-major, so a cap
      // spends the whole allowance on the northernmost rooms
      var step = Std.int(Math.ceil(cand.length / FacilityStyle.KIT_MAX));
      if (step > 1)
        cand = [for (i in 0...cand.length) if (i % step == 0) cand[i]];
      for (c in cand)
        {
          var h = FacilityModel.mix((c.col * 179424673) ^ (c.row * 512927377));
          var i = h % PROPS.length;
          var p = PROPS[i];
          // off the WALL FACE, and the prop's centre half its own depth clear of it
          var s = FacilityGeom.slab(m, c.col + DC[c.dir], c.row + DR[c.dir]);
          var off = p.d / 2 + FacilityStyle.KIT_GAP;
          var px = (c.dir == 2 ? s.x1 + off :
            (c.dir == 3 ? s.x0 - off : (c.col + 0.5) * CELL - half));
          var pz = (c.dir == 0 ? s.z1 + off :
            (c.dir == 1 ? s.z0 - off : (c.row + 0.5) * CELL - half));
          places[i].push({
            x: px,
            z: pz,
            // the turn that puts a back to the wall aims the prop's front at the OPPOSITE hand of
            // the same axis — dir ^ 1 — the same atan2(DC, DR) shape the bins face their mouth out
            // of a corner with, plus whatever `yaw0` this particular bake needs to face front at all
            yaw: p.yaw0 + Math.atan2(DC[c.dir ^ 1], DR[c.dir ^ 1]) +
              (((h >>> 8) % 1000) / 1000 - 0.5) * 2 * p.jit,
            y: FacilityGround.surfY(Surf.TILE),
          });
          // the floor pool under it. width runs ALONG the wall and depth across it, so which of the
          // two lands on x is what `dir` says. THE YAW JITTER IS IGNORED here on purpose: it is
          // KIT_YAW_JIT 0.18 rad, which grows a trolley's axis-aligned box by 0.16 units at the
          // worst corner, and the field is blurred over 0.7 — the correction is a quarter of the
          // ramp it would be applied to
          var pw = (c.dir < 2 ? p.w : p.d) / 2;
          var pd = (c.dir < 2 ? p.d : p.w) / 2;
          ContactMask.prop(px - pw, px + pw, pz - pd, pz + pd);
        }
    }

// may a piece of kit stand on this room cell, and against which wall? the first hand that answers is
// taken: a cell with walls on two hands is a room corner, and either face stands the prop in the
// same corner
  static function wall(m:Facility, col:Int, row:Int):Int
    {
      if (!FacilityModel.inside(m, col, row) ||
          m.surf[row][col] != Surf.TILE ||
          FacilityModel.isTable(m, col, row) ||
          FacilityModel.nearDoor(m, col, row))
        return -1;
      for (dir in 0...4)
        {
          var c = col + DC[dir];
          var r = row + DR[dir];
          if (!FacilityModel.isSolidWall(m, c, r))
            continue;
          // and the wall line has to RUN ON past this cell BOTH ways, or FacilityGeom.slab insets
          // that face by a unit and a 3-unit rack hangs off the end of the wall it is standing
          // against. the corridor casework hit this from the other side and answered it by clamping
          // its run to the slab; a prop cannot be clamped, so the cell is rejected instead
          var sc = (dir < 2 ? 1 : 0);
          var sr = (dir < 2 ? 0 : 1);
          if (FacilityGeom.carries(m, c - sc, r - sr) &&
              FacilityGeom.carries(m, c + sc, r + sr))
            return dir;
        }
      return -1;
    }
}

package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.sewer.SewerModel.Sewer;

// 3D clutter heaped against the tunnel walls — the first CONVEX geometry underground. everything
// else down here is the shell itself (a concave box: a corridor cannot block its own light) or a
// flat decal, which is why a wall bracket aimed along the walkway had nothing to throw a shadow off.
//
// placement is per 2x2 BLOCK against a wall FACE, the idiom SewerLamps explains at length: an
// independent per-cell coin flip deals visible runs, one prop per block caps a run at two by
// construction, and multiplying the gate by the eligible face count keeps per-FACE density at
// PILE_PCT whether the block is a corner or an open hall. hugging a wall is also what keeps the
// walkway clear — the player never has to walk through one.
//
// pure decoration: no AreaObject behind it, so unlike the exit ladder (render.world.ObjModels)
// there is no ghost twin, no tactical outline hull and nothing per-frame
class SewerPiles
{
  static inline var CELL = CityConfig.CELL;

  // cell offsets of the neighbour a wall face looks at, matching SewerGeom.side's four directions
  // (0 = north edge, 1 = south, 2 = west, 3 = east)
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

// scatter, then batch: one InstancedMesh per model, so the whole level pays one draw call per pile
// variant however many it places
  public static function build(scene:Scene, m:Sewer):Void
    {
      var models = SewerStyle.PILE_MODELS;
      var places = places(m);
      // ponytail: no per-frame Models.cull. instanced() turns three's own frustum cull off, so each
      // batch draws its whole list every frame — for a dozen static piles that is one constant call
      // per variant, against a repack that could never take a batch below one call anyway. if a
      // tunnel ever gets big enough for that to matter, Models.cull is one line from SewerArea.tick
      for (i in 0...models.length)
        Models.instanced(scene, models[i], places[i], SewerStyle.PILE_H, SOLID);
    }

// the scatter itself: one placement list per PILE_MODELS entry. split out of build so a layout can
// be read without a scene — parasiteHx['render.sewer.SewerPiles'].places(SewerModel.demo())
  public static function places(m:Sewer):Array<Array<{ x:Float, z:Float, yaw:Float }>>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var models = SewerStyle.PILE_MODELS;
      var places:Array<Array<{ x:Float, z:Float, yaw:Float }>> = [for (_ in models) []];
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            // multipliers of its own, mixed: the raw hash combs the always-solid area border (see
            // SewerModel.mix), and these must not correlate with the wall-variant, decal, ledge,
            // floor-decal, wall-lamp or litter rolls
            var hh = SewerModel.mix((bc * 40503151) ^ (br * 57885161));
            var faces = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (col >= m.w ||
                      row >= m.h ||
                      !m.floor[row][col] ||
                      nearExit(m, col, row))
                    continue;
                  for (dir in 0...4)
                    if (!SewerModel.isFloor(m, col + DC[dir], row + DR[dir]))
                      faces.push({ col: col, row: row, dir: dir });
                }
            if (faces.length == 0)
              continue;
            if (hh % 100 >= SewerStyle.PILE_PCT * faces.length)
              continue;
            var f = faces[(hh >> 7) % faces.length];

            // the wall plane point + the normal pointing INTO the floor cell, matching SewerGeom.side.
            // the yaw is the face's outward facing, so a pile's authored front looks down the corridor
            var x0 = f.col * CELL - half;
            var z0 = f.row * CELL - half;
            var px = x0 + CELL / 2, pz = z0 + CELL / 2;
            var nx = 0.0, nz = 0.0, yaw = 0.0;
            switch (f.dir)
              {
                case 0:
                  pz = z0;
                  nz = 1;
                  yaw = 0;
                case 1:
                  pz = z0 + CELL;
                  nz = -1;
                  yaw = Math.PI;
                case 2:
                  px = x0;
                  nx = 1;
                  yaw = Math.PI / 2;
                default:
                  px = x0 + CELL;
                  nx = -1;
                  yaw = -Math.PI / 2;
              }
            // a separate mixed word for the variant and the wobble, so which model a block takes does
            // not correlate with which of its faces took it
            var h2 = SewerModel.mix(hh ^ 0x85EBCA6B);
            var jit = (((h2 >> 3) % 2001) / 1000.0 - 1.0) * SewerStyle.PILE_YAW_JITTER;
            places[h2 % models.length].push({
              x: px + nx * SewerStyle.PILE_MARGIN,
              z: pz + nz * SewerStyle.PILE_MARGIN,
              yaw: yaw + jit,
            });
          }
      return places;
    }

// does an exit ladder stand on or beside this cell? a pile in the exit's own cell would sit inside
// the prop, and the ring around it is where the player lands and where the shaft pools its light
  static function nearExit(m:Sewer, col:Int, row:Int):Bool
    {
      for (l in m.lamps)
        {
          if (!l.exit)
            continue;
          if (Math.abs(l.col - col) <= 1 &&
              Math.abs(l.row - row) <= 1)
            return true;
        }
      return false;
    }
}

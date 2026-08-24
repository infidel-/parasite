package render.sewer;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.sewer.SewerModel.Sewer;
import render.world.VisionMask;

// 3D clutter scattered against the tunnel walls — the first CONVEX geometry underground. everything
// else down here is the shell itself (a concave box: a corridor cannot block its own light) or a
// flat decal, which is why a wall bracket aimed along the walkway had nothing to throw a shadow off.
//
// placement is per 2x2 BLOCK against a wall FACE, the idiom SewerLamps explains at length: an
// independent per-cell coin flip deals visible runs, one prop per block caps a run at two by
// construction, and multiplying the gate by the eligible face count keeps per-FACE density at
// PROP_PCT whether the block is a corner or an open hall. hugging a wall is also what keeps the
// walkway clear — the player never has to walk through one.
//
// pure decoration: no AreaObject behind it, so unlike the exit ladder (render.world.ObjModels)
// there is no ghost twin, no tactical outline hull and nothing per-frame
class SewerProps
{
  static inline var CELL = CityConfig.CELL;

  // cell offsets of the neighbour a wall face looks at, matching SewerGeom.side's four directions
  // (0 = north edge, 1 = south, 2 = west, 3 = east)
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];

  // the one wall direction a prop may NOT lean on: the SOUTH face, which is the wall standing between
  // the camera and its own cell (CAMERA_SEWER sits at +Z and looks back along -Z). that wall is
  // WALL_H tall and capped by a ledge plateau, so it hides everything within WALL_H / tan(pitch) of
  // it — 2.25 world units at the near preset (y16/z12, 53 degrees), 1.05 at the far one (y40/z14,
  // 71 degrees). every prop here is knee-high and stands a fraction of a unit off the plane, so a
  // south-wall prop is not partly occluded, it is INVISIBLE at every zoom. measured, not guessed:
  // a crate at h 0.75 / standoff 0.35 crosses the wall plane at y 1.22 against a 3.0 cap. pulling it
  // out far enough to clear would need a standoff of 1.7, i.e. parked mid-corridor, so the fix is to
  // never pick the face. costs ~a quarter of the eligible faces, which SewerStyle.PROP_PCT pays back
  static inline var CAM_DIR = 1;

  // an odd modulus folded in before ANY small-pool index. every step from (bcol, brow) to a roll is
  // linear over GF(2) — SewerModel.mix is a xorshift, and multiply-by-odd and xor are linear too —
  // so each bit of a roll is a fixed XOR of the coordinate bits and `roll % 2` reads exactly ONE of
  // them. That is not a coin, it is a plane: measured over 40 blocks, a row band scored only ever 16
  // or 24 of one pick, never a value between. Shifting first does not help ((roll >>> 16) % 2
  // quantises just as hard, to 18/22) because a shifted bit is still one linear form; reducing
  // through an odd number does, since it then depends on all 31 bits at once — the spread opens to
  // 10..27, sd 3.22 against a fair coin's 3.16
  static inline var PICK_ODD = 997;

// scatter, then batch: one InstancedMesh per model, so the whole level pays one draw call per prop
// variant however many it places
  public static function build(scene:Scene, m:Sewer):Void
    {
      var models = SewerStyle.PROP_MODELS;
      var places = places(m);
      // ponytail: no per-frame Models.cull. instanced() turns three's own frustum cull off, so each
      // batch draws its whole list every frame — for a dozen static props that is one constant call
      // per variant, against a repack that could never take a batch below one call anyway. if a
      // tunnel ever gets big enough for that to matter, Models.cull is one line from SewerArea.tick
      for (i in 0...models.length)
        {
          var prop = Models.instanced(scene, models[i].path, places[i], models[i].h, SOLID);
          // the vision mask, once the glb is actually here: instanced() fills `prop` from its own
          // queued Models.get callback, and this one is queued behind it, so the mesh is in place
          // whether the template was already cached or still loading
          Models.get(models[i].path, function(_) VisionMask.patchMesh(prop.mesh));
        }
    }

// the scatter itself: one placement list per PROP_MODELS entry. split out of build so a layout can
// be read without a scene — parasiteHx['render.sewer.SewerProps'].places(SewerModel.demo())
  public static function places(m:Sewer):Array<Array<render.Models.PropPlace>>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var models = SewerStyle.PROP_MODELS;
      var places:Array<Array<render.Models.PropPlace>> = [for (_ in models) []];
      // the two decks the model pick is dealt from, indexed 0 = flat run of wall, 1 = corner
      var deck:Array<Array<Int>> = [[], []];
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
                    if (dir != CAM_DIR &&
                        !SewerModel.isFloor(m, col + DC[dir], row + DR[dir]))
                      faces.push({ col: col, row: row, dir: dir });
                }
            if (faces.length == 0)
              continue;
            if (hh % 100 >= SewerStyle.PROP_PCT * faces.length)
              continue;
            var f = faces[(hh >> 7) % faces.length];
            // the ONE face of the same cell perpendicular to f, if there is one — that is what makes
            // this spot a corner (dirs 0/1 are +/-Z, 2/3 are +/-X). only one: a dead end walled on
            // three sides must not take two faces of the same axis, which would pull the prop off
            // both and park it in the middle of the corridor. first match wins, deterministic
            var perp = -1;
            for (g in faces)
              if (g.col == f.col &&
                  g.row == f.row &&
                  (g.dir < 2) != (f.dir < 2))
                {
                  perp = g.dir;
                  break;
                }
            // the model pick is CONSTRAINED by the spot, not free: SewerProp.corner partitions the
            // table, so a corner deals only from the corner props and a flat run of wall only from
            // the rest. an upright drum against a bare wall reads as dropped in the walkway; in the
            // angle of two walls it reads as stored there.
            //
            // and each pool is DEALT, not rolled. an independent roll cannot fix clustering, it can
            // only be lucky: a habitat puts nearly all of its corners on the one row where the room
            // walls line up, and on 5 such spots a fair 2-entry coin lands 4-or-more the same way
            // 37% of the time — which is what a wall of four drums was. The 5-entry flat pool is no
            // safer; the same level rolled cable for 6 of its 7 flat spots. A deck hands out every
            // entry once before any of them repeats, so a run is capped by construction, and it is
            // reshuffled on refill so it never reads as a fixed rotation either
            var h2 = SewerModel.mix(hh ^ 0x85EBCA6B);
            var pool = (perp >= 0) ? 1 : 0;
            if (deck[pool].length == 0)
              {
                for (i in 0...models.length)
                  if (models[i].corner == (pool == 1))
                    deck[pool].push(i);
                // Fisher-Yates off the same hash chain, so a level stays fully determined by its grid
                var r = h2;
                var k = deck[pool].length;
                while (k > 1)
                  {
                    r = SewerModel.mix(r);
                    k--;
                    var j = (r % PICK_ODD) % (k + 1);
                    var t = deck[pool][k];
                    deck[pool][k] = deck[pool][j];
                    deck[pool][j] = t;
                  }
              }
            var mi = deck[pool].pop();
            var mdl = models[mi];
            // the standoff, DERIVED rather than authored: r is the prop's footprint radius per unit
            // of height, so r * h is its world radius whatever h is set to and the prop can never be
            // left half inside the masonry by a height edit somewhere else
            var margin = mdl.r * mdl.h + SewerStyle.PROP_CLEAR;

            // start at the cell centre; each taken face then pulls the prop onto that wall plane and
            // pushes it back in by its own margin. a corner applies both, which tucks it into the
            // angle instead of centring it on a 4-unit face — where a single small object reads as
            // swept aside rather than deliberately placed
            var x0 = f.col * CELL - half;
            var z0 = f.row * CELL - half;
            var px = x0 + CELL / 2, pz = z0 + CELL / 2;
            var nx = 0.0, nz = 0.0;
            for (d in [f.dir, perp])
              switch (d)
                {
                  case 0:
                    pz = z0 + margin;
                    nz += 1;
                  case 2:
                    px = x0 + margin;
                    nx += 1;
                  case 3:
                    px = x0 + CELL - margin;
                    nx -= 1;
                  default:
                    // -1 = no perpendicular face. dir 1 is CAM_DIR and never reaches `faces`
                }
            // yaw from the summed inward normal, so the prop's authored front looks down the corridor
            // — and a corner's two normals bisect to 45 into the room for free. reproduces the four
            // literals this replaced exactly: (0,1)->0, (0,-1)->PI, (1,0)->PI/2, (-1,0)->-PI/2
            var jit = (((h2 >> 3) % 2001) / 1000.0 - 1.0) * SewerStyle.PROP_YAW_JITTER;
            places[mi].push({
              x: px,
              z: pz,
              yaw: Math.atan2(nx, nz) + jit,
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

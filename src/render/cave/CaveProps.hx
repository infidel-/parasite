package render.cave;

import three.Three;
import citygen.CityConfig;
import gen.cave.CaveField;
import render.Models;
import render.cave.CaveStyle.CaveProp;
import render.cave.CaveStyle.CavePropSpot;
import render.sewer.SewerModel;
import render.sewer.SewerModel.Sewer;
import render.sewer.SewerProps;
import render.world.VisionMask;

// the cave's dressing — stalagmites, flowstone, fallen rock, rimstone pools, crystals, fungus and root
// curtains — dealt against the wall foot. render.sewer.SewerProps' idiom (per 2x2 block, gated per
// eligible wall face, dealt from a deck so a run cannot repeat, never the camera-side face, never next
// to an exit) with one difference that is the cave's: the wall is not on the cell edge. the outline
// sits wherever gen.cave.CaveField crosses ISO, a lumpy distance into the rock, so each prop finds its
// own wall by walking the field and stands off THAT.
//
// pure decoration, like the sewer's: no AreaObject behind it, one instanced batch per glb
class CaveProps
{
  static inline var CELL = CityConfig.CELL;

  // a wall face's neighbour, as render.sewer.SewerProps: 0 north, 1 south, 2 west, 3 east
  static var DC = [0, 0, -1, 1];
  static var DR = [-1, 1, 0, 0];
  // the south face stands between the camera and its cell and hides anything against it
  // (render.sewer.SewerProps.CAM_DIR measured why)
  static inline var CAM_DIR = 1;
  // see render.sewer.SewerProps.PICK_ODD: a deck index reduced through an odd modulus, not a bit
  static inline var PICK_ODD = 997;

// scatter, then batch: one InstancedMesh per glb
  public static function build(scene:Scene, m:Sewer):Void
    {
      var models = CaveStyle.PROP_MODELS;
      var places = places(m);
      // ponytail: no per-frame cull, for render.sewer.SewerProps' reason (a static level's handful)
      for (i in 0...models.length)
        {
          var prop = Models.instanced(scene, models[i].path, places[i], models[i].h, SOLID);
          Models.get(models[i].path, function(_) VisionMask.patchMesh(prop.mesh));
        }
    }

// the scatter itself: one placement list per PROP_MODELS entry, readable without a scene —
// parasiteHx['render.cave.CaveProps'].places(render.cave.CaveModel.demo())
  public static function places(m:Sewer):Array<Array<Models.PropPlace>>
    {
      var models = CaveStyle.PROP_MODELS;
      var places:Array<Array<Models.PropPlace>> = [for (_ in models) []];
      var decks:Array<Array<Int>> = [[], [], []];
      for (brow in 0...Std.int((m.h + 1) / 2))
        for (bcol in 0...Std.int((m.w + 1) / 2))
          {
            var bc = bcol * 2;
            var br = brow * 2;
            // multipliers of their own, so these rolls do not correlate with anything else's
            var hh = SewerModel.mix((bc * 83492791) ^ (br * 29986577));
            var hang = SewerModel.mix((bc * 15485863) ^ (br * 32452843));
            var faces = [];
            var north = [];
            for (dr in 0...2)
              for (dc in 0...2)
                {
                  var col = bc + dc;
                  var row = br + dr;
                  if (!SewerModel.isFloor(m, col, row) ||
                      SewerProps.nearExit(m, col, row))
                    continue;
                  for (dir in 0...4)
                    if (dir != CAM_DIR &&
                        !SewerModel.isFloor(m, col + DC[dir], row + DR[dir]))
                      {
                        var face = {
                          col: col,
                          row: row,
                          dir: dir,
                        };
                        faces.push(face);
                        if (dir == 0)
                          north.push(face);
                      }
                }

            // a floor prop: a corner deals from the corner deck, a flat run of wall from the flat one
            if (faces.length > 0 &&
                hh % 100 < CaveStyle.PROP_PCT * faces.length)
              {
                var f = faces[(hh >> 7) % faces.length];
                var perp = -1;
                for (g in faces)
                  if (g.col == f.col &&
                      g.row == f.row &&
                      (g.dir < 2) != (f.dir < 2))
                    {
                      perp = g.dir;
                      break;
                    }
                var h2 = SewerModel.mix(hh ^ 0x85EBCA6B);
                var mi = deal(decks, perp >= 0 ? CORNER : FLAT, h2);
                places[mi].push(place(m, f.col, f.row, f.dir, perp, models[mi], h2));
              }

            // a root curtain, down a north face only
            if (north.length > 0 &&
                hang % 100 < CaveStyle.HANG_PCT * north.length)
              {
                var f = north[(hang >> 7) % north.length];
                var h2 = SewerModel.mix(hang ^ 0xC2B2AE35);
                var mi = deal(decks, HANG, h2);
                places[mi].push(place(m, f.col, f.row, f.dir, -1, models[mi], h2));
              }
          }
      return places;
    }

// the next model index off the spot's deck, refilled and Fisher-Yates shuffled off the hash chain
// when it runs dry (render.sewer.SewerProps: a deck caps a run by construction, a roll cannot)
  static function deal(decks:Array<Array<Int>>, spot:CavePropSpot, h:Int):Int
    {
      var deck = decks[spot.getIndex()];
      if (deck.length == 0)
        {
          var models = CaveStyle.PROP_MODELS;
          for (i in 0...models.length)
            if (models[i].spot == spot)
              deck.push(i);
          var r = h;
          var k = deck.length;
          while (k > 1)
            {
              r = SewerModel.mix(r);
              k--;
              var j = (r % PICK_ODD) % (k + 1);
              var t = deck[k];
              deck[k] = deck[j];
              deck[j] = t;
            }
        }
      return deck.pop();
    }

// stand one prop off the wall foot of face `dir` of a cell (and of `perp` too, for a corner): find
// where the field crosses ISO along the face normal, step back toward the floor by the prop's own
// standoff, less the tuck. a hung prop is lifted so its top sits just under the rock top's lip there
  static function place(m:Sewer, col:Int, row:Int, dir:Int, perp:Int, mdl:CaveProp,
      h:Int):Models.PropPlace
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var scale = CaveStyle.PROP_SCALE_LO +
        (CaveStyle.PROP_SCALE_HI - CaveStyle.PROP_SCALE_LO) * ((h >> 5) % 1001) / 1000.0;
      var off = mdl.r * mdl.h * scale * (1 - CaveStyle.PROP_TUCK);
      // the cell centre, slid along a flat wall (a corner pins both axes, so it does not slide)
      var slide = (perp < 0 ? (((h >> 11) % 2001) / 1000.0 - 1.0) * CaveStyle.PROP_SLIDE / CELL : 0.0);
      var u = col + 0.5 + (dir < 2 ? slide : 0.0);
      var v = row + 0.5 + (dir < 2 ? 0.0 : slide);
      var nx = 0.0;
      var nz = 0.0;
      var footU = u;
      var footV = v;
      for (d in [dir, perp])
        {
          if (d < 0)
            continue;
          var foot = foot(m, col, row, d, u, v);
          switch (d)
            {
              case 0:
                footV = foot;
                v = foot + off / CELL;
                nz += 1;
              case 2:
                footU = foot;
                u = foot + off / CELL;
                nx += 1;
              case 3:
                footU = foot;
                u = foot - off / CELL;
                nx -= 1;
              default:
            }
        }
      var jit = (((h >> 3) % 2001) / 1000.0 - 1.0) * CaveStyle.PROP_YAW_JITTER;
      var p:Models.PropPlace = {
        x: u * CELL - half,
        z: v * CELL - half,
        yaw: Math.atan2(nx, nz) + (mdl.spot == HANG ? 0.0 : jit),
        scale: scale,
      };
      if (mdl.spot == HANG)
        p.y = CaveGeom.topY(footU, footV, 0) - mdl.h * scale - CaveStyle.HANG_TUCK;
      return p;
    }

// the wall foot behind face `d` of a cell, in cells along that face's axis: walk from the cell edge
// into the neighbour until the field falls under ISO. the oracle (gen.GenCheck.caveSane) asserts a
// rock cell's centre is always under it, so the walk ends within half a cell. public for
// render.cave.CaveArea.objWall, which stands the exit arch off the same foot
  public static function foot(m:Sewer, col:Int, row:Int, d:Int, u:Float, v:Float):Float
    {
      var isFloor = function(c:Int, r:Int) return SewerModel.isFloor(m, c, r);
      var t = 0.0;
      while (t < 0.5)
        {
          var f = switch (d)
            {
              case 0: CaveField.field(isFloor, u, row - t);
              case 2: CaveField.field(isFloor, col - t, v);
              default: CaveField.field(isFloor, col + 1 + t, v);
            }
          if (f < CaveField.ISO)
            break;
          t += 0.02;
        }
      return switch (d)
        {
          case 0: row - t;
          case 2: col - t;
          default: col + 1 + t;
        }
    }
}

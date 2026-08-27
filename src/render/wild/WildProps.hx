package render.wild;

import three.Three;
import citygen.CityConfig;
import render.Models;
import render.wild.WildModel.Wild;

// the wilderness scatter: trees and rocks as instanced glb, one InstancedMesh per model however many
// copies a cell grid asks for.
//
// UNLIKE render.sewer.SewerProps this DOES cull per frame, and the difference is the count. a tunnel
// places a dozen props and its own comment argues that a repack could never take a batch below the
// one draw call it already costs; a 100x100 wilderness places hundreds spread over 400 world units,
// and render.Models.instanced turns three's own frustum cull off — so without cull() every batch
// draws its whole list from anywhere on the map, at any zoom.
//
// placement is per CELL and not scattered freely: the 2D tile grid already says where a tree stands
// (game.AreaGenerator.generateWilderness wrote it, and it is what the pathfinder walks around), so
// the 3D prop has to land on that cell or the geometry and the gameplay disagree
class WildProps
{
  static inline var CELL = CityConfig.CELL;

// scatter, then batch: one InstancedMesh per model. returns the batches so the area tick can cull them
  public static function build(scene:Scene, m:Wild):Array<Models.InstancedProp>
    {
      var models = WildStyle.PROPS;
      var places = places(m);
      var out = [];
      for (i in 0...models.length)
        {
          var prop = Models.instanced(scene, models[i].path, places[i], models[i].h, SOLID);
          // the vision mask, once the glb is actually here: instanced() fills `prop` from its own
          // queued Models.get callback and this one queues behind it, so the mesh is in place whether
          // the template was cached or still loading (render.sewer.SewerProps' idiom).
          // GATED on the batch having anything in it, unlike the tunnel's — instanced() returns early
          // on an empty list without ever touching the loader, so an unconditional get here would pull
          // a glb down for a batch that draws nothing. the plains has exactly that case: no band but
          // the mountains places a large rock
          if (places[i].length > 0)
            Models.get(models[i].path, function(_) render.world.VisionMask.patchMesh(prop.mesh));
          out.push(prop);
        }
      return out;
    }

// the scatter itself: one placement list per PROPS entry. split out of build so a layout can be read
// without a scene, the way render.sewer.SewerProps.places can
  public static function places(m:Wild):Array<Array<Models.PropPlace>>
    {
      var half = (CityConfig.GRID * CELL) / 2;
      var places:Array<Array<Models.PropPlace>> = [for (_ in WildStyle.PROPS) []];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var mi = m.prop[row][col];
            if (mi < 0)
              continue;
            // its own multipliers, mixed: must not correlate with the grass tuft rolls, which run
            // over the same cells (see render.sewer.SewerModel.mix on why the raw hash combs)
            var h = WildModel.mix((col * 40503151) ^ (row * 57885161));
            // off-centre within the cell, so a stand of trees is not a grid of trees. kept well
            // inside it — the cell is what the pathfinder treats as blocked
            var px = (col + 0.35 + (h % 601) / 601.0 * 0.3) * CELL - half;
            var pz = (row + 0.35 + ((h >> 9) % 601) / 601.0 * 0.3) * CELL - half;
            places[mi].push({
              x: px,
              z: pz,
              y: sit(mi, px, pz),
              // a full turn: every one of these is a natural object with no authored front, so
              // there is nothing for a yaw to get wrong
              yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
              scale: 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.PROPS[mi].jitter,
            });
          }
      bigRocks(m, places, half);
      thicket(m, places, half);
      rails(m, places, half);
      small(m, places, half);
      return places;
    }

// the guard rail along the highway — one segment per cell, on BOTH shoulders, in two continuous runs.
//
// it went in on ONE side, chosen from the field at the corridor's midpoint on the reasoning that a
// rail belongs on the side that DROPS. that is true of a hillside road and wrong here: the corridor
// is GRADED, so render.wild.WildHeight ramps it down symmetrically and BOTH shoulders drop away from
// the asphalt. a barrier on one side of a two-lane highway read as unfinished rather than as sited.
//
// the second run is free where it matters — render.Models.instanced keeps one InstancedMesh per PROPS
// row, so both runs are the SAME draw call and only the instance count moves. what it does cost is
// triangles, and this prop is the area's largest single consumer of them (see docs/3d-render.md): if
// the wilderness ever needs a triangle back, its castShadow is the lever, not this.
//
// the yaw is LOCKED to the corridor axis, alone among the props out here. every other row deals a full
// turn because a rock and a tree have no authored front; a crash barrier has one, and a run of them at
// random angles is a scrapyard. the far run adds PI so both face the road — correct by intent and
// invisible in fact, since the glb is 0.05 deep against 0.40 tall and draws 0.2 world units thick.
// no sit() call either — `sit` sinks a prop by its footprint against the SLOPE, and the shoulder cell
// it stands on has just been graded, so the correction it would apply is the one thing this prop must
// not have: a rail follows the road, level across
  static function rails(m:Wild, places:Array<Array<Models.PropPlace>>, half:Float):Void
    {
      if (m.road == null)
        return;
      var off = (m.road.half + WildStyle.RAIL_OFF) * CELL;
      var c = m.road.centre * CELL - half;
      var yaw = (m.road.alongX ? 0.0 : Math.PI / 2);
      // ONE PER CELL, and that is not a spacing choice: WildStyle sizes this prop's `h` so its own
      // width comes out at exactly CELL, so consecutive segments meet end to end and the run reads
      // as continuous barrier rather than as fence posts
      for (i in 0...(m.road.alongX ? m.w : m.h))
        {
          var a = (i + 0.5) * CELL - half;
          for (k in 0...2)
            {
              var side = (k == 0 ? -off : off);
              var px = (m.road.alongX ? a : c + side);
              var pz = (m.road.alongX ? c + side : a);
              places[WildStyle.GUARD_RAIL].push({
                x: px,
                z: pz,
                y: WildHeight.at(px, pz),
                yaw: yaw + k * Math.PI,
                scale: 1.0,
              });
            }
        }
    }

// the 2x2 boulders: ONE instance per rect, standing on the corner its four cells share rather than in
// any one of them. no seating code of its own — sit() sinks a prop by h * r * slope, and this row's `r`
// is set so h * r is a whole CELL, which is exactly the footprint radius of a two-cell object. the yaw
// is a full turn like every other natural object out here, and the scale roll is the tightest in the
// table because on this prop it moves the FOOTPRINT: the four cells are blocked whatever it draws
  static function bigRocks(m:Wild, places:Array<Array<Models.PropPlace>>, half:Float):Void
    {
      for (r in m.rocks)
        {
          var h = WildModel.mix((r.col * 26700001) ^ (r.row * 15485863));
          var px = (r.col + 1.0) * CELL - half;
          var pz = (r.row + 1.0) * CELL - half;
          places[WildStyle.ROCK_LARGE].push({
            x: px,
            z: pz,
            y: sit(WildStyle.ROCK_LARGE, px, pz),
            yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
            scale: 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) *
              WildStyle.PROPS[WildStyle.ROCK_LARGE].jitter,
          });
        }
    }

// the tree thickets: the UNDERSTOREY only. each thicket cell already carries a real tree index, so the
// scatter above has planted its tree; what a cell blocking SIGHT needs on top of that is something at
// eye level, because a stand of bare trunks is a thing you can see between however many of them there
// are. so every cell also gets a bush, and half of them a second tree at half to three-quarter height —
// which is the point of the second tree as much as the filling is: the scatter deals one size of tree
// give or take a fifth, and a block holding both full-grown and half-grown ones is what stops a 3x3
// reading as a tidier patch of the same wood. all of it lands in the batches the band is already
// drawing, so this costs no draw call
  static function thicket(m:Wild, places:Array<Array<Models.PropPlace>>, half:Float):Void
    {
      for (c in m.thicket)
        {
          var h = WildModel.mix((c.col * 83492791) ^ (c.row * 15485863));
          var bi = WildBand.pick(WildBand.cur.bushes, h);
          var bs = 0.85 + ((h >> 17) % 1001) / 1000.0 * 0.6;
          var bx = (c.col + 0.15 + (h % 601) / 601.0 * 0.7) * CELL - half;
          var bz = (c.row + 0.15 + ((h >> 9) % 601) / 601.0 * 0.7) * CELL - half;
          places[bi].push({
            x: bx,
            z: bz,
            y: sit(bi, bx, bz, bs),
            yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
            scale: bs,
          });
          if ((h >> 27) % 2 == 1)
            continue;
          h = WildModel.mix(h);
          var ti = WildBand.pick(WildBand.cur.trees, h);
          var ts = 0.5 + ((h >> 17) % 1001) / 1000.0 * 0.25;
          var tx = (c.col + 0.15 + (h % 601) / 601.0 * 0.7) * CELL - half;
          var tz = (c.row + 0.15 + ((h >> 9) % 601) / 601.0 * 0.7) * CELL - half;
          places[ti].push({
            x: tx,
            z: tz,
            y: sit(ti, tx, tz, ts),
            yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
            scale: ts,
          });
        }
    }

// loose stones on OPEN ground — the same two rock glbs a tenth the size, on cells with no prop of
// their own. render-only and deliberately so: a full-size rock stands on an unwalkable TILE_ROCK cell,
// and a stone the player steps over must not block anything, so this scatter touches no tile and no
// walkability. its own hash multipliers, mixed, so a stone does not land wherever a grass tuft or a
// prop already rolled over the same cell
  static function small(m:Wild, places:Array<Array<Models.PropPlace>>, half:Float):Void
    {
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            // against -1 and not 0, so a cell under a 2x2 boulder (WildModel.OCCUPIED) is skipped too
            if (m.prop[row][col] != -1)
              continue;
            var h = WildModel.mix((col * 73856093) ^ (row * 19349663));
            if ((h % 1000) >= WildBand.cur.smallRocks * 1000)
              continue;
            // one in three is a cluster, the same split the full-size rocks take
            var mi = (h % 3 == 0) ? WildStyle.ROCK_CLUSTER_SMALL : WildStyle.ROCK_BOULDER_SMALL;
            var px = (col + 0.2 + (h % 601) / 601.0 * 0.6) * CELL - half;
            var pz = (row + 0.2 + ((h >> 9) % 601) / 601.0 * 0.6) * CELL - half;
            // and never on the corridor — the VERGE included, which is what this measures off. the
            // gate above is m.prop, which is per CELL and only ever marks the road tiles, while the
            // dirt shoulder reaches 2.75 cells out and is not a tile at all. so without this a stone
            // seeded on a shoulder cell is buried under the verge, and a loose boulder sitting on a
            // graded shoulder beside a crash barrier is the wrong read even where it is not
            if (WildRoad.vergeDist(m, px, pz) < 0)
              continue;
            places[mi].push({
              x: px,
              z: pz,
              y: sit(mi, px, pz),
              yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
              scale: 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.PROPS[mi].jitter,
            });
          }
    }

// where a prop's base sits: the relief under it, SUNK by its own footprint against the slope.
//
// render.Models.instanced plants a prop's base on a horizontal plane, so on a hillside the plane
// meets the ground at the centre and the downhill edge hangs in the air. `r` is that footprint as a
// multiple of `h` (which is exactly why it is stored as a ratio — see WildStyle.WildProp), so
// h * r * slope is the drop from centre to lowest edge, and burying the prop by it puts the downhill
// edge on the ground and the uphill edge under it. that is the right way round: a rock half in the
// earth reads as a rock, a rock floating over it reads as a bug. no TILT, deliberately —
// render.Models.PropPlace carries a yaw and nothing else, and a tree grows vertical whatever it
// stands on
// `s` is the instance's own scale multiplier, because the footprint it is being sunk by shrinks with
// it — the scatter's own +/-20-30% jitter is close enough to 1.0 to leave at the default, but a thicket
// plants trees at half size and a sink computed for a full-grown one would bury them
  static inline function sit(mi:Int, x:Float, z:Float, s:Float = 1.0):Float
    {
      var p = WildStyle.PROPS[mi];
      return WildHeight.at(x, z) - p.h * p.r * s * WildHeight.slope(x, z);
    }
}

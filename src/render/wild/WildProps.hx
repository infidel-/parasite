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
        out.push(Models.instanced(scene, models[i].path, places[i], models[i].h, SOLID));
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
              // a full turn: every one of these is a natural object with no authored front, so
              // there is nothing for a yaw to get wrong
              yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
              scale: 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.PROPS[mi].jitter,
            });
          }
      small(m, places, half);
      return places;
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
            if (m.prop[row][col] >= 0)
              continue;
            var h = WildModel.mix((col * 73856093) ^ (row * 19349663));
            if ((h % 1000) >= WildStyle.SMALL_ROCK_CHANCE * 1000)
              continue;
            // one in three is a cluster, the same split the full-size rocks take
            var mi = (h % 3 == 0) ? WildStyle.ROCK_CLUSTER_SMALL : WildStyle.ROCK_BOULDER_SMALL;
            places[mi].push({
              x: (col + 0.2 + (h % 601) / 601.0 * 0.6) * CELL - half,
              z: (row + 0.2 + ((h >> 9) % 601) / 601.0 * 0.6) * CELL - half,
              yaw: ((h >> 3) % 3600) / 3600.0 * 2 * Math.PI,
              scale: 1.0 + (((h >> 17) % 2001) / 1000.0 - 1.0) * WildStyle.PROPS[mi].jitter,
            });
          }
    }
}

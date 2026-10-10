package render.wild;

import game.Game;
import map.Terrain;
import render.AreaSounds;
import render.RenderConfig;
import render.SoundSources;
import render.wild.WildModel;

// the sounds of the open wilderness (sound/wild/*.mp3, see docs/sound-gen.md): one bed per terrain
// band, the highway's own where the area has one, and the band's night one-shots — an owl in the
// forest, a coyote over the plains, stones on the mountain — through render.AreaSounds
class WildSounds
{
  // the beds: the area's band, and the highway strip
  static var BAND:Map<String, String> = [
    'forest' => 'wild/forest',
    'plains' => 'wild/plains',
    'mountain' => 'wild/mountain',
  ];
  static inline var ROAD_BED = 'wild/road';
  // how far either side of the highway's centreline its bed plays, in cells
  static inline var ROAD_REACH = 4.0;

  var game:Game;
  var m:Wild;
  var loops:AreaSounds;
  var beds:Array<String>;
  // each bed's eased level, 0..1, in beds order
  var bed:Array<Float>;
  // the band's one-shots with no source, each with its mean gap and seconds to its next roll
  var far:Array<{ key:String, gap:Float, wait:Float }>;

  public function new(game:Game, m:Wild)
    {
      this.game = game;
      this.m = m;
      var band = switch (Terrain.bandAtArea(game.region.mapSeed, game.area.x, game.area.y))
        {
          case TERRAIN_FOREST: 'forest';
          case TERRAIN_MOUNTAIN: 'mountain';
          case TERRAIN_PLAINS: 'plains';
        };
      // the cells the one-shots come from, off the saved tiles
      var trees = [];
      var bushes = [];
      var rocks = [];
      var road = [];
      for (row in 0...m.h)
        for (col in 0...m.w)
          {
            var t = game.area.getCellType(col, row);
            var c = { col: col, row: row };
            if ((t >= Const.TILE_TREE1 && t < Const.TILE_BUSH) ||
                t == Const.TILE_TREE_CLUSTER)
              trees.push(c);
            else if (t == Const.TILE_BUSH)
              bushes.push(c);
            else if (t == Const.TILE_ROCK ||
                t == Const.TILE_ROCK_LARGE)
              rocks.push(c);
            if (WildRoad.isRoad(m, col, row))
              road.push(c);
          }
      var events:Array<AreaEvent> = [
        { key: 'facility/car', range: 8, gap: 45, cells: road },
      ];
      far = [];
      if (band == 'forest')
        {
          events.push({ key: 'wild/owl', range: 8, gap: 40, cells: trees });
          events.push({ key: 'wild/twig', range: 3, gap: 25, cells: trees.concat(bushes) });
        }
      else if (band == 'plains')
        far.push({ key: 'wild/coyote', gap: 120, wait: 0 });
      else
        events.push({ key: 'wild/rockfall', range: 6, gap: 35, cells: rocks });
      for (f in far)
        f.wait = f.gap * Math.random();
      loops = new AreaSounds(game, [], events);
      beds = [BAND[band]];
      if (m.road != null)
        beds.push(ROAD_BED);
      bed = [for (_ in beds) 0.0];
      SoundSources.beds = beds.copy();
      SoundSources.events = [for (f in far) f.key];
    }

// per frame: the events, the band's bed and the road's crossfaded over four BASE_MS as the player
// walks onto the highway's strip, and the sourceless one-shots at full
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      loops.tick(pc, pr, dtMs);
      var d = WildRoad.distTo(m, pc, pr);
      var on = (d >= 0 && d <= ROAD_REACH ? 1 : 0);
      var kb = Math.min(1, dtMs / (RenderConfig.BASE_MS * 4));
      for (i in 0...beds.length)
        {
          bed[i] += ((i == on ? 1.0 : 0.0) - bed[i]) * kb;
          game.scene.sounds.updateLoop(beds[i], bed[i], game.config.ambientVolume);
        }
      for (f in far)
        {
          f.wait -= dtMs / 1000;
          if (f.wait > 0)
            continue;
          f.wait = f.gap * (0.5 + Math.random());
          AreaSounds.once(game, f.key, 1);
        }
    }
}

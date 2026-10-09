package render;

import game.Game;
import objects.Door;
import render.RenderConfig;

// one looping kind of an area: its sound key, the path distance in cells at which it falls silent,
// and the cells it plays from
typedef AreaLoop = {
  key:String,
  range:Float,
  cells:Array<{ col:Int, row:Int }>,
};

// the looping object sounds of a 3D area (sound/<area>/*.mp3, see docs/sound-gen.md): each kind
// fades with the PATH distance from the player to its nearest source (SoundPath), so a wall or a
// closed door between them silences it. render.corp.CorpSounds runs the tower's machines on it and
// adds its beds; render.facility.FacilityArea runs the compound's vents
class AreaSounds
{
  var game:Game;
  var kinds:Array<AreaLoop>;
  // the area's doors by cell, built once: a door object never moves, only opens
  var doors:Map<Int, Door>;
  // each kind's eased level, 0..1
  var level:Array<Float>;
  // the path search, the player at the centre; searched by tick, so a caller ticking after it can
  // ask it for its own sources
  public var path(default, null):SoundPath;

  public function new(game:Game, kinds:Array<AreaLoop>)
    {
      this.game = game;
      this.kinds = kinds;
      var r = 0.0;
      for (k in kinds)
        {
          r = Math.max(r, k.range);
          SoundSources.put(k.key, k.cells, k.range);
        }
      path = new SoundPath(Math.ceil(r));
      doors = SoundPath.doorsOf(game.area);
      level = [for (_ in kinds) 0.0];
    }

// per frame: search from the player's cell, aim each kind at full at the nearest source's face and
// at silence at its range — squared, (1 - d/range)^2, so one step off a 3-cell source is already
// -7 dB and not -3.5 — and ease the level there over two BASE_MS so a step or a door closing fades
// rather than cuts. raw dtMs: like the fire loop, sound is not an animation
// ponytail: no panning and no partial muffling, a wall is all or nothing for a loop; upgrade by
// keeping a fraction of the level when the only path is through a closed door
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      path.search(game.area, doors, pc, pr);
      var k = Math.min(1, dtMs / (RenderConfig.BASE_MS * 2));
      for (i in 0...kinds.length)
        {
          var d = 1e9;
          for (s in kinds[i].cells)
            d = Math.min(d, path.reach(s.col, s.row));
          var aim = Math.pow(Math.max(0, 1 - d / kinds[i].range), 2);
          level[i] += (aim - level[i]) * k;
          game.scene.sounds.updateLoop(kinds[i].key, level[i], game.config.ambientVolume);
        }
    }
}

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
  // seconds it runs and rests, each roll 0.5-1.5x of these: a fridge's compressor cuts in and out.
  // omitted, it never rests
  ?duty:{ on:Float, off:Float },
};

// one intermittent kind: a one-shot played every `gap` seconds or so (each roll 0.5-1.5x) from a
// random one of its cells within `range` of the player — a phone ringing, a tap dripping. a roll
// with no cell in reach plays nothing, so it is never heard through a wall either
typedef AreaEvent = {
  key:String,
  range:Float,
  gap:Float,
  cells:Array<{ col:Int, row:Int }>,
};

// the object sounds of a 3D area (sound/<area>/*.mp3, see docs/sound-gen.md): each kind fades with
// the PATH distance from the player to its nearest source (SoundPath), so a wall or a closed door
// between them silences it. render.corp.CorpSounds runs the tower's machines on it and adds its
// beds; render.facility.FacilityArea runs the compound's vents
class AreaSounds
{
  var game:Game;
  var kinds:Array<AreaLoop>;
  var events:Array<AreaEvent>;
  // the area's doors by cell, built once: a door object never moves, only opens
  var doors:Map<Int, Door>;
  // each kind's eased level, 0..1
  var level:Array<Float>;
  // each kind's duty state, and the seconds left in it
  var running:Array<Bool>;
  var left:Array<Float>;
  // each event's seconds to its next roll
  var wait:Array<Float>;
  // the path search, the player at the centre; searched by tick, so a caller ticking after it can
  // ask it for its own sources
  public var path(default, null):SoundPath;

  public function new(game:Game, kinds:Array<AreaLoop>, ?events:Array<AreaEvent>)
    {
      this.game = game;
      this.kinds = kinds;
      this.events = (events == null ? [] : events);
      var r = 0.0;
      for (k in kinds)
        {
          r = Math.max(r, k.range);
          SoundSources.put(k.key, k.cells, k.range);
        }
      for (e in this.events)
        {
          r = Math.max(r, e.range);
          SoundSources.put(e.key, e.cells, e.range);
        }
      path = new SoundPath(Math.ceil(r));
      doors = SoundPath.doorsOf(game.area);
      level = [for (_ in kinds) 0.0];
      // a duty cycle starts anywhere in itself, so two floors' fridges do not cut in together
      running = [for (_ in kinds) Math.random() < 0.5];
      left = [for (k in kinds) (k.duty == null ? 0.0 : roll(k.duty.on) * Math.random())];
      wait = [for (e in this.events) roll(e.gap)];
    }

// a gap or a duty phase around its mean, 0.5-1.5x
  static inline function roll(mean:Float):Float
    {
      return mean * (0.5 + Math.random());
    }

// play one one-shot of a kind at `frac` of the ambient slider and the kind's tuned gain, and record
// the volume for sound mode. ambient and not effects: an office phone is the room, not an action
  public static function once(game:Game, key:String, frac:Float):Void
    {
      var vol = Math.min(100, game.config.ambientVolume * frac * SoundSources.gain(key));
      SoundSources.vol[key] = vol;
      game.scene.sounds.play(key, {
        volume: vol,
        always: true,
      });
    }

// per frame: search from the player's cell, aim each kind at full at the nearest source's face and
// at silence at its range — squared, (1 - d/range)^2, so one step off a 3-cell source is already
// -7 dB and not -3.5 — and ease the level there over two BASE_MS so a step, a door closing or a
// compressor cutting out fades rather than cuts; then roll the events. raw dtMs: like the fire
// loop, sound is not an animation
// ponytail: no panning and no partial muffling, a wall is all or nothing for a loop; upgrade by
// keeping a fraction of the level when the only path is through a closed door
  public function tick(pc:Int, pr:Int, dtMs:Float):Void
    {
      path.search(game.area, doors, pc, pr);
      var sec = dtMs / 1000;
      var k = Math.min(1, dtMs / (RenderConfig.BASE_MS * 2));
      for (i in 0...kinds.length)
        {
          var kind = kinds[i];
          var d = 1e9;
          for (s in kind.cells)
            d = Math.min(d, path.reach(s.col, s.row));
          var aim = Math.pow(Math.max(0, 1 - d / kind.range), 2);
          if (kind.duty != null)
            {
              left[i] -= sec;
              if (left[i] <= 0)
                {
                  running[i] = !running[i];
                  left[i] = roll(running[i] ? kind.duty.on : kind.duty.off);
                }
              if (!running[i])
                aim = 0;
            }
          level[i] += (aim - level[i]) * k;
          game.scene.sounds.updateLoop(kind.key, level[i], game.config.ambientVolume);
        }
      for (i in 0...events.length)
        {
          wait[i] -= sec;
          if (wait[i] > 0)
            continue;
          var e = events[i];
          wait[i] = roll(e.gap);
          var near = [];
          for (s in e.cells)
            {
              var d = path.reach(s.col, s.row);
              if (d < e.range)
                near.push(d);
            }
          if (near.length > 0)
            once(game, e.key, Math.pow(1 - near[Std.random(near.length)] / e.range, 2));
        }
    }
}

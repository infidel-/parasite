package render;

import citygen.CityConfig;

// one looping sound source in the world: a run of contiguous cells of one kind (a rack row, a lift)
typedef SoundSource = {
  // the kind's sound key, e.g. corp/vending
  key:String,
  // world position of its centre
  x:Float,
  z:Float,
  // the distance in cells at which it falls silent
  range:Float,
  // the cells it covers
  cells:Array<{ col:Int, row:Int }>,
};

// the looping world sounds by kind: each kind's base gain (the tuned dB table), the volume it
// played last frame, and where its sources stand in the current area. Sounds.updateLoop applies the
// gain and records the volume; render.SoundDebug (sound mode) and console.Go (`go sound`) read it
class SoundSources
{
  // base gain per kind in dB, relative to the level `make sounds` baked it at. tuned in the sound
  // debug mode, which copies the changed lines to the clipboard to be pasted back here
  public static var DB:Map<String, Float> = [
    'ambient-fire' => -4.0,
    'corp/rack' => -6.0,
    'corp/elevator' => -10.0,
    'facility/vent' => -14.0,
    'corp/vending' => -2.0,
    'corp/cctv' => -6.0,
    'corp/cooler' => -10.0,
    'corp/window' => -6.0,
    'corp/fridge' => -6.0,
    'corp/phone' => -10.0,
    'corp/drip' => -10.0,
    'corp/flush' => -10.0,
    'ambient-corp' => 0.0,
    'corp/room' => -6.0,
    'corp/cubicle' => -6.0,
    'corp/washroom' => -9.0,
    'facility/machine' => -4.0,
    'facility/generator' => -3.0,
    'facility/drain' => -10.0,
    'facility/pa' => -10.0,
    'facility/birds' => -10.0,
    'facility/car' => -10.0,
    'ambient-facility' => 0.0,
    'facility/lab' => -6.0,
    'facility/washroom' => -5.0,
    'facility/hangar' => -4.0,
    'facility/park' => -8.0,
    'facility/exterior' => -4.0,
    'ambient-city' => 0.0,
    'city/slums-main' => -4.0,
    'city/slums-street' => -4.0,
    'city/slums-alley' => -14.0,
    'city/medium-main' => -4.0,
    'city/medium-street' => -4.0,
    'city/medium-alley' => -4.0,
    'city/downtown-main' => -4.0,
    'city/downtown-street' => -4.0,
    'city/downtown-alley' => -4.0,
    'city/diner' => -16.0,
    'city/store' => -19.0,
    'city/laundromat' => -16.0,
    'city/warehouse' => -14.0,
    'city/sewer' => -30.0,
    'city/lampbuzz' => -22.0,
    'city/bottle' => -16.0,
    'city/can' => -10.0,
    'city/screendoor' => -10.0,
    'city/rats' => -23.0,
    'city/crackle' => -10.0,
    'city/horn' => -10.0,
    'city/shopbell' => -10.0,
    'city/garage' => -14.0,
    'city/helicopter' => -10.0,
    'ambient-wilderness' => 0.0,
    'wild/forest' => -8.0,
    'wild/plains' => -4.0,
    'wild/mountain' => -12.0,
    'wild/road' => -4.0,
    'wild/owl' => -10.0,
    'wild/twig' => -14.0,
    'wild/coyote' => -10.0,
    'wild/rockfall' => -14.0,
    'sewer/tunnel' => -4.0,
    'sewer/chamber' => -4.0,
    'sewer/manhole' => -4.0,
    'sewer/trickle' => -4.0,
    'sewer/pipe' => -4.0,
    'sewer/drip' => -10.0,
    'sewer/rats' => -10.0,
    'sewer/knock' => -10.0,
    'sewer/rumble' => -10.0,
    'sewer/surge' => -10.0,
  ];
  // the volume each kind played last frame, 0..100 of the sound manager's scale
  public static var vol:Map<String, Float> = [];
  // when each intermittent kind last played (haxe.Timer.stamp) and from which cell — none for a
  // sourceless one — so render.SoundDebug can blink the source that just sounded
  public static var pings:Map<String, { t:Float, ?col:Int, ?row:Int }> = [];
  // the kinds with a duty cycle that are in their rest phase now (a fridge whose compressor is off)
  public static var resting:Map<String, Bool> = [];
  // the current area's sources; cleared by render.View before each area build
  public static var sources:Array<SoundSource> = [];
  // the current area's beds: kinds that play everywhere, with no source to stand at
  public static var beds:Array<String> = [];
  // and its sourceless one-shots, which play off a bed rather than from a place (the washroom's
  // distant flush)
  public static var events:Array<String> = [];

// a kind's linear gain off its dB (1 for a kind not in the table)
  public static function gain(key:String):Float
    {
      var db = DB[key];
      return (db == null ? 1.0 : Math.pow(10, db / 20));
    }

// a kind's short name for labels and `go sound`: corp/vending -> vending, ambient-fire -> fire;
// a bed says it is one, since its key names the area and not the place it plays
  public static function label(key:String):String
    {
      if (key == 'ambient-corp')
        return 'bed - corridor';
      if (beds.indexOf(key) >= 0)
        return 'bed - ' + key.substr(key.lastIndexOf('/') + 1);
      var s = key.substr(key.lastIndexOf('/') + 1);
      return (StringTools.startsWith(s, 'ambient-') ? s.substr(8) : s);
    }

// the short names of every kind with a source in the current area, sorted
  public static function kinds():Array<String>
    {
      var out = [];
      for (s in sources)
        if (out.indexOf(label(s.key)) < 0)
          out.push(label(s.key));
      out.sort(Reflect.compare);
      return out;
    }

// replace one kind's sources: cells touching each other (8-way) merge into one source, so a rack
// row or a 3x3 lift is one circle and one label. a no-op when the cells are the ones it already has
  public static function put(key:String, cells:Array<{ col:Int, row:Int }>, range:Float):Void
    {
      // the fire re-puts its visible barrels every frame: an unchanged list keeps the same array, so
      // render.SoundDebug, which rebuilds when the array changes, does not rebuild every frame
      var had = 0;
      var same = true;
      for (s in sources)
        if (s.key == key)
          for (c in s.cells)
            {
              had++;
              if (!Lambda.exists(cells, function(n) return n.col == c.col && n.row == c.row))
                same = false;
            }
      if (same &&
          had == cells.length)
        return;
      sources = [for (s in sources) if (s.key != key) s];
      var left = cells.copy();
      while (left.length > 0)
        {
          var run = [left.pop()];
          var i = 0;
          while (i < run.length)
            {
              var c = run[i];
              i++;
              var j = left.length - 1;
              while (j >= 0)
                {
                  if (Math.abs(left[j].col - c.col) <= 1 &&
                      Math.abs(left[j].row - c.row) <= 1)
                    run.push(left.splice(j, 1)[0]);
                  j--;
                }
            }
          var col = 0.0;
          var row = 0.0;
          for (c in run)
            {
              col += c.col;
              row += c.row;
            }
          var w = CityConfig.cellToWorld(col / run.length, row / run.length);
          sources.push({
            key: key,
            x: w.x,
            z: w.z,
            range: range,
            cells: run,
          });
        }
    }
}

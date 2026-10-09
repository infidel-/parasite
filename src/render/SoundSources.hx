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
    'ambient-fire' => 0.0,
    'corp/rack' => -8.0,
    'corp/elevator' => -8.0,
    'corp/vent' => -8.0,
    'corp/vending' => -8.0,
    'corp/cctv' => -8.0,
    'corp/cooler' => -16.0,
    'ambient-corp' => 0.0,
    'corp/room' => 0.0,
  ];
  // the volume each kind played last frame, 0..100 of the sound manager's scale
  public static var vol:Map<String, Float> = [];
  // the current area's sources; cleared by render.View before each area build
  public static var sources:Array<SoundSource> = [];
  // the current area's beds: kinds that play everywhere, with no source to stand at
  public static var beds:Array<String> = [];

// a kind's linear gain off its dB (1 for a kind not in the table)
  public static function gain(key:String):Float
    {
      var db = DB[key];
      return (db == null ? 1.0 : Math.pow(10, db / 20));
    }

// a kind's short name for labels and `go sound`: corp/vending -> vending, ambient-fire -> fire
  public static function label(key:String):String
    {
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

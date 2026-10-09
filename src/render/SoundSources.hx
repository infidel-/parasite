package render;

// the looping world sounds by kind: each kind's base gain (the tuned dB table) and the volume it
// played last frame. Sounds.updateLoop applies the gain and records the volume
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
    'corp/cooler' => -8.0,
  ];
  // the volume each kind played last frame, 0..100 of the sound manager's scale
  public static var vol:Map<String, Float> = [];

// a kind's linear gain off its dB (1 for a kind not in the table)
  public static function gain(key:String):Float
    {
      var db = DB[key];
      return (db == null ? 1.0 : Math.pow(10, db / 20));
    }
}

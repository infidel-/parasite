package render.anim;

import render.RenderConfig;

// base for a transient one-shot billboard effect. it advances its own progress and writes
// a world-space offset + scale multiplier that the actor layer lays over the sprite's
// resting pose. subclass and override compute(k) for the motion, plus onStart/onFinish for
// launch/landing hooks (sounds, spawns). one instance per playback
class Effect {
  public var offx:Float = 0.0;           // world-space offset laid over the billboard, refreshed each frame
  public var offy:Float = 0.0;
  public var offz:Float = 0.0;
  public var scale:Float = 1.0;          // uniform scale multiplier over the resting scale

  var t:Float = 0.0;                     // progress 0..1
  var ms:Float;                          // duration (multiple of BASE_MS)
  var started:Bool = false;              // onStart fired yet?

  public function new(ms:Float)
    {
      this.ms = ms;
    }

// advance by dtMs (scaled by the global anim speed); fires onStart once on the first frame
// and onFinish once on the frame it completes (returns true then)
  public function advance(dtMs:Float):Bool
    {
      if (!started)
        {
          started = true;
          onStart();
        }
      t += dtMs * RenderConfig.ANIM_SPEED / ms;
      if (t > 1) t = 1;
      compute(t);
      if (t < 1)
        return false;
      onFinish();
      return true;
    }

// override: set offx/offy/offz/scale from progress k (0..1)
  function compute(k:Float):Void {}

// override: fired once when the effect begins (before the first frame)
  function onStart():Void {}

// override: fired once when the effect completes
  function onFinish():Void {}
}

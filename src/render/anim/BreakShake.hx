package render.anim;

import render.RenderConfig;

// host breaking hit: one red self-glow flash (rises and falls once) over a decaying jitter. `cfg` is
// another flash of the same shape (RenderConfig.SIGN_BURN, the elder sign's), RenderConfig.BREAKING
// when left out
class BreakShake extends Shake {
  var peak:Float;

  public function new(?cfg:{ ms:Float, shakeAmp:Float, color:Int, glow:Float })
    {
      if (cfg == null)
        cfg = RenderConfig.BREAKING;
      super(cfg.ms, cfg.shakeAmp * citygen.CityConfig.CELL);
      glow = cfg.color;
      peak = cfg.glow;
    }

  override function compute(k:Float):Void
    {
      super.compute(k);
      glowInt = peak * Math.sin(Math.PI * k);
    }
}

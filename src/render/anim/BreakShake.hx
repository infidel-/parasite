package render.anim;

import render.RenderConfig;

// host breaking hit: one red self-glow flash (rises and falls once) over a decaying jitter
class BreakShake extends Shake {
  public function new()
    {
      super(RenderConfig.BREAKING.ms, RenderConfig.BREAKING.shakeAmp * citygen.CityConfig.CELL);
      glow = RenderConfig.BREAKING.color;
    }

  override function compute(k:Float):Void
    {
      super.compute(k);
      glowInt = RenderConfig.BREAKING.glow * Math.sin(Math.PI * k);
    }
}

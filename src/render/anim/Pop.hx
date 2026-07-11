package render.anim;

// spawn bounce: scale small -> overshoot -> 1 (no positional offset)
class Pop extends Effect {
  public function new(ms:Float)
    {
      super(ms);
    }

  override function compute(k:Float):Void
    {
      scale = 0.4 + 0.6 * (k * k * (3 - 2 * k)) + 0.15 * Math.sin(Math.PI * k);
    }
}

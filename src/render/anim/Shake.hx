package render.anim;

// decaying positional jitter (amplitude decays to 0 at k=1)
class Shake extends Effect {
  var amp:Float;   // starting jitter amplitude (world units)

  public function new(ms:Float, amp:Float)
    {
      super(ms);
      this.amp = amp;
    }

  override function compute(k:Float):Void
    {
      var d = (1 - k) * amp;
      offx = d * Math.sin(k * 40);
      offz = d * Math.cos(k * 37);
    }
}

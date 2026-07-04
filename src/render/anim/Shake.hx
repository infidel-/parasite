package render.anim;

// decaying positional jitter (amplitude decays to 0 at k=1). phase offsets the wave so two
// shakes on different actors (parasite vs host during a grip struggle) read as out of sync
class Shake extends Effect {
  var amp:Float;     // starting jitter amplitude (world units)
  var phase:Float;   // radians added to the wave so parallel shakes desync

  public function new(ms:Float, amp:Float, phase:Float = 0.0)
    {
      super(ms);
      this.amp = amp;
      this.phase = phase;
    }

  override function compute(k:Float):Void
    {
      var d = (1 - k) * amp;
      offx = d * Math.sin(k * 40 + phase);
      offz = d * Math.cos(k * 37 + phase);
    }
}

package render.anim;

// attack lunge: there-and-back toward (px,pz), zero at k=0 and k=1, peak mid
class Lunge extends Effect {
  var px:Float;    // lunge direction/reach on x
  var pz:Float;

  public function new(ms:Float, px:Float, pz:Float)
    {
      super(ms);
      this.px = px;
      this.pz = pz;
    }

  override function compute(k:Float):Void
    {
      var m = Math.sin(Math.PI * k);
      offx = px * m;
      offz = pz * m;
    }
}

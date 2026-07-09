package render.anim;

import render.RenderConfig;

// melee lunge: a reach toward the target that eases out, dwells briefly at full reach, then eases
// back. the caller-supplied impact beat (sound + target shake + blood burst + attack arc) fires
// once when the reach lands (the apex dwell), so the hit reads at the target before the retreat
class MeleeLunge extends Lunge {
  var onDone:Void->Void;
  var apexFired:Bool = false;            // impact beat fired yet?

  public function new(ms:Float, px:Float, pz:Float, onDone:Void->Void)
    {
      super(ms, px, pz);
      this.onDone = onDone;
    }

  override function compute(k:Float):Void
    {
      var s = RenderConfig.MELEE.apexStart;
      var e = RenderConfig.MELEE.apexEnd;
      // three-phase reach: ease out to full, dwell at full, ease back to rest
      var m;
      if (k < s)
        m = Math.sin(k / s * Math.PI / 2);
      else if (k < e)
        m = 1.0;
      else
        m = Math.sin((1 - k) / (1 - e) * Math.PI / 2);
      offx = px * m;
      offz = pz * m;
      // the reach has landed — fire the impact beat once, before the retreat
      if (!apexFired &&
          k >= s)
        {
          apexFired = true;
          if (onDone != null)
            onDone();
        }
    }
}

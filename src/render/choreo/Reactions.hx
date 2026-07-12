package render.choreo;

import citygen.CityConfig;
import entities.Entity;
import render.RenderConfig;
import render.anim.Shake;

// misc actor-reaction choreography: the small one-shot jitters and fades tied to a single entity
// (grip struggle, resist shake, death fade, body fade-in). thin drivers over the actor layer
class Reactions {

// grip-struggle shake: jitter the parasite and its host out of phase (different amplitude, duration
// and wave phase) so they read as wrestling
  public static function gripStruggle(c:Choreo, parasite:Entity, host:Entity):Void
    {
      var amp = CityConfig.CELL * 0.09;
      c.actors.playFx(parasite, new Shake(RenderConfig.BASE_MS, amp, 0));
      c.actors.playFx(host, new Shake(RenderConfig.BASE_MS * 1.3, amp * 0.7, Math.PI));
    }

// resist shake: jitter an actor as it lurches off in a direction the parasite didn't command (host
// resisting control mid-move)
  public static function resistShake(c:Choreo, e:Entity):Void
    {
      c.actors.playFx(e, new Shake(RenderConfig.BASE_MS, CityConfig.CELL * 0.07, 0));
    }

// snapshot a dying actor into a fade-out ghost (before its entity is nulled)
  public static function deathFade(c:Choreo, e:Entity):Void
    {
      c.actors.startDeathFade(e);
    }

// fade a freshly-spawned corpse body in, but only once the dying sprite has fallen flat (bound to the
// death ghost's landing); falls back to an immediate fade when the view is off
  public static function bindBodyFadeIn(c:Choreo, e:Entity, id:Int, ground:Bool):Void
    {
      if (e != null)
        c.actors.bindBodyFadeIn(e, id, ground);
    }
}

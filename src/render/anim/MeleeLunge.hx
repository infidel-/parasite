package render.anim;

// melee lunge: a there-and-back reach toward the target (Lunge motion) that fires a caller-
// supplied hit callback on landing — the impact beat (sound + target shake + blood burst)
class MeleeLunge extends Lunge {
  var onDone:Void->Void;

  public function new(ms:Float, px:Float, pz:Float, onDone:Void->Void)
    {
      super(ms, px, pz);
      this.onDone = onDone;
    }

  override function onFinish():Void
    {
      if (onDone != null)
        onDone();
    }
}

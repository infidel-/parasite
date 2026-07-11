package render.anim;

import game.Game;

// the parasite's leap off a host back to the ground: from the resting head pose down to the
// ground. detach sound on launch, splat on landing
class LeaveHost extends Leap {
  public function new(game:Game, ms:Float, px:Float, py:Float, pz:Float, arc:Float)
    {
      super(game, ms, px, py, pz, arc);
    }

  override function onStart():Void
    {
      game.scene.sounds.play('parasite-detach');
    }

  override function onFinish():Void
    {
      game.scene.sounds.play('fx-splat2');
    }
}

package render.anim;

import game.Game;

// the parasite's leap onto a host's head: from the ground up to the resting head pose.
// splat on launch, attach sound on landing
class JumpOnFace extends Leap {
  public function new(game:Game, ms:Float, px:Float, py:Float, pz:Float, arc:Float)
    {
      super(game, ms, px, py, pz, arc);
    }

  override function onStart():Void
    {
      game.scene.sounds.play('fx-splat3');
    }

  override function onFinish():Void
    {
      game.scene.sounds.play('parasite-attach');
    }
}

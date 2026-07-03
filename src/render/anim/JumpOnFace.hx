package render.anim;

import game.Game;

// the parasite's leap onto a host's head. offsets are relative to the resting head pose:
// slides in from the ground start (px,pz), rises from below (py, negative) to the head (0),
// with an arc up and over mid-leap. all offsets decay to 0 at k=1 (landed on the head).
// splat on launch, attach sound on landing
class JumpOnFace extends Effect {
  var game:Game;   // for the launch/landing sounds
  var px:Float;    // horizontal start offset from the head, decays to 0
  var py:Float;    // vertical start offset (negative = ground below the head)
  var pz:Float;
  var arc:Float;   // extra height at the peak of the leap

  public function new(game:Game, ms:Float, px:Float, py:Float, pz:Float, arc:Float)
    {
      super(ms);
      this.game = game;
      this.px = px;
      this.py = py;
      this.pz = pz;
      this.arc = arc;
    }

  override function compute(k:Float):Void
    {
      var e = k * k * (3 - 2 * k); // smoothstep
      offx = px * (1 - e);
      offz = pz * (1 - e);
      offy = py * (1 - e) + arc * Math.sin(Math.PI * k);
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

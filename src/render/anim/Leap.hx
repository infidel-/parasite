package render.anim;

import game.Game;

// a leap between poses: offsets slide/rise from a start (px,py,pz) and decay to the resting
// pose (0), arcing up and over mid-flight. subclasses add the launch/landing sounds
class Leap extends Effect {
  var game:Game;   // for the launch/landing sounds
  var px:Float;    // horizontal start offset from the rest pose, decays to 0
  var py:Float;    // vertical start offset from the rest pose, decays to 0
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
}

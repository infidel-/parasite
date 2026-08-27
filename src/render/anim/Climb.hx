package render.anim;

// swinging over something that stands in the way but does not block it — the wilderness highway's
// guard rail is the only one today. the billboard rises, DWELLS at the top with its weight on the
// barrier, then drops back to the resting pose.
//
// purely vertical: the position slide underneath runs its usual smoothstep across the two cells, so
// this lays an arc over a move that was going to happen anyway and never touches where the actor
// ends up. the game does not know the rail exists (nothing is stamped on the tiles for it), which is
// exactly why the effect has to be free of consequences.
//
// the DWELL is the whole difference from render.anim.Leap, whose arc is a pure sine and reads as a
// hop. a vault has a beat at the top, and from a camera 18-55 units up that beat is the only thing
// that separates "climbed over it" from "jumped near it"
class Climb extends Effect {
  static inline var RISE = 0.35;   // progress at which the top is reached
  static inline var DROP = 0.65;   // progress at which the drop begins

  var arc:Float;                   // world height at the top of the swing

  public function new(ms:Float, arc:Float)
    {
      super(ms);
      this.arc = arc;
    }

  override function compute(k:Float):Void
    {
      // sine easing on both ends rather than linear, so neither the takeoff nor the landing has a
      // corner in it — the middle is flat by construction
      if (k < RISE)
        offy = arc * Math.sin(k / RISE * Math.PI / 2);
      else if (k < DROP)
        offy = arc;
      else
        offy = arc * Math.sin((1 - k) / (1 - DROP) * Math.PI / 2);
    }
}

package render.choreo;

// silent-scream choreography (choir of discord): an expanding ghostly dome + a screen-space shockwave
// ripple at the caster cell. 3D port of ParticleSilentScream
class Scream {

// choreograph a silent scream. returns true if the view took over (caller then skips the 2D particle)
  public static function play(c:Choreo, x:Int, y:Int):Bool
    {
      c.shockwave.add(c.actors.scream(x, y));
      return true;
    }
}

package render.choreo;

// thrown-money choreography: a chaotic fountain of tumbling bills flies out of the thrower's cell over
// the throw radius, landing flat and fading, plus lingering money ground stains over the radius (some
// permanent, some fading). 3D port of ParticleMoney + its onDeath ground decal
class Money {

// choreograph a money throw. returns true if the view took over (caller then skips the per-tile 2D
// particles)
  public static function play(c:Choreo, x:Int, y:Int, range:Int):Bool
    {
      c.actors.money(x, y, range);
      c.actors.moneyGround(x, y, range);
      return true;
    }
}

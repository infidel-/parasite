package render.particles;

// holds the live 3D particles for one street view and ticks/draws them each frame. mirrors the
// 2D area particle list. dumb by design (no game ref): each particle carries whatever it needs
class Particles3D {
  public var list:Array<Particle3D> = [];              // live particles

  public function new() {}

// spawn a particle
  public inline function add(p:Particle3D):Void
    list.push(p);

// advance every particle one frame, draw the survivors, cull + finalize the finished ones.
// iterate backwards so splice during the walk is safe
  public function update(dtMs:Float, g:Sprites):Void
    {
      var i = list.length;
      while (i-- > 0)
        {
          var p = list[i];
          if (!p.tick(dtMs))
            {
              p.onDeath();
              list.splice(i, 1);
              continue;
            }
          p.draw(g);
        }
    }

// live particle count (profiler read)
  public inline function count():Int
    return list.length;
}

package render.particles;

// base for a free transient 3D effect (blood droplet, death ghost, future projectiles). the
// 3D analog of particles.Particle: each subclass owns its own lifetime, draws itself onto the
// shared Billboards surface, and may commit lasting state on death. dt-driven (the street loop
// already has dtMs), unlike the 2D wall-clock isDead(), because motion integrates per frame
class Particle3D {
  public function new() {}

// advance one frame; return false when finished (the manager culls it and fires onDeath)
  public function tick(dtMs:Float):Bool
    return true;

// draw this frame onto the shared paint surfaces (p.sprites lit billboards, p.beams bright FX)
  public function draw(p:Paint3D):Void {}

// fired once when the particle is culled (e.g. a landed droplet commits a ground decal)
  public function onDeath():Void {}
}

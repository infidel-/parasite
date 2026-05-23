// mod-side particle: short-lived blood blob that arcs from a source tile to a
// landing tile, then triggers the engine's red splat on death (which lays down
// the ground decal via the standard ParticleSplat onDeath path).
//
// demonstrates how mods can ship custom Particle subclasses without any engine
// change: the SDK extern of particles.Particle is a real prototype chain at
// JS load time, so Haxe `extends` produces a particle the engine's draw loop
// dispatches into virtually (isDead / draw / onDeath).
package;

import particles.Particle;

class ParticleBloodSpurt extends Particle
{
  var srcTile: _Point;
  var dstTile: _Point;
  // precomputed pixel endpoints in camera-local space (matches engine pattern
  // from ParticleNeedle: snapshot at ctor; camera scroll during a 200ms spurt
  // is visually negligible and lets draw stay cheap)
  var srcx: Float;
  var srcy: Float;
  var dstx: Float;
  var dsty: Float;

// constructs a spurt from `from` tile to `to` tile against the given scene
  public function new(s: GameScene, from: _Point, to: _Point)
    {
      super(s);
      srcTile = from;
      dstTile = to;
      var tile = Const.TILE_SIZE;
      srcx = (from.x - s.cameraTileX1) * tile + tile / 2;
      srcy = (from.y - s.cameraTileY1) * tile + tile / 2;
      dstx = (to.x - s.cameraTileX1) * tile + tile / 2;
      dsty = (to.y - s.cameraTileY1) * tile + tile / 2;
      time = 220;
      s.area.addParticle(this);
    }

// draws the blob along a parabolic arc: linear x/y plus sin-bump in y so the
// spurt rises mid-flight and lands at dst. dt ∈ [0..1] (engine-supplied).
// ctx is Dynamic in the extern (browser type resolves to Dynamic in SDK)
  public override function draw(ctx: Dynamic, dt: Float)
    {
      var tile = Const.TILE_SIZE;
      var nx = srcx + (dstx - srcx) * dt;
      var ny = srcy + (dsty - srcy) * dt - Math.sin(dt * Math.PI) * tile * 0.55;
      // radius shrinks slightly toward landing for a "thinning trail" feel
      var r = 2.5 + (1 - dt) * 3.0;
      ctx.save();
      ctx.fillStyle = 'rgb(170,10,10)';
      ctx.globalAlpha = 0.9 * (1 - dt * 0.3);
      ctx.beginPath();
      ctx.arc(nx, ny, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

// on landing, fire the engine's standard red splat at the destination tile;
// pass srcTile so the ground decal cone faces away from the source
  public override function onDeath()
    {
      Particle.createSplat('red', scene, dstTile, srcTile);
    }
}

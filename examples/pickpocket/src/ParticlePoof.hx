// drifting gas cloud for the Burglar King's vanish. a realtime Particle
// (millisecond draw loop) — distinct from the engine's turn-based addEffect
// clouds. each cloud drifts outward from the origin tile over ~1s while fading,
// blitting a panic / paralysis gas frame from the entities effect row.
//
// mod-side Particle subclass: the SDK extern of particles.Particle is a real
// prototype chain at JS load, so the engine's draw loop dispatches our draw()
// virtually with no engine change (same pattern as chainsaw's ParticleBloodSpurt).
package;

import particles.Particle;

class ParticlePoof extends Particle
{
  var ox: Float; // origin pixel x (camera-local)
  var oy: Float; // origin pixel y
  var dx: Float; // drift over lifetime, pixels
  var dy: Float;
  var frame: Int; // gas atlas frame

// fans a cloud out from tile (cx,cy) in one of six directions
  public function new(s: GameScene, cx: Int, cy: Int, dir: Int)
    {
      super(s);
      var tile = Const.TILE_SIZE;
      ox = (cx - s.cameraTileX1) * tile + tile / 2;
      oy = (cy - s.cameraTileY1) * tile + tile / 2;
      var ang = dir * (Math.PI * 2 / 6);
      dx = Math.cos(ang) * tile * 0.8;
      dy = Math.sin(ang) * tile * 0.8;
      frame = (dir % 2 == 0 ?
        Const.FRAME_PANIC_GAS : Const.FRAME_PARALYSIS_GAS);
      time = 1000;
      s.area.addParticle(this);
    }

// blit the gas frame drifting outward, growing slightly while fading out.
// ctx is Dynamic in the extern (browser canvas type resolves to Dynamic)
  public override function draw(ctx: Dynamic, dt: Float): Void
    {
      var tile = Const.TILE_SIZE;
      var nx = ox + dx * dt;
      var ny = oy + dy * dt;
      var size = tile * (0.5 + dt * 0.5);
      ctx.save();
      ctx.globalAlpha = 0.8 * (1 - dt);
      ctx.drawImage(game.scene.images.entities,
        frame * Const.TILE_SIZE_CLEAN,
        Const.ROW_EFFECT * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,
        nx - size / 2,
        ny - size / 2,
        size,
        size);
      ctx.restore();
    }
}

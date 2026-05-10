package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleNeedle extends Particle
{
  var sourceTile: _Point;
  var targetTile: _Point;
  var dstTile: _Point;
  var hit: Bool;
  var bloodType: String;
  var srcx: Float;
  var srcy: Float;
  var dstx: Float;
  var dsty: Float;

// create needle projectile between source and destination tiles
  public function new(
      s: GameScene,
      sx: Int,
      sy: Int,
      dst: _Point,
      hit: Bool,
      ?bloodType: String = 'red')
    {
      super(s);
      sourceTile = {
        x: sx,
        y: sy,
      };
      targetTile = {
        x: dst.x,
        y: dst.y,
      };
      dstTile = {
        x: dst.x,
        y: dst.y,
      };
      this.hit = hit;
      this.bloodType = bloodType;
      time = 150;
      if (!hit)
        dstTile = {
          x: dst.x + Const.roll(-1, 1),
          y: dst.y + Const.roll(-1, 1),
        };
      srcx = (sx - scene.cameraTileX1) * tile + tile / 2;
      srcy = (sy - scene.cameraTileY1) * tile + tile / 2;
      dstx = (dstTile.x - scene.cameraTileX1) * tile + tile / 2;
      dsty = (dstTile.y - scene.cameraTileY1) * tile + tile / 2;
      game.scene.area.addParticle(this);
    }

// draw flying needle and faint trailing afterimages
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var dx = dstx - srcx;
      var dy = dsty - srcy;
      var len = Math.sqrt(dx * dx + dy * dy);
      var angle = 0.0;
      var tx = 0.0;
      var ty = 0.0;
      if (len > 0.0001)
        {
          tx = dx / len;
          ty = dy / len;
          angle = Math.atan2(ty, tx);
        }
      var nx = srcx + dx * dt;
      var ny = srcy + dy * dt;
      var alpha = 1.0;
      if (dt > 0.82)
        alpha = (1 - dt) / 0.18;
      if (alpha < 0)
        alpha = 0;

      for (i in 0...2)
        {
          var trail = tile * (0.24 + i * 0.18);
          drawNeedle(ctx,
            nx - tx * trail,
            ny - ty * trail,
            angle,
            tile * (0.42 - i * 0.06),
            alpha * (0.38 - i * 0.12));
        }
      drawNeedle(ctx, nx, ny, angle, tile * 0.54, alpha);
    }

// spawn blood splat when needle reaches target tile
  public override function onDeath()
    {
      if (hit)
        Particle.createSplat(bloodType, scene, targetTile, sourceTile);
    }

// draw one needle sprite
  function drawNeedle(
      ctx: CanvasRenderingContext2D,
      x: Float,
      y: Float,
      angle: Float,
      size: Float,
      alpha: Float)
    {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.translate(x, y);
      ctx.rotate(angle);
      ctx.drawImage(game.scene.images.entities,
        Const.FRAME_PARTICLE_PARALYSIS_SPIT * Const.TILE_SIZE_CLEAN,
        Const.ROW_EFFECT * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        -size / 2,
        -size / 2,
        size,
        size);
      ctx.restore();
    }
}

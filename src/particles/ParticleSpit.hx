package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleSpit extends Particle
{
  var type: String;
  var dstTile: _Point;
  var frame: Int;
  var srcx: Float;
  var srcy: Float;
  var dstx: Float;
  var dsty: Float;
  var dripSide: Array<Float>;

// create spit projectile between source and destination tiles
  public function new(
      s: GameScene,
      type: String,
      sx: Int,
      sy: Int,
      dst: _Point)
    {
      super(s);
      this.type = type;
      this.dstTile = { x: dst.x, y: dst.y };
      time = 150;
      frame = getFrame(type);
      srcx = (sx - scene.cameraTileX1) * tile + tile / 2;
      srcy = (sy - scene.cameraTileY1) * tile + tile / 2;
      dstx = (dst.x - scene.cameraTileX1) * tile + tile / 2;
      dsty = (dst.y - scene.cameraTileY1) * tile + tile / 2;
      dripSide = [];
      for (i in 0...3)
        dripSide.push((Std.random(100) / 100) * 2 - 1);
      game.scene.area.addParticle(this);
    }

// draw main spit blob and smaller trail drips
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var dx = dstx - srcx;
      var dy = dsty - srcy;
      var len = Math.sqrt(dx * dx + dy * dy);
      var angle = 0.0;
      var nx = srcx + dx * dt;
      var ny = srcy + dy * dt;
      var tx = 0.0;
      var ty = 0.0;
      if (len > 0.0001)
        {
          tx = dx / len;
          ty = dy / len;
          angle = Math.atan2(ty, tx);
        }
      var px = -ty;
      var py = tx;
      var alpha = 1.0;
      if (dt > 0.8)
        alpha = (1 - dt) / 0.2;
      if (alpha < 0)
        alpha = 0;

      // draw trailing smaller drips with slight lateral spread
      var mainSize = tile * (0.34 - dt * 0.04);
      if (mainSize < tile * 0.26)
        mainSize = tile * 0.26;
      for (i in 0...3)
        {
          var trail = tile * (0.28 + i * 0.24);
          var dripX = nx - tx * trail;
          var dripY = ny - ty * trail;
          var wobble = Math.sin(dt * 10 + i * 1.5) * tile * 0.04;
          dripX += px * (dripSide[i] * tile * 0.10 + wobble);
          dripY += py * (dripSide[i] * tile * 0.10 + wobble);

          var scale = 0.92 - i * 0.12;
          var dripSize = mainSize * scale;
          drawBlob(ctx, dripX, dripY, dripSize, alpha * (0.9 - i * 0.15), angle);
        }

      // draw main projectile blob on top
      drawBlob(ctx, nx, ny, mainSize, alpha, angle);
    }

// spawn splat when projectile reaches target tile
  public override function onDeath()
    {
      switch (type)
        {
          case 'acidSpit':
            Particle.createSplat('acid', scene, dstTile);
          case 'slimeSpit':
            Particle.createSplat('slime', scene, dstTile);
          default:
        }
    }

// resolve frame from spit type
  function getFrame(type: String): Int
    {
      switch (type)
        {
          case 'acidSpit':
            return Const.FRAME_PARTICLE_ACID_SPIT;
          case 'slimeSpit':
            return Const.FRAME_PARTICLE_SLIME_SPIT;
          case 'paralysisSpit':
            return Const.FRAME_PARTICLE_PARALYSIS_SPIT;
          default:
            return Const.FRAME_PARTICLE_ACID_SPIT;
        }
    }

// draw one spit sprite blob at requested size and opacity
  function drawBlob(
      ctx: CanvasRenderingContext2D,
      x: Float,
      y: Float,
      size: Float,
      alpha: Float,
      angle: Float)
    {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.translate(x, y);
      ctx.rotate(angle);
      ctx.drawImage(game.scene.images.entities,
        frame * Const.TILE_SIZE_CLEAN,
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

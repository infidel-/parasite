// shotgun shot
package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleShotgun extends Particle
{
  // area x,y
  var sx: Int;
  var sy: Int;
  var dstreal: _Point;
  var dst: Array<_Point>; // destination point (can be AI or player)
  var delta: Array<_Point>; // slight delta for each shot
  var hit: Bool;

  public function new(s: GameScene, sx: Int, sy: Int, pt: _Point, hit: Bool)
    {
      super(s);
      this.sx = sx;
      this.sy = sy;
      this.dst = [];
      var numShots = 5;
      for (i in 0...numShots)
        this.dst[i] = pt;
      this.dstreal = pt;
      this.time = 50;
      this.hit = hit;
      if (!hit)
        for (i in 0...numShots)
          this.dst[i] = {
            x: pt.x + Const.roll(-1, 1),
            y: pt.y + Const.roll(-1, 1)
          };
      this.delta = [];
      var spread = Std.int(tile / 4);
      for (i in 0...numShots)
        this.delta[i] = {
          x: Const.roll(- spread, spread),
          y: Const.roll(- spread, spread)
        };
      game.scene.area.addParticle(this);
    }

// draws multiple lines
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      for (i in 0...dst.length)
        drawLine(ctx, dt, dst[i], delta[i]);
    }

// draw one line
  function drawLine(ctx: CanvasRenderingContext2D, dt: Float, dst: _Point, delta: _Point)
    {
      // find nearest tile edge to target
      var dsrc = Const.distanceSign(
        sx, sy,
        this.dstreal.x, this.dstreal.y);
      var ddst = Const.distanceSign(
        this.dstreal.x, this.dstreal.y,
        sx, sy);
      // when src and dst are near, start line from center of tile
      var xFromCenter = false;
      if (Math.abs(this.dstreal.x - sx) == 1)
        xFromCenter = true;
      var yFromCenter = false;
      if (Math.abs(this.dstreal.y - sy) == 1)
        yFromCenter = true;

      ctx.beginPath();
      var srcx = (sx - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : dsrc.x * tile / 2);
      var srcy = (sy - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : dsrc.y * tile / 2);
      var dstx = (dst.x - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : ddst.x * tile / 2) + delta.x;
      var dsty = (dst.y - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : ddst.y * tile / 2) + delta.y;
      ctx.moveTo(srcx, srcy);
      ctx.lineTo(srcx + (dstx - srcx) * dt,
        srcy + (dsty - srcy) * dt);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
      ctx.lineWidth = 3;
      ctx.stroke();
    }

// create splat on death
  public override function onDeath()
    {
      if (hit)
        new ParticleSplat(scene, dstreal);
    }
}

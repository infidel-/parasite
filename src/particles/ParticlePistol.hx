// pistol shot
package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticlePistol extends Particle
{
  // area x,y
  var sx: Int;
  var sy: Int;
  var dst: _Point; // destination point (can be AI or player)
  var hit: Bool;

  public function new(s: GameScene, sx: Int, sy: Int, dst: _Point, hit: Bool)
    {
      super(s);
      this.sx = sx;
      this.sy = sy;
      this.dst = dst;
      this.time = 50;
      this.hit = hit;
      if (!hit)
        this.dst = {
          x: dst.x + Const.roll(-2, 2),
          y: dst.y + Const.roll(-2, 2)
        };
      game.scene.area.addParticle(this);
    }

// draws a line
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      // find nearest tile edge to target
      var dsrc = Const.distanceSign(
        sx, sy,
        dst.x, dst.y);
      var ddst = Const.distanceSign(
        dst.x, dst.y,
        sx, sy);
      // when src and dst are near, start line from center of tile
      var xFromCenter = false;
      if (Math.abs(dst.x - sx) == 1)
        xFromCenter = true;
      var yFromCenter = false;
      if (Math.abs(dst.y - sy) == 1)
        yFromCenter = true;

      ctx.beginPath();
      var srcx = (sx - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : dsrc.x * tile / 2);
      var srcy = (sy - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : dsrc.y * tile / 2);
      var dstx = (dst.x - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : ddst.x * tile / 2);
      var dsty = (dst.y - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : ddst.y * tile / 2);
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
        new ParticleSplat(scene, dst);
    }
}

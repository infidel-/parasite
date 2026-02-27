// pistol shot
package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticlePistol extends ParticleBullet
{
  // area x,y
  var sx: Int;
  var sy: Int;
  var dst: _Point; // destination point (can be AI or player)
  var hit: Bool;
  var bloodType: String;
  var srcx: Float;
  var srcy: Float;
  var dstx: Float;
  var dsty: Float;

  public function new(s: GameScene, sx: Int, sy: Int, dstp: _Point, hit: Bool,
      ?bloodType: String = 'red')
    {
      super(s);
      this.sx = sx;
      this.sy = sy;
      this.dst = dstp;
      this.time = 50;
      this.hit = hit;
      this.bloodType = bloodType;
      if (!hit)
        this.dst = {
          x: dst.x + Const.roll(-2, 2),
          y: dst.y + Const.roll(-2, 2)
        };
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

      srcx = (sx - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : dsrc.x * tile / 2);
      srcy = (sy - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : dsrc.y * tile / 2);
      dstx = (dst.x - scene.cameraTileX1) * tile +
        tile / 2 + (xFromCenter ? 0 : ddst.x * tile / 2);
      dsty = (dst.y - scene.cameraTileY1) * tile +
        tile / 2 + (yFromCenter ? 0 : ddst.y * tile / 2);

      game.scene.area.addParticle(this);
    }

// draws a line
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      drawLine(ctx, srcx, srcy, dstx, dsty, dt);
    }

// create splat on death
  public override function onDeath()
    {
      if (hit)
        Particle.createSplat(bloodType, scene, dst);
      game.scene.sounds.play('attack-bullet-' +
        (hit ? 'hit' : 'miss'), {
        always: true,
        delay: (hit ? 60 : 40),
        x: dst.x, 
        y: dst.y
      });
    }
}

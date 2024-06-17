// generic bullet particle
package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleBullet extends Particle
{
  var hitWindow: Bool;
  var lineWidth: Int;
  var lineDash: Array<Float>;

  public function new(s: GameScene)
    {
      super(s);
      time = 0;
      lineWidth = 3;
      lineDash = [];
    }

// line drawing function
  public function drawLine(
      ctx: CanvasRenderingContext2D,
      srcx: Float, srcy: Float,
      dstx: Float, dsty: Float, dt: Float)
    {
      var nx = srcx + (dstx - srcx) * dt;
      var ny = srcy + (dsty - srcy) * dt;
      var ax = Math.floor((scene.cameraX + nx) / tile);
      var ay = Math.floor((scene.cameraY + ny) / tile);
      var t = game.area.getCellType(ax, ay);
      if (Const.isWindowTile(t) && !hitWindow)
        {
          hitWindow = true;
          game.scene.sounds.play('attack-bullet-glass');
        }
      ctx.beginPath();
      if (lineDash.length > 0)
        ctx.setLineDash(lineDash);
      ctx.moveTo(srcx, srcy);
      ctx.lineTo(nx, ny);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.5)';
      ctx.lineWidth = lineWidth;
      ctx.stroke();
      if (lineDash.length > 0)
        ctx.setLineDash([]);
    }
}

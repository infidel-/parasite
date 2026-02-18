// choir silent scream pulse particle
package particles;

import js.html.CanvasRenderingContext2D;
import Const.TILE_SIZE as tile;

class ParticleSilentScream extends Particle
{
  var pt: _Point;
  var ringOffsets: Array<Float>;
  var maxRadius: Float;

// create pulse at caster tile
  public function new(s: GameScene, pt: _Point)
    {
      super(s);
      this.pt = pt;
      this.time = 320;
      this.ringOffsets = [ 0.0, 0.18, 0.36 ];
      this.maxRadius = tile * 5;
      game.scene.area.addParticle(this);
    }

// draw concentric pulse rings
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var visualDT = dt;
      if (visualDT >= 1)
        visualDT = 0.85;

      var cx = (pt.x - scene.cameraTileX1) * tile + tile / 2;
      var cy = (pt.y - scene.cameraTileY1) * tile + tile / 2;

      // draw center flash
      if (visualDT < 0.25)
        {
          var flashAlpha = (0.25 - visualDT) / 0.25 * 0.40;
          ctx.beginPath();
          ctx.arc(cx, cy,
            tile * 0.20 + visualDT * tile * 0.16,
            0, Math.PI * 2, false);
          ctx.fillStyle = 'rgba(60, 60, 60, ' + flashAlpha + ')';
          ctx.fill();
        }

      // draw staggered expanding rings
      for (i in 0...ringOffsets.length)
        {
          var ringDT = (visualDT - ringOffsets[i]) / (1 - ringOffsets[i]);
          if (ringDT < 0 ||
              ringDT > 1)
            continue;

          var radius = tile * 0.2 + maxRadius * ringDT;
          var alpha = 0.08 + (1 - ringDT) * (0.60 - i * 0.10);
          if (alpha <= 0)
            continue;

          ctx.beginPath();
          ctx.arc(cx, cy, radius, 0, Math.PI * 2, false);
          ctx.lineWidth = 5.5 - ringDT * 1.6;
          if (ctx.lineWidth < 1.5)
            ctx.lineWidth = 1.5;
          ctx.strokeStyle = 'rgba(35, 35, 35, ' + alpha + ')';
          ctx.stroke();

          // draw soft outer fringe
          ctx.beginPath();
          ctx.arc(cx, cy, radius + 1.5, 0, Math.PI * 2, false);
          ctx.lineWidth = 1.5;
          ctx.strokeStyle = 'rgba(200, 200, 200, ' + alpha * 0.55 + ')';
          ctx.stroke();
        }
    }
}

package render.particles;

import three.Three;
import render.RenderConfig;

// a dying actor's last sprite, eased out while the body billboard fades in — the crossfade that
// replaces the hard cut from actor to corpse. purely visual; commits nothing on death
class DeathFade3D extends Particle3D {
  static inline var FADE_SPEED = 0.5;                  // fades at this * base anim speed (slower, like the LOS fade)

  var tex:CanvasTexture;
  var x:Float; var y:Float; var z:Float;
  var scale:Float;
  var op:Float;

  public function new(tex:CanvasTexture, x:Float, y:Float, z:Float, scale:Float, op:Float)
    {
      super();
      this.tex = tex;
      this.x = x; this.y = y; this.z = z;
      this.scale = scale;
      this.op = op;
    }

// ease opacity toward invisible; return false once effectively gone
  override public function tick(dtMs:Float):Bool
    {
      op -= dtMs * RenderConfig.ANIM_SPEED / RenderConfig.BASE_MS * FADE_SPEED;
      return op > 0.02;
    }

// draw the fading ghost upright
  override public function draw(p:Paint3D):Void
    {
      p.sprites.paint(x, y, z, tex, op, scale, false);
    }
}

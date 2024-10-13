package particles;

import js.html.CanvasRenderingContext2D;
import js.Browser;
import Const.TILE_SIZE as tile;

class ParticleMoney extends Particle
{
  // area x,y
  var pt: _Point;

  public function new(s: GameScene, pt: _Point)
    {
      super(s);
      this.pt = pt;
      this.time = 80;
      game.scene.area.addParticle(this);
    }

// scale image
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var dsize = dt * tile;
      ctx.drawImage(game.scene.images.entities,
        Const.FRAME_EFFECT_MONEY * Const.TILE_SIZE_CLEAN,
        Const.ROW_EFFECT * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        (pt.x - game.scene.cameraTileX1) * tile + tile / 2 - dsize / 2,
        (pt.y - game.scene.cameraTileY1) * tile + tile / 2 - dsize / 2,
        dsize,
        dsize);
    }

// create ground splat on death
  public override function onDeath()
    {
      var e = game.scene.area.addEffect(pt.x, pt.y, 2,
        Const.FRAME_EFFECT_MONEY);
      e.randomizeScale(0.9);
      e.randomizeAngle();
      e.randomizeDelta();
      Browser.window.setTimeout(game.scene.updateCamera, 1);
    }
}

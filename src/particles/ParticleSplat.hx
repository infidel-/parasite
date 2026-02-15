package particles;

import js.html.CanvasRenderingContext2D;
import objects.DecorationExt;
import Const.TILE_SIZE as tile;

class ParticleSplat extends Particle
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
        Const.BLOOD_LARGE * Const.TILE_SIZE_CLEAN,
        Const.ROW_BLOOD * Const.TILE_SIZE_CLEAN + 1,
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
      var o = new DecorationExt(game, game.area.id,
        pt.x, pt.y, Const.ROW_BLOOD,
        Const.roll(0, Const.BLOOD_NUM - 1));
      o.isStatic = false;
      game.area.addObject(o);
    }
}

package particles;

import js.html.CanvasRenderingContext2D;
import objects.DecorationExt;
import Const.TILE_SIZE as tile;

class ParticleSplat extends Particle
{
  public static var SPLAT_NUM = 5;

  // area x,y
  var pt: _Point;
  var row: Int;
  var firstCol: Int;

  public function new(s: GameScene, type: String, pt: _Point)
    {
      super(s);
      this.pt = pt;
      row = Const.ROW_BLOOD;
      firstCol = Const.BLOOD_LARGE;
      switch (type)
        {
          case 'black':
            row = Const.ROW_BLOOD;
            firstCol = Const.BLACK_BLOOD_LARGE;
          case 'acid':
            row = Const.ROW_SPACESHIP1;
            firstCol = Const.ACID_LARGE;
          case 'slime':
            row = Const.ROW_SPACESHIP2;
            firstCol = Const.SLIME_LARGE;
          default:
        }
      this.time = 80;
      game.scene.area.addParticle(this);
    }

// scale image
  public override function draw(ctx: CanvasRenderingContext2D, dt: Float)
    {
      var dsize = dt * tile;
      ctx.drawImage(game.scene.images.entities,
        firstCol * Const.TILE_SIZE_CLEAN,
        row * Const.TILE_SIZE_CLEAN + 1,
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
        pt.x, pt.y, row,
        Const.roll(firstCol, firstCol + SPLAT_NUM - 1));
      o.isStatic = false;
      game.area.addObject(o);
    }
}

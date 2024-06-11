// engine entity

package entities;

import js.html.CanvasRenderingContext2D;
import js.html.Image;
import game.Game;
import Const.TILE_SIZE as tile;
import Const.TILE_SIZE_CLEAN as tileClean;

class Entity
{
  var game: Game; // game state
  public var type: String;
  public var isMaleAtlas: Bool;
  // new draw
  // entities image (entities, male, female)
  var imageName: String;
  // image tile x,y
  var ix: Int;
  var iy: Int;
  // map x,y
  var mx: Int;
  var my: Int;
  public var scale: Float;
  public var angle: Float;
  // displacement inside of tile
  public var dx: Int;
  public var dy: Int;


  public function new(g: Game, layer: Int)
    {
      game = g;
      imageName = 'entities';
      ix = iy = mx = my = 0;
      type = 'undefined';
      isMaleAtlas = false;
      scale = 1.0;
      angle = 0.0;
      dx = 0;
      dy = 0;
    }

// is currently on screen?
  public inline function isVisible(): Bool
    {
      if (mx >= game.scene.cameraTileX1 - 1 &&
          my >= game.scene.cameraTileY1 - 1 &&
          mx <= game.scene.cameraTileX2 + 2 &&
          my <= game.scene.cameraTileY2 + 2)
        return true;
      else return false;
    }

// draw image at this entity x,y
  function drawImage(ctx: CanvasRenderingContext2D, img: Image, xx: Int, yy: Int)
    {
      // full display
      if (scale != 1.0 || angle != 0.0)
        {
          drawImageFull(ctx, img, xx, yy);
          return;
        }

      // simple tile draw
      // kludge: draw one pixel less to avoid scaling bugs
      ctx.drawImage(img,
        xx * tileClean,
        yy * tileClean + 1,
        tileClean,
        tileClean - 1,

        (mx - game.scene.cameraTileX1) * tile,
        (my - game.scene.cameraTileY1) * tile,
        tile * scale,
        tile * scale);
    }

// with scale/rotation/displacement
  function drawImageFull(ctx: CanvasRenderingContext2D, img: Image, xx: Int, yy: Int)
    {
      // apply scale to x,y
      var ex: Float = (mx - game.scene.cameraTileX1) * tile;
      var ey: Float = (my - game.scene.cameraTileY1) * tile;
      if (scale != 1.0)
        {
          ex += tile / 2 - tile * scale / 2;
          ey += tile / 2 - tile * scale / 2;
        }
      // apply rotation in place
      ctx.save();
      ctx.translate(ex + tile * scale / 2, ey + tile * scale / 2);
      ctx.rotate(angle);
      ctx.translate(- tile * scale / 2, - tile * scale / 2);

      // kludge: draw one pixel less to avoid scaling bugs
      ctx.drawImage(img,
        xx * tileClean, yy * tileClean + 1,
        tileClean, tileClean - 1,
        dx, dy, tile * scale, tile * scale);

      // restore context state
      ctx.restore();
    }

// set entity icon
  public function setIcon(img: String, ix: Int, iy: Int)
    {
      this.imageName = img;
      this.ix = ix;
      this.iy = iy;
    }


// set position on map (calc from map x,y)
  public function setPosition(mx: Int, my: Int)
    {
      this.mx = mx;
      this.my = my;
    }

// draw entity on map
  public function draw(ctx: CanvasRenderingContext2D)
    {
      var img = null;
      switch (imageName)
        {
          case 'entities':
            img = game.scene.images.entities;
          case 'male':
            img = game.scene.images.male;
          case 'female':
            img = game.scene.images.female;
            // NOTE: some specials only have male image (security, etc)
            if (isMaleAtlas)
              img = game.scene.images.male;
          default:
            trace('UNKNOWN IMAGE: ' + imageName);
            return;
        }
      // entity image
      drawImage(ctx, img, ix, iy);
    }
}

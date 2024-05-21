// engine entity

package entities;

import js.html.CanvasRenderingContext2D;
import js.html.Image;
import game.Game;

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


  public function new(g: Game, layer: Int)
    {
      game = g;
      imageName = 'entities';
      ix = iy = mx = my = 0;
      type = 'undefined';
      isMaleAtlas = false;
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
      // kludge: draw one pixel less to avoid scaling bugs
      ctx.drawImage(img,
        xx * Const.TILE_SIZE_CLEAN,
        yy * Const.TILE_SIZE_CLEAN + 1,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN - 1,

        (mx - game.scene.cameraTileX1) * Const.TILE_SIZE,
        (my - game.scene.cameraTileY1) * Const.TILE_SIZE,
        Const.TILE_SIZE,
        Const.TILE_SIZE);
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

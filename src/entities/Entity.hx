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
  public var isMaleAtlas: Bool;
  public var skinColor: Int; // 3D actor skin tone (mirrors AIData.skinColor; 0 for non-actors)
  // new draw
  // entities image (entities, male, female)
  public var imageName: String;
  // image tile x,y
  public var ix: Int;
  public var iy: Int;
  // map x,y
  public var mx: Int;
  public var my: Int;
  // render hint: next slide is a real contiguous multi-cell move (push-past swap + own
  // AI move applied atomically in one turn), so the slide must not treat the 2-cell jump
  // as a teleport and snap. consumed (reset) once by the renderer. see render.ActorAnim.slideTo
  public var slideNoSnap: Bool;


  public function new(g: Game)
    {
      game = g;
      imageName = 'entities';
      ix = iy = mx = my = 0;
      isMaleAtlas = false;
      skinColor = 0;
      slideNoSnap = false;
    }

// draw image at this entity x,y (region map)
  function drawImage(ctx: CanvasRenderingContext2D, img: Image, xx: Int, yy: Int)
    {
      // kludge: draw one pixel less to avoid scaling bugs
      ctx.drawImage(img,
        xx * tileClean,
        yy * tileClean + 1,
        tileClean,
        tileClean - 1,

        (mx - game.scene.cameraTileX1) * tile,
        (my - game.scene.cameraTileY1) * tile,
        tile,
        tile);
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

// draw entity on the region map (areas draw through render.View)
  public function draw(ctx: CanvasRenderingContext2D)
    {
      var img = game.scene.images.getImage(imageName, isMaleAtlas);
      if (img == null)
        {
          trace('UNKNOWN IMAGE: ' + imageName);
          return;
        }
      if (!img.complete ||
          img.naturalWidth <= 0)
        return;
      // entity image
      drawImage(ctx, img, ix, iy);
    }
}

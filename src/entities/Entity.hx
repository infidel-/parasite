// engine entity

package entities;

import js.html.CanvasRenderingContext2D;
import game.Game;
import Const.TILE_SIZE as tile;

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

// draw one atlas cell at this entity's map spot (region map), off whichever sheet holds its pixels
// (render.particles.Sprites.atlasFor): the host sheets and the parasite come off the 3D's 128 px art
// at half size. a negative column is "no cell" (the mask with no host)
  function drawCell(ctx: CanvasRenderingContext2D, name: String, xx: Int, yy: Int)
    {
      if (xx < 0)
        return;
      var src = render.particles.Sprites.atlasFor(game.scene.images, name, xx, yy, isMaleAtlas, skinColor);
      var img = src.img;
      if (img == null)
        {
          trace('UNKNOWN IMAGE: ' + name);
          return;
        }
      if (!img.complete ||
          img.naturalWidth <= 0)
        return;
      var t = src.t;
      // kludge: draw one source pixel less to avoid scaling bugs
      ctx.drawImage(img,
        src.ix * t,
        src.iy * t + 1,
        t,
        t - 1,

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
      drawCell(ctx, imageName, ix, iy);
    }
}

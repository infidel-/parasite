// engine entity

package entities;

import js.html.CanvasRenderingContext2D;
import h2d.Object;

import game.Game;

class Entity
{
  var game: Game; // game state
  var _container: Object;
  public var type: String;
  public var isMaleAtlas: Bool;
  public var visible(get, set): Bool;
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
      _container = new Object();
      game.scene.add(_container, layer);
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
      _container.x = mx * Const.TILE_SIZE - game.scene.cameraX;
      _container.y = my * Const.TILE_SIZE - game.scene.cameraY;
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
      ctx.drawImage(img,
        ix * Const.TILE_SIZE_CLEAN, 
        iy * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,

        (mx * Const.TILE_SIZE_CLEAN - game.scene.cameraX) * game.config.mapScale,
        (my * Const.TILE_SIZE_CLEAN - game.scene.cameraY) * game.config.mapScale,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN);
    }


// remove from scene
  public function remove()
    {
      _container.removeChildren();
      _container.remove();
      _container = null;
    }

  function get_visible()
    {
      return _container.visible;
    }


  function set_visible(v: Bool)
    {
      return _container.visible = v;
    }
}

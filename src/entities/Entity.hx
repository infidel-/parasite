// engine entity

package entities;

import h2d.Object;

import game.Game;

class Entity
{
  var game: Game; // game state
  var _container: Object;
  public var type: String;
  public var visible(get, set): Bool;


  public function new(g: Game)
    {
      game = g;
      type = 'undefined';
      _container = new Object(game.scene);
    }


// set position on map (calc from map x,y)
  public inline function setPosition(mx: Int, my: Int)
    {
      _container.x = mx * Const.TILE_WIDTH - game.scene.cameraX;
      _container.y = my * Const.TILE_HEIGHT - game.scene.cameraY;
    }


// remove from scene
  public inline function remove()
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

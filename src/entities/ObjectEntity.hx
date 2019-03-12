// objects engine entity

package entities;

import objects.AreaObject;
import game.Game;

class ObjectEntity // extends Entity
{
  var game: Game; // game state
  var object: AreaObject; // object link

  var type: String; // temp
/*
  var _list: Graphiclist; // graphics list
  var _spriteBody: Spritemap; // body sprite map
*/


  public function new(o: AreaObject, g: Game, xx: Int, yy: Int,
      atlasRow: Int, atlasCol: Int)
    {
//      super(xx * Const.TILE_WIDTH, yy * Const.TILE_HEIGHT);

      game = g;
      object = o;
      trace('object entity');
/*
      _list = new Graphiclist();
      _spriteBody = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteBody.setFrame(atlasCol, atlasRow);
      _list.add(_spriteBody);
*/

      type = "undefined";
//      layer = Const.LAYER_OBJECT;
//      graphic = _list;
    }


// set position on map
  public inline function setPosition(vx: Int, vy: Int)
    {
//      x = vx * Const.TILE_WIDTH;
//      y = vy * Const.TILE_HEIGHT;
    }


// set image index
  public inline function setImage(index: Int)
    {
//      _spriteBody.frame = index;
    }


// get image index
  public inline function getImage(): Int
    {
//      return _spriteBody.frame;
      return 0;
    }
}

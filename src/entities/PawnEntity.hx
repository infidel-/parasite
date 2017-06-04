// pawn (AI, player) engine entity

package entities;

import com.haxepunk.Entity;
import com.haxepunk.graphics.Graphiclist;
import com.haxepunk.graphics.Spritemap;
import com.haxepunk.graphics.Text;

import game.Game;

class PawnEntity extends Entity
{
  var game: Game; // game state

  var _text: Text;
  var _list: Graphiclist; // graphics list
  var _spriteBody: Spritemap; // body sprite map
  var _spriteMask: Spritemap; // mask sprite map (invaded state)
  public var atlasRow: Int; // tile atlas row

  var _textTimer: Int; // turns left to display this text


  public function new(g: Game, xx: Int, yy: Int, r: Int)
    {
      super(xx * Const.TILE_WIDTH, yy * Const.TILE_HEIGHT);

      game = g;
      atlasRow = r;
      _list = new Graphiclist();
      _spriteBody = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteBody.setFrame(Const.FRAME_DEFAULT, atlasRow);
      _spriteMask = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteMask.frame = Const.FRAME_EMPTY;
      _list.add(_spriteBody);
      _list.add(_spriteMask);

      _text = new Text("", 0, -10);
      _textTimer = 0;
      _list.add(_text);

      type = "undefined";
      layer = Const.LAYER_AI;
      graphic = _list;
    }


// set text
  public inline function setText(s: String, timer: Int)
    {
      _text.text = s;
      _text.x = - (_text.textWidth - Const.TILE_WIDTH) / 2;
      _textTimer = timer;
    }


// turn passed
  public function turn()
    {
      if (_textTimer <= 0)
        return;

      _textTimer--;
      if (_textTimer == 0)
        _text.text = '';
    }


// set position on map
  public inline function setPosition(vx: Int, vy: Int)
    {
      x = vx * Const.TILE_WIDTH;
      y = vy * Const.TILE_HEIGHT;
    }


// set body image index
  public inline function setImage(col: Int, ?row: Int)
    {
      _spriteBody.setFrame(col, (row == null ? atlasRow : row));
    }


// get body image index
  public inline function getImage(): Int
    {
      return _spriteBody.frame;
    }


// set mask image index
  public inline function setMask(col: Int, ?row: Int)
    {
      _spriteMask.setFrame(col, (row == null ? atlasRow : row));
    }

/*
// moveTo() wrapper that uses tile x, y
  public inline function setPosition(vx: Int, vy: Int)
    {
      moveTo(vx * Const.TILE_WIDTH, vy * Const.TILE_HEIGHT);
    }
*/
}

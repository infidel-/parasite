// pawn (AI, player) engine entity

package entities;

import h2d.Bitmap;
import h2d.Object;

import game.Game;

class PawnEntity extends Entity
{

/*
  var _text: BitmapText;
  var _list: Graphiclist; // graphics list
*/
  var _spriteBody: Bitmap; // body sprite
  var _spriteMask: Bitmap; // mask sprite map (invaded state)
  public var atlasRow: Int; // tile atlas row

  var _textTimer: Int; // turns left to display this text


  public function new(g: Game, xx: Int, yy: Int, r: Int)
    {
      super(g);
      type = 'pawn';
      trace('PawnEntity');
      atlasRow = r;

      _spriteBody = new Bitmap(
        game.scene.entityAtlas[Const.FRAME_DEFAULT][atlasRow], _container);
      _spriteMask = null;
/*
      _spriteMask = new Spritemap(game.scene.entityAtlas,
        Const.TILE_WIDTH, Const.TILE_HEIGHT);
      _spriteMask.frame = Const.FRAME_EMPTY;
      _list.add(_spriteMask);

      _text = new BitmapText("", 0, -10);
      _textTimer = 0;
      _list.add(_text);

      layer = Const.LAYER_AI;
*/
      setPosition(xx, yy);
    }


// set text
  public inline function setText(s: String, timer: Int)
    {
//      _text.text = s;
//      _text.x = - (_text.textWidth - Const.TILE_WIDTH) / 2;
//      _textTimer = timer;
    }


// turn passed
  public function turn()
    {
      if (_textTimer <= 0)
        return;

      _textTimer--;
//      if (_textTimer == 0)
//        _text.text = '';
    }


// set body image index
  public inline function setImage(col: Int, ?row: Int)
    {
//      _spriteBody.setFrame(col, (row == null ? atlasRow : row));
    }


// get body image index
  public inline function getImage(): Int
    {
//      return _spriteBody.frame;
      return 0;
    }


// set mask image index
  public inline function setMask(col: Int, ?row: Int)
    {
      trace('setMask ' + col + ' ' + row);
      // no mask, remove image
      if (col == 0)
        {
          if (_spriteMask == null)
            return;

          _spriteMask.remove();
          _spriteMask = null;
          return;
        }

      // skip same image
      var tile = game.scene.entityAtlas[col]
        [(row == null ? atlasRow : row)];
      if (_spriteMask != null && _spriteMask.tile == tile)
        return;

      if (_spriteMask != null)
        _spriteMask.remove();
      _spriteMask = new Bitmap(tile, _container);
    }
}

// pawn (AI, player) engine entity

package entities;

import h2d.Bitmap;
import h2d.Graphics;
import h2d.Text;

import game.Game;

class PawnEntity extends Entity
{

  var _text: Text;
  var _textBack: Graphics;
  var _spriteBody: Bitmap; // body sprite
  var _spriteMask: Bitmap; // mask sprite map (invaded state)
  public var atlasRow: Int; // tile atlas row

  var _textTimer: Int; // turns left to display this text


  public function new(g: Game, xx: Int, yy: Int, r: Int)
    {
      super(g, Const.LAYER_AI);
      type = 'pawn';
      atlasRow = r;

      _spriteBody = new Bitmap(
        game.scene.entityAtlas[Const.FRAME_DEFAULT][atlasRow], _container);
      _spriteMask = null;
      _text = null;
      _textBack = null;
      _textTimer = 0;
      setPosition(xx, yy);
    }


// set text
  public function setText(s: String, timer: Int)
    {
      if (_text == null)
        {
          _textBack = new Graphics(_container);
          _text = new Text(hxd.res.DefaultFont.get(), _container);
        }
      else _textBack.clear();
/*
      _text.scale(1.2);
      _text.dropShadow = {
        dx: 1,
        dy: 1,
        color: 0,
        alpha: 1 
      };
*/
      _text.textColor = 0xffffff;
      _text.text = s;
      _text.x = - (_text.textWidth - Const.TILE_WIDTH) / 2;
      _textTimer = timer;

      var bounds = _text.getBounds(_container);
      var size = _text.getSize();
      _textBack.beginFill(0,  0.75);
      _textBack.drawRect(bounds.x, 0, size.width, size.height + 2);
      _textBack.endFill();
    }


// turn passed
  public function turn()
    {
      if (_textTimer <= 0)
        return;

      _textTimer--;
      if (_textTimer == 0)
        {
          _text.remove();
          _textBack.remove();
          _text = null;
          _textBack = null;
        }
    }


// set body image index
  public function setImage(col: Int, ?row: Int)
    {
      _spriteBody.remove();
      _spriteBody = new Bitmap(
        game.scene.entityAtlas[col][(row == null ? atlasRow : row)],
        _container);
    }


// set mask image index
  public function setMask(col: Int, ?row: Int)
    {
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

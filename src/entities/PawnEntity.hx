// pawn (AI, player) engine entity

package entities;

import h2d.Bitmap;
import h2d.Graphics;
import h2d.Text;
import h2d.Tile;

import game.Game;

class PawnEntity extends Entity
{
  var _text: Text;
  var _back: Graphics;
  var _body: Bitmap; // body sprite
  var _mask: Bitmap; // mask sprite map (invaded state)
  public var tile(default, set): Tile;

  var _textTimer: Int; // turns left to display this text


  public function new(g: Game, xx: Int, yy: Int, t: Tile)
    {
      super(g, Const.LAYER_AI);
      _body = null;
      tile = t;
      type = 'pawn';

      _mask = null;
      _text = null;
      _back = null;
      _textTimer = 0;
      setPosition(xx, yy);
    }


// set text
  public function setText(s: String, timer: Int)
    {
      if (_text == null)
        {
          _back = new Graphics(_container);
          _text = new Text(hxd.res.DefaultFont.get(), _container);
        }
      else _back.clear();
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
      _back.beginFill(0,  0.75);
      _back.drawRect(bounds.x, 0, size.width, size.height + 2);
      _back.endFill();
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
          _back.remove();
          _text = null;
          _back = null;
        }
    }


// set new image
  function set_tile(t: Tile)
    {
      tile = t;
      if (_body != null)
        _body.remove();
      _body = new Bitmap(tile, _container);
      return tile;
    }


// set mask image index
  public function setMask(t: Tile)
    {
      // no mask, remove image
      if (t == null)
        {
          if (_mask == null)
            return;

          _mask.remove();
          _mask = null;
          return;
        }

      // skip same image
      if (_mask != null && _mask.tile == t)
        return;

      if (_mask != null)
        _mask.remove();
      _mask = new Bitmap(t);
      _container.addChildAt(_mask, 0);
    }
}

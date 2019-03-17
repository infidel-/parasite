// pawn (AI, player) engine entity

package entities;

import h2d.Bitmap;
import h2d.Graphics;
import h2d.Text;

import game.Game;

class PawnEntity extends Entity
{

  var _text: Text;
  var _back: Graphics;
  var _body: Bitmap; // body sprite
  var _mask: Bitmap; // mask sprite map (invaded state)
  public var atlasRow: Int; // tile atlas row

  var _textTimer: Int; // turns left to display this text


  public function new(g: Game, xx: Int, yy: Int, r: Int)
    {
      super(g, Const.LAYER_AI);
      type = 'pawn';
      atlasRow = r;

      _body = new Bitmap(
        game.scene.entityAtlas[Const.FRAME_DEFAULT][atlasRow], _container);
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


// set body image index
  public function setImage(col: Int, ?row: Int)
    {
      _body.remove();
      _body = new Bitmap(
        game.scene.entityAtlas[col][(row == null ? atlasRow : row)],
        _container);
    }


// set mask image index
  public function setMask(col: Int, ?row: Int)
    {
      // no mask, remove image
      if (col == 0)
        {
          if (_mask == null)
            return;

          _mask.remove();
          _mask = null;
          return;
        }

      // skip same image
      var tile = game.scene.entityAtlas[col]
        [(row == null ? atlasRow : row)];
      if (_mask != null && _mask.tile == tile)
        return;

      if (_mask != null)
        _mask.remove();
      _mask = new Bitmap(tile, _container);
    }
}

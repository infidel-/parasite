// pawn (AI, player) engine entity

package entities;

import jsui.UI;
import js.html.CanvasRenderingContext2D;
import game.Game;

class PawnEntity extends Entity
{
  var _textTimer: Int; // turns left to display this text

  // new draw
  // mask sprite map (invaded state)
  var maskx: Int;
  var text: String;

  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g, Const.LAYER_AI);
      type = 'pawn';
      maskx = -1;

      _textTimer = 0;
      setPosition(xx, yy);
    }


// set text
  public function setText(s: String, timer: Int)
    {
      text = s;
      _textTimer = timer;
    }


// turn passed
  public function turn()
    {
      if (_textTimer <= 0)
        return;

      _textTimer--;
      if (_textTimer == 0)
        text = null;
    }

// draw pawn entity
  public override function draw(ctx: CanvasRenderingContext2D)
    {
      var x = (mx * Const.TILE_SIZE_CLEAN - game.scene.cameraX) * game.config.mapScale;
      var y = (my * Const.TILE_SIZE_CLEAN - game.scene.cameraY) * game.config.mapScale;

      // draw mask image first
      ctx.drawImage(game.scene.images.entities,
        maskx * Const.TILE_SIZE_CLEAN, 
        Const.ROW_PARASITE * Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN,
        x,
        y,
        Const.TILE_SIZE_CLEAN,
        Const.TILE_SIZE_CLEAN);

      // draw entity image
      super.draw(ctx);

      // draw text
      if (text != null)
        {
          // text bg
          var m = ctx.measureText(text);
          var h = 14;
          var tx = x + Const.TILE_SIZE / 2;
          var ty = y + 4;
          var bgX = tx - m.width/2 - 5;
          var bgY = y - h/2 - 4;
          ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
          ctx.fillRect(bgX, bgY, m.width + 10, h + 3);

          // text
          ctx.font = "14px " + UI.getVar('--text-font');
          ctx.fillStyle = 'white';
          ctx.fillText(text, tx, ty);
        }
    }

// set mask image
// NOTE: -1 means no mask
  public inline function setMask(mx: Int)
    {
      maskx = mx;
    }
}

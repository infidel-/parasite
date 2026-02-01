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
  var textFont: String;
  var textFontFormatted: String;
  var textFontFamily: String;

  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g, Const.LAYER_AI);
      type = 'pawn';
      maskx = -1;

      _textTimer = 0;
      textFont = null;
      textFontFormatted = null;
      textFontFamily = null;
      setPosition(xx, yy);
    }


// set text
  public function setText(s: String, timer: Int, ?lang: String)
    {
      // load font if needed
      if (lang != null &&
          lang != '')
        {
          game.lang.ensureFontLoaded(lang);
          s = game.lang.renderText(s, lang);
          textFont = game.lang.getFont(lang);
        }
      else textFont = null;

      // cache font family
      if (textFont != null &&
          textFont != '')
        textFontFormatted = formatFontFamily(textFont);
      else textFontFormatted = null;
      var defaultFontFormatted = formatFontFamily(UI.getVar('--text-font'));
      if (textFontFormatted != null &&
          textFontFormatted != '')
        textFontFamily = textFontFormatted + ', ' + defaultFontFormatted;
      else textFontFamily = defaultFontFormatted;
    
      // set text and timer
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
        {
          text = null;
          textFont = null;
          textFontFormatted = null;
          textFontFamily = null;
        }
    }

// draw pawn entity
  public override function draw(ctx: CanvasRenderingContext2D)
    {
      // draw mask image first
      drawImage(ctx, game.scene.images.entities,
        maskx, Const.ROW_PARASITE);

      // draw entity image
      super.draw(ctx);

      // draw text
      if (text != null)
        {
          var x = (mx - game.scene.cameraTileX1) * Const.TILE_SIZE;
          var y = (my - game.scene.cameraTileY1) * Const.TILE_SIZE;
          // text bg
          ctx.font = Std.int(14 * game.config.mapScale) + "px " + textFontFamily;
          var m = ctx.measureText(text);
          var h = Std.int(14 * game.config.mapScale);
          var tx = x + Const.TILE_SIZE / 2;
          var ty = y + 4;
          var bgX = tx - m.width / 2 - 5;
          var bgY = y - h / 2 - 4;
          ctx.fillStyle = 'rgba(0, 0, 0, 0.5)';
          ctx.fillRect(bgX, bgY, m.width + 10, h + 3);

          // text
          ctx.fillStyle = 'white';
          ctx.fillText(text, tx, ty);
        }
    }

// formats a font family for canvas usage
  function formatFontFamily(family: String): String
    {
      if (family == null ||
          family == '')
        return 'sans-serif';
      var trimmed = StringTools.trim(family);
      if (trimmed.indexOf(' ') >= 0)
        return '"' + trimmed + '"';
      return trimmed;
    }

// set mask image
// NOTE: -1 means no mask
  public inline function setMask(mx: Int)
    {
      maskx = mx;
    }
}

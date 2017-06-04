// game over window

package ui;

import openfl.Assets;
import com.haxepunk.HXP;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

import game.Game;

class Finish extends Actions
{
  public function new(g: Game)
    {
      super(g);

      var font = Assets.getFont(Const.FONT);
      var textFormat = new TextFormat(font.fontName,
        game.config.fontSizeLarge, 0xFFFFFF);
      textFormat.align = TextFormatAlign.CENTER;
      textInput.defaultTextFormat = textFormat;

      var w = Std.int(HXP.width / 2);
      var h = Std.int(HXP.height / 2);
      window.width = w;
      window.height = h;
      window.x = Std.int(HXP.halfWidth - w / 2);
      window.y = Std.int(HXP.halfHeight - h / 2);
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('\nGame Over\n===\n\n');
      buf.add(game.finishText);
      buf.add("\n\nClose window" +
        "\nThen you can restart the game by pressing ENTER\n");

      return buf.toString();
    }
}


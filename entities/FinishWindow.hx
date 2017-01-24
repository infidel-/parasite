// game over window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

import game.Game;

class FinishWindow extends TextWindow
{
  public function new(g: Game)
    {
      super(g);

      var font = Assets.getFont(Const.FONT);
      textFormat = new TextFormat(font.fontName,
        game.config.fontSizeLarge, 0xFFFFFF);
      textFormat.align = TextFormatAlign.CENTER;
      _textField.defaultTextFormat = textFormat;

      var w = Std.int(HXP.width / 2);
      var h = Std.int(HXP.height / 2);
      setSize(w, h);
      setPosition(Std.int(HXP.width / 2 - w / 2),
        Std.int(HXP.height / 2 - h / 2));
    }


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('\nGame Over\n===\n\n');
      buf.add(game.finishText);
      buf.add("\n\nPress ESC to close window" +
        "\nThen you can restart the game by pressing ENTER\n");

      return buf.toString();
    }
}


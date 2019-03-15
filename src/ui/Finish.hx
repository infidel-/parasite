// game over window

package ui;

/*
import openfl.Assets;
import com.haxepunk.HXP;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
*/

import game.Game;

class Finish extends Text
{
  public function new(g: Game)
    {
      super(g,
        Std.int(g.scene.win.width / 2),
        Std.int(g.scene.win.height / 2));
      text.textAlign = Center;
      window.x = Std.int((game.scene.win.width - width) / 2);
      window.y = Std.int((game.scene.win.height - height) / 2);

/*
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
*/
    }


// set parameters
  public override function setParams(o: Dynamic)
    {
      var buf = new StringBuf();
      buf.add('<br/>Game Over<br/>===<br/><br/>');
      buf.add(o);
      buf.add("<br/><br/>Close the window" +
        "<br/>Then you can restart the game by pressing ENTER<br/>");

      text.text = buf.toString();
    }
}


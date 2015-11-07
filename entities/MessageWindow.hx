// important message GUI window

package entities;

import game.Game;
import com.haxepunk.HXP;

class MessageWindow extends TextWindow
{
  public function new (g: Game)
    {
      super(g);
      exitByEnter = true;
      var ww = Std.int(HXP.width / 2);
      var hh = Std.int(HXP.height / 4);
      setSize(ww, hh);
      setPosition(Std.int(HXP.halfWidth - ww / 2), Std.int(HXP.halfHeight - hh / 2));
      textFormat.size = 24;
      _textField.defaultTextFormat = textFormat;
      _textField.border = true;
      _textField.borderColor = 0x004040;
    }


  override function getText(): String
    {
      return '<br>' + game.importantMessage + '\n\n\n' +
        'Press ENTER to continue';
    }
}


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

      var font = Assets.getFont("font/04B_03__.ttf");
      textFormat = new TextFormat(font.fontName, 24, 0xFFFFFF);
      textFormat.align = TextFormatAlign.CENTER;
      _textField.defaultTextFormat = textFormat;

      var w = Std.int(HXP.width / 2);
      var h = Std.int(HXP.height / 2);
      setSize(w, h);
      setPosition(Std.int(HXP.width / 2 - w / 2),
        Std.int(HXP.height / 2 - h / 2));
    }


// get action list
/*
  override function getActions()
    {
      var list = new List<_PlayerAction>();
      var actions = null;
      if (game.location == LOCATION_AREA)
        actions = game.debugArea.actions;
      else if (game.location == LOCATION_REGION)
        actions = game.debugRegion.actions;

      var n = 0;
      for (a in actions)
        list.add({
          id: 'debug' + (n++),
          type: ACTION_DEBUG,
          name: a.name,
          energy: 0,
          });

      return list;
    }


// action handler
  override function onAction(action: _PlayerAction)
    {
      var index = Std.parseInt(action.id.substr(5));

      if (game.location == LOCATION_AREA)
        game.debugArea.action(index);
      else if (game.location == LOCATION_REGION)
        game.debugRegion.action(index);
    }
*/


// update window text
  override function getText()
    {
      var buf = new StringBuf();
      buf.add('\n\nGame Over\n===\n\n');
      buf.add(game.finishText);

      return buf.toString();
    }
}


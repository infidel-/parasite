// organs GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class OrgansWindow
{
  var game: Game; // game state

  var _textField: TextField; // text field
  var _back: Sprite; // window background
  var _actionNames: List<String>; // list of currently available actions (names)
  var _actionIDs: List<String>; // list of currently available actions (string IDs)

  public function new(g: Game)
    {
      game = g;

      _actionNames = new List<String>();
      _actionIDs = new List<String>();

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
      _textField.autoSize = TextFieldAutoSize.LEFT;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _back = new Sprite();
      _back.addChild(_textField);
      _back.x = 20;
      _back.y = 20;
      HXP.stage.addChild(_back);
    }


// call action by id
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var actionName = null;
      for (a in _actionIDs)
        if (i++ == index)
          {
            actionName = a;
            break;
          }
      if (actionName == null)
        return;

      // do action
      game.player.host.organs.action(actionName);
      update(); // update display
      game.scene.hud.update(); // update HUD
    }


// update and show window
  public function show()
    {
      update();
      _back.visible = true;
    }


// hide this window
  public function hide()
    {
      _back.visible = false;
    }


// update window text
  function update()
    {
      var buf = new StringBuf();
      buf.add('Body features\n===\n\n');

      // draw a list of organs
      var n = 0;
      for (organ in game.player.host.organs)
        {
          buf.add(organ.info.name + ': ' + organ.info.note + '\n');
          n++;
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      // form a list of actions
      _actionNames.clear();
      _actionIDs.clear();
      for (imp in game.player.evolutionManager.getList())
        {
          // improvement not available yet or no organs
          if (imp.level == 0 || imp.info.organ == null)
            continue;

          var organ = imp.info.organ;

          _actionIDs.add('set.' + imp.id);
          _actionNames.add(organ.name + ' (' + organ.gp + 'gp)' +
            ' [' + organ.note + ']');
        }

      buf.add('\nGrowing body feature: ');
      buf.add(game.player.host.organs.getGrowInfo());

      // add list of actions
      buf.add('\n\nSelect body feature to grow:\n\n');
      var n = 1;
      for (a in _actionNames)
        buf.add((n++) + ': ' + a + '\n');

      _textField.htmlText = buf.toString();
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}

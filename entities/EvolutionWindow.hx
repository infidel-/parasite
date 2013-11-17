// evolution GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class EvolutionWindow
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
//      _back.width = 400;
//      _back.height = 400;
//      _back.width = HXP.windowWidth - 40;
//      _back.height = HXP.windowHeight - 40;
      HXP.stage.addChild(_back);

//      _back.visible = false;
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

      game.player.evolutionManager.action(actionName);
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
      buf.add('Controlled Evolution\n===\n\n');

      // form a list of improvs and actions
      buf.add('Improvements\n===\n');
      _actionNames.clear();
      _actionIDs.clear();
      for (imp in game.player.evolutionManager.getList())
        {
          var info = EvolutionConst.getInfo(imp.id);
          buf.add(info.name);
          buf.add(' ');
          buf.add(imp.level);
          buf.add(': ');
          buf.add(info.note);

          _actionIDs.add('set.' + imp.id);
          _actionNames.add(info.name);
        }

      // add paths
      for (p in EvolutionConst.paths)
        {
          _actionIDs.add('setPath.' + p.id);
          _actionNames.add('Path of ' + p.name);
        }

      // add list of actions
      buf.add('\n\nSelect evolution direction:\n\n');
      var n = 1;
      for (a in _actionNames)
        buf.add((n++) + ': ' + a + '\n');
      
      _textField.text = buf.toString();
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .75);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}

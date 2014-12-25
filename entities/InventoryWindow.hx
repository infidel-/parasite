// inventory GUI window

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class InventoryWindow
{
  var game: Game; // game state

  var _textField: TextField; // text field
  var _back: Sprite; // window background
  var _actions: List<_PlayerAction>; // list of currently available actions

  public function new(g: Game)
    {
      game = g;

      _actions = new List<_PlayerAction>();

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
//      _textField.autoSize = TextFieldAutoSize.LEFT;
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _back = new Sprite();
      _back.addChild(_textField);
//      _back.x = 20;
//      _back.y = 20;
      _back.x = 0;
      _back.y = 0;
      _back.width = HXP.width;
      _back.height = HXP.height;
      HXP.stage.addChild(_back);
    }


// call action by id
  public function action(index: Int)
    {
      // find action name by index
      var i = 1;
      var action = null;
      for (a in _actions)
        if (i++ == index)
          {
            action = a;
            break;
          }
      if (action == null)
        return;

      game.player.host.inventory.action(action); // do action

      // player host could die after that action
      if (game.player.host != null)
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
      buf.add('Inventory\n===\n\n');

      // draw a list of items
      var n = 0;
      for (item in game.player.host.inventory)
        {
          n++;
          var knowsItem = game.player.knowsItem(item.id);  
          var name = (knowsItem ? item.name : item.info.unknown);
          buf.add(name + '\n');
        }

      if (n == 0)
        buf.add('  --- empty ---\n');

      // inventory actions 
      var n = 1;
      if (game.player.state == PLR_STATE_HOST && game.player.host.isHuman)
        {
          _actions = game.player.host.inventory.getActions();

          // check if list contains at least one possible action
          var ok = false;
          for (action in _actions)
            if (game.player.host.energy >= action.energy)
              {
                ok = true;
                break;
              }
              
          if (ok)
            {
              buf.add('\n\nSelect action:\n\n');
              for (action in _actions)
                if (game.player.host.energy >= action.energy)
                  buf.add((n++) + ': ' + action.name +
                    ' (' + action.energy + ' energy)\n');
            }
        }

      _textField.htmlText = buf.toString();
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }
}

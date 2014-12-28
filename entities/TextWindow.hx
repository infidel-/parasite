// generic scrollable text GUI window with actions

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

class TextWindow
{
  var game: Game; // game state
  var _actions: List<_PlayerAction>; // list of currently available actions

  var _textField: TextField; // text field
  var _back: Sprite; // window background
  var actionName: String; // default action name

  public function new(g: Game)
    {
      game = g;
      actionName = 'action';

      _actions = new List<_PlayerAction>();

      // actions list
      var font = Assets.getFont("font/04B_03__.ttf");
      _textField = new TextField();
      _textField.wordWrap = true;
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      var fmt = new TextFormat(font.fontName, 16, 0xFFFFFF);
      fmt.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = fmt;
      _back = new Sprite();
      _back.addChild(_textField);
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
      var act = null;
      for (a in _actions)
        if (i++ == index)
          {
            act = a;
            break;
          }
      if (act == null)
        return;

      var state = game.scene.getState();

      onAction(act); // call action handler

      // gui is still in the same state post-action, update window
      if (state == game.scene.getState())
        update();

      // close window if player

      // player host could die after that action
//      if (game.player.host != null)

      game.scene.hud.update(); // update HUD
    }


// scroll window up/down
  public function scroll(n: Int)
    {
      _textField.scrollV += n;
    }


// scroll window to beginning
  public function scrollToBegin()
    {
      _textField.scrollV = 0;
    }


// scroll window to end 
  public function scrollToEnd()
    {
      _textField.scrollV = _textField.maxScrollV;
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
      var text = getText();

      // print actions
      var buf = new StringBuf();
      _actions = getActions();

      // check if list contains at least one possible action
      var ok = false;
      for (action in _actions)
        if (action.energy == 0 || game.player.host.energy >= action.energy)
          {
            ok = true;
            break;
          }
          
      if (ok)
        {
          var n = 1;
          buf.add('\n\nSelect ' + actionName + ':\n\n');
          for (action in _actions)
            if (action.energy == 0 || game.player.host.energy >= action.energy)
              {
                buf.add((n++) + ': ' + action.name);
                if (action.energy > 0)
                  buf.add(' (' + action.energy + ' energy)');
                buf.add('\n');
              }
        }

      _textField.htmlText = text + buf.toString();
      _textField.width = HXP.width;
      _textField.height = HXP.height;
      _back.graphics.clear();
      _back.graphics.beginFill(0x202020, .95);
      _back.graphics.drawRect(0, 0, _textField.width, _textField.height);
    }


// function that produces window text
  dynamic function getText(): String
    {
      return '';
    }


// function that produces a list of actions
  static var _emptyList: List<_PlayerAction> = new List();
  dynamic function getActions(): List<_PlayerAction>
    {
      return _emptyList; 
    }


// action handler
  dynamic function onAction(action: _PlayerAction)
    {}
}

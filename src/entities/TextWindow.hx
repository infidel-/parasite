// generic scrollable text GUI window with actions

package entities;

import openfl.Assets;
import com.haxepunk.HXP;
import flash.display.Sprite;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import flash.text.TextFieldAutoSize;

import game.Game;

class TextWindow
{
  var game: Game; // game state
  var _actions: List<_PlayerAction>; // list of currently available actions

  var _textField: TextField; // text field
  var _back: Sprite; // window background
  var actionName: String; // default action name

  // options
  public var exitByEnter: Bool; // allows exiting by pressing enter
  var width: Int; // window size
  var height: Int;
  var x: Int; // window position
  var y: Int;
  var textFormat: TextFormat;

  public function new(g: Game)
    {
      game = g;
      actionName = 'action';
      exitByEnter = false;
      width = 0;
      height = 0;
      x = 0;
      y = 0;

      _actions = new List<_PlayerAction>();

      // actions list
      var font = Assets.getFont(Const.FONT);
      _textField = new TextField();
      _textField.visible = false;
      _textField.wordWrap = true;
      _textField.width = HXP.width;
      _textField.height = HXP.height;
//      _textField.x = 5;
//      _textField.y = 5;
      textFormat = new TextFormat(font.fontName, game.config.fontSize, 0xFFFFFF);
      textFormat.align = TextFormatAlign.LEFT;
      _textField.defaultTextFormat = textFormat;
      _back = new Sprite();
      _back.addChild(_textField);
      _back.x = 0;
      _back.y = 0;
      _back.width = HXP.width;
      _back.height = HXP.height;
      HXP.stage.addChild(_back);
    }


// set window size
  public inline function setSize(w: Int, h: Int)
    {
      width = w;
      height = h;
    }


// set window position
  public inline function setPosition(xv: Int, yv: Int)
    {
      x = xv;
      y = yv;
      _back.x = x;
      _back.y = y;
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
      _textField.visible = true;
    }


// hide this window
  public function hide()
    {
      _back.visible = false;
      _textField.visible = false;
    }

// update window text
  function update()
    {
      var text = getText();

      // print actions
      var buf = new StringBuf();
      _actions = getActions();

      // remove actions that there is no energy for
      for (a in _actions)
        if (a.energy > 0 && game.player.host.energy < a.energy)
          _actions.remove(a);

      if (_actions.length > 0)
        {
          var n = 1;
          buf.add('\n\nSelect ' + actionName + ' (press 0-9):\n\n');
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
      _textField.width = (width > 0 ? width : HXP.width);
      _textField.height = (height > 0 ? height : HXP.height);
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

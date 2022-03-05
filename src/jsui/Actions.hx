// generic action GUI window (legacy)

package jsui;

import js.Browser;
import js.html.DivElement;

import game.Game;

class Actions extends UIWindow
{
  var text: DivElement;
  var _actions: List<_PlayerAction>; // list of currently available actions
  var actionName: String; // default action name

  public function new (g: Game, id: String)
    {
      super(g, id);
      actionName = 'action';
      window.style.borderImage = "url('./img/window-temp.png') 130 fill / 1 / 0 stretch";

      text = Browser.document.createDivElement();
      text.id = id + '-text';
      text.className = 'scroller';
      window.appendChild(text);
    }


// update text
  override function update()
    {
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
          buf.add('<br/><br/>Select ' + actionName + ' (press 0-9):<br/><br/>');
          for (action in _actions)
            if (action.energy == 0 || game.player.host.energy >= action.energy)
              {
                buf.add((n++) + ': ' + action.name);
                if (action.energy > 0)
                  buf.add(' (' + action.energy + ' energy)');
                buf.add('<br/>');
              }
        }

      setParams(getText() + buf.toString());
    }

  public override function setParams(obj: Dynamic)
    {
      text.innerHTML = obj;
      text.scrollTop = 10000;
    }

// call action by id
  public override function action(index: Int)
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

      var state = game.ui.state;

      onAction(act); // call action handler

      // gui is still in the same state post-action, update window
      if (state == game.ui.state)
        update();

      game.ui.hud.update(); // update HUD
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


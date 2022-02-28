// new js ui group
package jsui;

import js.Browser;
import js.html.KeyboardEvent;
import js.html.CanvasElement;

import game.*;

class UI
{
  var game: Game;
  var canvas: CanvasElement;
  public var hud: HUD;
  public var state(get, set): _UIState;
  var _state: _UIState; // current HUD state (default, evolution, etc)
  var inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)
  var isFullScreen: Bool; // game is in fullscreen mode?

  public function new(g: Game)
    {
      game = g;
      isFullScreen = false;
      _state = UISTATE_DEFAULT;
      hud = new HUD(this, game);
      canvas = cast Browser.document.getElementById('webgl');
      canvas.onkeydown = onKey;
    }

// refocus canvas
  public function focus()
    {
      canvas.focus();
    }

// grab key presses
  function onKey(e: KeyboardEvent)
    {
//      trace(e.keyCode + ' ' + e.altKey + ' ' + e.ctrlKey + ' ' + e.code);
      // TODO check windows first
      if (false)
        {

        }
      // hud/movement/actions
      else
        {
          // toggle hud
          if (e.code == 'Space')
            {
              hud.toggle();
              return;
            }

          // enter restarts the game when it is finished
          if (game.isFinished &&
              e.code == 'Enter' &&
              _state == UISTATE_DEFAULT)
            {
              game.restart();
              return;
            }

          // open console
          if (e.code == 'Semicolon' && !hud.consoleVisible())
            {
              hud.showConsole();
              return;
            }
          // close console
          if (e.code == 'Escape' && hud.consoleVisible())
            {
              hud.hideConsole();
              return;
            }

          // try to handle keyboard actions
          var ret = handleActions(e.code);
/*
          if (!ret)
            ret = handleWindows(e.code);*/
          if (!ret)
            ret = handleMovement(e.code);
        }
    }

// handle player actions
  function handleActions(key: String): Bool
    {
      // game finished
      if (game.isFinished)
        return false;

      // actions from action menu
      var ret = false;
      for (i in 1...11)
        if (key == 'Digit' + i)
          {
            var n = i;

            // s + number = 10 + action
            if (inputState > 0)
              n += 10;

            if (_state == UISTATE_DEFAULT)
              hud.action(n);
/*
            else if (components[_state] != null)
              components[_state].action(n);
*/
            inputState = 0;
            ret = true;
            break;
          }
/*
      // yes/no
      if (_state == UISTATE_YESNO)
        {
          var n = 0;
          if (key == Key.Y)
            n = 1;
          else if (key == Key.N)
            n = 2;
          if (n > 0)
            {
              components[_state].action(n);
              return true;
            }
        }
*/

      // actions by key
      ret = hud.keyAction(key);
      if (_state == UISTATE_DEFAULT)
        {
          // skip until end of turn
          if (key == 'Numpad5' || key == 'KeyZ')
            {
              game.turn();
              game.updateHUD();
              ret = true;
            }

          // toggle fullscreen
          else if (key == 'KeyF')
            {
              isFullScreen = !isFullScreen;
              var doc = js.Browser.document;
              if (doc.fullscreenEnabled)
                {
                  var e: js.html.CanvasElement =
                    cast doc.getElementById("webgl");
                  if (isFullScreen)
                    untyped e.requestFullscreen();
                  else doc.exitFullscreen();
                }
              ret = true;
            }
        }

      // next 10 actions
      if (key == 'KeyS')
        {
          inputState = 1;
          ret = true;
        }

      return ret;
    }

// handle player movement
  function handleMovement(key: String): Bool
    {
      // game finished or window open
      if (game.isFinished ||
          _state != UISTATE_DEFAULT)
        return false;

      var dx = 0;
      var dy = 0;

      if (key == 'ArrowUp' ||
          key == 'Numpad8')
        dy = -1;

      if (key == 'ArrowDown' ||
          key == 'Numpad2')
        dy = 1;

      if (key == 'ArrowLeft' ||
          key == 'Numpad4')
        dx = -1;

      if (key == 'ArrowLeft' ||
          key == 'Numpad6')
        dx = 1;

      if (key == 'Numpad7')
        {
          dx = -1;
          dy = -1;
        }

      if (key == 'Numpad9')
        {
          dx = 1;
          dy = -1;
        }

      if (key == 'Numpad1')
        {
          dx = -1;
          dy = 1;
        }

      if (key == 'Numpad3')
        {
          dx = 1;
          dy = 1;
        }

      if (dx == 0 && dy == 0)
        return false;

      // area mode
      if (game.location == LOCATION_AREA)
        game.playerArea.moveAction(dx, dy);

      // area mode
      else if (game.location == LOCATION_REGION)
        game.playerRegion.moveAction(dx, dy);

      return true;
    }

// get CSS variable
  public static inline function getVar(s: String): String
    {
      return Browser.window.getComputedStyle(
        Browser.document.documentElement).getPropertyValue(s);
    }


// get CSS variable as int
  public static inline function getVarInt(s: String): Int
    {
      return Std.parseInt(getVar(s));
    }

// get GUI state
  function get_state(): _UIState
    {
      return _state;
    }

// set new GUI state, open and close windows if needed
  public function set_state(vstate: _UIState)
    {
      trace(vstate);
//      Const.traceStack();
/*
      if (_state != UISTATE_DEFAULT)
        {
          if (components[_state] != null)
            components[_state].hide();
        }

      _state = vstate;
      if (_state != UISTATE_DEFAULT && components[_state] != null)
        {
          if (components[_state] != null)
            components[_state].show();

          if (_state != UISTATE_LOG)
            components[_state].scrollToBegin();
        }

      // clear old path on opening message window
      if (_state == UISTATE_MESSAGE)
        clearPath();*/

      return _state;
    }
}

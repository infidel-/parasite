// new js ui group
package jsui;

import js.Browser;
import js.html.KeyboardEvent;
import js.html.CanvasElement;

import game.Game;

class UI
{
  var game: Game;
  var canvas: CanvasElement;
  public var hud: HUD;
  public var state(get, set): _UIState;
  var _state: _UIState; // current HUD state (default, evolution, etc)
  var inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)
  var isFullScreen: Bool; // game is in fullscreen mode?
  var components: Map<_UIState, UIWindow>; // GUI windows
  var uiLocked: Array<_UIState>; // list of gui states that lock the player
  var uiNoClose: Array<_UIState>; // list of gui states that disable window closing
  var uiQueue: List<_UIEvent>; // gui event queue
  var uiQueuePaused: Bool; // if true, the queue is paused
  var uiQueuePrev: _UIEvent; // previous UI event

  public function new(g: Game)
    {
      game = g;
      isFullScreen = false;
      _state = UISTATE_DEFAULT;
      uiQueue = new List();
      uiQueuePaused = false;
      uiQueuePrev = null;
      hud = new HUD(this, game);
      canvas = cast Browser.document.getElementById('webgl');
      canvas.onkeydown = onKey;

      uiLocked = [ UISTATE_DIFFICULTY, UISTATE_YESNO, UISTATE_DOCUMENT ];
      uiNoClose = [ UISTATE_DEFAULT, UISTATE_YESNO, UISTATE_DIFFICULTY ];
      components = [
        UISTATE_MESSAGE => new Message(game),
        UISTATE_DOCUMENT => new Document(game),
        UISTATE_YESNO => new YesNo(game),
        UISTATE_DIFFICULTY => new Difficulty(game),

        UISTATE_GOALS => new Goals(game),
        UISTATE_INVENTORY => new Inventory(game),
        UISTATE_SKILLS => new Skills(game),
        UISTATE_LOG => new Log(game),
        UISTATE_TIMELINE => new Timeline(game),
        UISTATE_EVOLUTION => new Evolution(game),
        UISTATE_ORGANS => new Organs(game),
        UISTATE_FINISH => new Finish(game),
/*
        UISTATE_DEBUG => new Debug(game),
        UISTATE_OPTIONS => new Options(game),*/
      ];
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
      // toggle hud
      if (e.code == 'Space' && _state == UISTATE_DEFAULT)
        {
          hud.toggle();
          return;
        }

      // enter restarts the game when it is finished
      if (game.isFinished &&
          (e.code == 'Enter' ||
          e.code == 'NumpadEnter') && 
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
      if (!ret)
        ret = handleWindows(e.code, e.altKey, e.ctrlKey);
      if (!ret)
        ret = handleMovement(e.code);
    }

// handle opening and closing windows
  function handleWindows(key: String, altKey: Bool, ctrlKey: Bool): Bool
    {
/*
      // scrolling text
      if (_state != UISTATE_DEFAULT)
        {
          // get amount of lines
          var lines = 0;
          if (key == Key.PGUP ||
            (key == Key.K && shiftPressed))
            lines = -20;
          else if (key == Key.PGDOWN ||
            (key == Key.J && shiftPressed))
            lines = 20;
          else if (key == Key.UP || key == Key.K || key == Key.NUMPAD_8)
            lines = -1;
          else if (key == Key.DOWN || key == Key.J || key == Key.NUMPAD_2)
            lines = 1;

          var win: UIWindow = cast components[_state];

          if (lines != 0)
            {
              win.scroll(lines);
              return false;
            }

          else if (key == Key.END ||
            (key == Key.G && shiftPressed))
            {
              win.scrollToEnd();
              return false;
            }

          else if (key == Key.HOME || key == Key.G)
            {
              win.scrollToBegin();
              return false;
            }
        }*/

      // window open
      if (!Lambda.has(uiNoClose, _state))
        {
          // close windows
          if (key == 'Enter' || key == 'NumpadEnter' || key == 'Escape') 
            closeWindow();
        }

      // ui in locked state, do not allow changing windows
      if (Lambda.has(uiLocked, _state))
        return true;

      // no windows open
      var goalsPressed = (key == 'Digit1' && altKey) || key == 'F1';
      var inventoryPressed =
        (key == 'Digit2' && altKey) || key == 'F2';
      var skillsPressed =
        (key == 'Digit3' && altKey) || key == 'F3';
      var logPressed =
        (key == 'Digit4' && altKey) || key == 'F4';
      var timelinePressed =
        (key == 'Digit5' && altKey) || key == 'F5';
      var evolutionPressed =
        (key == 'Digit6' && altKey) || key == 'F6';
      var organsPressed =
        (key == 'Digit7' && altKey) || key == 'F7';
/*
      var optionsPressed =
        (key == 'Digit8' && altKey) || key == 'F8';
      var debugPressed =
        (key == 'Digit9' && altKey) || key == 'F9';
*/
      var exitPressed =
        (key == 'Digit0' && altKey) || key == 'F10';

      // open goals window
      if (goalsPressed)
        state = UISTATE_GOALS;
      // open inventory window (if items are learned)
      else if (inventoryPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.host.isHuman &&
          game.player.vars.inventoryEnabled)
        state = UISTATE_INVENTORY;
      // open skills window (if skills are learned)
      else if (skillsPressed &&
          game.player.vars.skillsEnabled)
        state = UISTATE_SKILLS;
      // open message log window
      else if (logPressed)
        state = UISTATE_LOG;
      // open timeline window
      else if (timelinePressed &&
          game.player.vars.timelineEnabled)
        state = UISTATE_TIMELINE;
      // open evolution window (if enabled)
      else if (evolutionPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.evolutionManager.state > 0)
        state = UISTATE_EVOLUTION;
      // open organs window
      else if (organsPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.vars.organsEnabled)
        state = UISTATE_ORGANS;

      else if (exitPressed)
        {
          // show exit yes/no dialog
          game.ui.event({
            state: UISTATE_YESNO,
            obj: {
              text: 'Do you want to exit the game?',
              func: function(yes: Bool)
                {
                  if (yes)
                    electron.renderer.IpcRenderer.invoke('quit');
                }
            }
          });
        }
/*
      // open options window
      else if (optionsPressed)
        state = UISTATE_OPTIONS;

#if mydebug
      // open debug window
      else if (debugPressed && !game.isFinished)
        state = UISTATE_DEBUG;
#end
*/
      return false;
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
            else if (components[_state] != null)
              components[_state].action(n);
            inputState = 0;
            ret = true;
            break;
          }

      // yes/no
      if (_state == UISTATE_YESNO)
        {
          var n = 0;
          if (key == 'KeyY')
            n = 1;
          else if (key == 'KeyN')
            n = 2;
          if (n > 0)
            {
              components[_state].action(n);
              return true;
            }
        }

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
        game.scene.clearPath();

      if (_state == UISTATE_DEFAULT)
        {
          canvas.focus();
          hud.show();
        }
      else hud.hide();

      return _state;
    }

// add event to the GUI queue
  public function event(ev: _UIEvent)
    {
      uiQueue.add(ev);

      // no windows open, work on event immediately
      if (state == UISTATE_DEFAULT)
        closeWindow();
    }

// clear GUI queue
  public inline function clearEvents()
    {
      uiQueue.clear();
    }

// close the current window
  public function closeWindow()
    {
      // check if there are more UI events in the queue
      if (uiQueue.length > 0)
        {
          // get next event
          var ev = uiQueue.first();
          uiQueuePrev = ev;
          uiQueue.remove(ev);

          if (components[ev.state] != null)
            components[ev.state].setParams(ev.obj);
          else
            {
              trace('component is null for ' + ev.state);
              state = UISTATE_DEFAULT;
              return;
            }
          state = ev.state;
          return;
        }

      state = UISTATE_DEFAULT;
    }
}

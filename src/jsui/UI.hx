// new js ui group
package jsui;

import js.Browser;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.CanvasElement;
import js.html.Element;
#if electron
import js.node.Fs;
#end

import game.Game;

class UI
{
  var game: Game;
  public var canvas: CanvasElement;
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
      canvas.style.visibility = 'hidden';
      Browser.document.onkeydown = onKey;
      canvas.onmousemove = function (e: MouseEvent) {
        hud.onMouseMove(e);
      }
#if electron
      Browser.window.onerror = onError;
#end

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
        UISTATE_BODY => new Body(game),
        UISTATE_FINISH => new Finish(game),
        UISTATE_OPTIONS => new Options(game),
        UISTATE_MAINMENU => new MainMenu(game),
      ];
    }

#if electron
  public function onError(msg: Dynamic, url: String, line: Int, col: Int, err: Dynamic): Bool
    {
      var d = Date.now();
      var l = msg + ', ' + err.stack + ', line ' + line + ', col ' + col + '\n';
      trace(l);
      game.log('An exception has occured and was logged. Please send exceptions.txt file to me (starinfidel@gmail.com).', COLOR_ALERT);
      try {
        Fs.appendFileSync('exceptions.txt', l);
      }
      catch (e: Dynamic)
        {}
      return false;
    }
#end

// refocus canvas
  public function focus()
    {
      canvas.focus();
    }

// grab key presses
  function onKey(e: KeyboardEvent)
    {
      if (hud.consoleVisible())
        return;
//      trace(e.code + ' ' + e.altKey + ' ' + e.ctrlKey + ' ' + e.shiftKey + ' ' + e.key);
      // default state
      if (_state == UISTATE_DEFAULT)
        {
          // toggle hud
          if (e.code == 'Space')
            {
              hud.toggle();
              return;
            }

          // enter restarts the game when it is finished
          if (game.isFinished && e.key == 'Enter')
            {
              game.restart();
              return;
            }

          // open console
          if (e.key == ';' && !hud.consoleVisible())
            {
              hud.showConsole();
              return;
            }

          // close console or open main menu
          if (e.code == 'Escape')
            {
              if (hud.consoleVisible())
                {
                  hud.hideConsole();
                  return;
                }
              else
                {
                  state = UISTATE_MAINMENU;
                  return;
                }
            }
        }

      // try to handle keyboard actions
      var ret = handleActions(e.key, e.code, e.altKey, e.ctrlKey, e.shiftKey);
      if (!ret)
        ret = handleWindows(e.key, e.code, e.altKey, e.ctrlKey);
      if (!ret)
        ret = handleMovement(e.key, e.code);
      // update camera position
      if (ret)
        game.scene.updateCamera();
    }

// handle opening and closing windows
  function handleWindows(key: String, code: String, altKey: Bool, ctrlKey: Bool): Bool
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
            {
              if (_state == UISTATE_OPTIONS)
                state = UISTATE_MAINMENU;
              else if (_state == UISTATE_MAINMENU && !game.isStarted)
                return true;
              else closeWindow();
            }
        }

      // ui in locked state, do not allow changing windows
      if (Lambda.has(uiLocked, _state))
        return true;

      // no windows open
      var goalsPressed = (code == 'Digit1' && altKey) || code == 'F1';
      var bodyPressed = (code == 'Digit2' && altKey) || code == 'F2';
      var logPressed = (code == 'Digit3' && altKey) || code == 'F3';
      var timelinePressed = (code == 'Digit4' && altKey) || code == 'F4';
      var evolutionPressed = (code == 'Digit5' && altKey) || code == 'F5';
      var optionsPressed = (code == 'Digit6' && altKey) || code == 'F6';
      var exitPressed = (code == 'Digit0' && altKey) || code == 'F10';

      // open goals window
      if (goalsPressed)
        state = UISTATE_GOALS;
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
      // open options window
      else if (optionsPressed)
        state = UISTATE_OPTIONS;
      // open body window
      else if (bodyPressed &&
              (game.player.vars.inventoryEnabled ||
               game.player.vars.skillsEnabled ||
               game.player.vars.organsEnabled))
        state = UISTATE_BODY;
      // exit button
      else if (exitPressed)
        {
          // show exit yes/no dialog
          game.ui.event({
            state: UISTATE_YESNO,
            obj: {
              text: 'Do you want to exit the game?',
              func: function(yes: Bool) {
                if (yes)
                  electron.renderer.IpcRenderer.invoke('quit');
              }
            }
          });
        }
      return false;
    }

// handle player actions
  function handleActions(key: String, code: String, altKey: Bool, ctrlKey: Bool, shiftKey: Bool): Bool
    {
      // game finished
      if (game.isFinished)
        return false;

      // action prefix for body window
      if (_state == UISTATE_BODY)
        {
          var window: Body = cast components[_state];
          if (key == 'i' ||
              (code.indexOf('Digit') == 0 && ctrlKey))
            window.prefix('inventory');
          else if (key == 'b' ||
              (code.indexOf('Digit') == 0 && shiftKey))
            window.prefix('body');
        }

      // actions from action menu
      var ret = false;
      for (i in 1...11)
        if (code == 'Digit' + i)
          {
            var n = i;

            // s + number = 10 + action
            if (inputState > 0)
              n += 10;

            if (_state == UISTATE_DEFAULT)
              hud.action(n);
            else if (components[_state] != null)
              components[_state].action(n);
            return true;
//            inputState = 0;
//            ret = true;
//            break;
          }

      // yes/no
      if (_state == UISTATE_YESNO)
        {
          var n = 0;
          if (key == 'y')
            n = 1;
          else if (key == 'n')
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
          // skip until end of turn (alternative to z)
          if (code == 'Numpad5' ||// key == 'z' ||
              (game.config.laptopKeyboard && key == 'k'))
            {
              game.turn();
              game.updateHUD();
              ret = true;
            }
/*
          // toggle fullscreen
          else if (key == 'f')
            {
              isFullScreen = !isFullScreen;
              var doc = js.Browser.document;
              if (doc.fullscreenEnabled)
                {
                  doc.documentElement.requestFullscreen();
                  if (isFullScreen)
                    doc.documentElement.requestFullscreen();
                  else doc.exitFullscreen();
                }
              ret = true;
            }
*/
        }

/*
      // next 10 actions
      if (key == 's')
        {
          inputState = 1;
          ret = true;
        }*/

      return ret;
    }

// handle player movement
  function handleMovement(key: String, code: String): Bool
    {
      // game finished or window open
      if (game.isFinished ||
          _state != UISTATE_DEFAULT)
        return false;

      var dx = 0;
      var dy = 0;

      if (code == 'ArrowUp' ||
          code == 'Numpad8' ||
          (game.config.laptopKeyboard && key == 'i'))
        dy = -1;

      if (code == 'ArrowDown' ||
          code == 'Numpad2' ||
          (game.config.laptopKeyboard && key == ','))
        dy = 1;

      if (code == 'ArrowLeft' ||
          code == 'Numpad4' ||
          (game.config.laptopKeyboard && key == 'j'))
        dx = -1;

      if (code == 'ArrowRight' ||
          code == 'Numpad6' ||
          (game.config.laptopKeyboard && key == 'l'))
        dx = 1;

      if (code == 'Numpad7' ||
          (game.config.laptopKeyboard && key == 'u'))
        {
          dx = -1;
          dy = -1;
        }

      if (code == 'Numpad9' ||
          (game.config.laptopKeyboard && key == 'o'))
        {
          dx = 1;
          dy = -1;
        }

      if (code == 'Numpad1' ||
          (game.config.laptopKeyboard && key == 'm'))
        {
          dx = -1;
          dy = 1;
        }

      if (code == 'Numpad3' ||
          (game.config.laptopKeyboard && key == '.'))
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

// set CSS variable
  public static inline function setVar(s: String, v: String)
    {
      Browser.document.documentElement.style.setProperty(s, v);
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
//      trace(vstate);
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

// find element
  public function getElement(id: String): Element
    {
      return Browser.document.getElementById(id);
    }
}

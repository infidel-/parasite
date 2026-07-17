// new js ui group
package ui;

import js.Browser;
import js.html.KeyboardEvent;
import js.html.MouseEvent;
import js.html.CanvasElement;
import js.html.Element;

import game.Game;
import _UIState;

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
  public var shiftPressed: Bool; // true when shift is held
  var awaitingNextKey: Bool; // true when waiting for second key press for quick menu
  var quickMenuKeyup: String; // code of a quick-menu key whose keyup must be swallowed
  public var cult(get, never): ui.Cult;
  public var pedia(get, never): ui.Pedia;
  public var difficulty(get, never): ui.Difficulty;
  public var mainMenu(get, never): ui.MainMenu;

  public function new(g: Game)
    {
      game = g;
      isFullScreen = false;
      _state = UISTATE_DEFAULT;
      uiQueue = new List();
      uiQueuePaused = false;
      uiQueuePrev = null;
      shiftPressed = false;
      awaitingNextKey = false;
      quickMenuKeyup = null;
      hud = new HUD(this, game);
      canvas = cast Browser.document.getElementById('canvas');
      canvas.style.visibility = 'hidden';
      canvas.style.cursor = 'none';
      Browser.document.onkeydown = onKey;
      Browser.document.onkeyup = onKeyUp;
      canvas.onmousemove = function (e: MouseEvent) {
        game.scene.mouseX = e.clientX * Browser.window.devicePixelRatio;
        game.scene.mouseY = e.clientY * Browser.window.devicePixelRatio;
        game.scene.mouse.update();
        hud.onMouseMove(e);
      }
      canvas.onmouseleave = function (_) {
        hud.onMouseLeave();
      }
      canvas.onclick = function (e: MouseEvent) {
        game.scene.mouse.onClick(e);
      }
      // middle click is delivered as auxclick in Chromium/Electron.
      // wired always; Mouse.onClick gates debug branch on Const.isDebug
      untyped canvas.onauxclick = function (e: MouseEvent) {
        if (e.button == 1)
          {
            game.scene.mouse.onClick(e);
            e.preventDefault();
          }
      }
#if electron
      Browser.window.onerror = onError;
#end

      uiLocked = [ UISTATE_DIFFICULTY, UISTATE_CHOICE, UISTATE_YESNO ];
      uiNoClose = [ UISTATE_DEFAULT, UISTATE_YESNO, UISTATE_DIFFICULTY, UISTATE_CHOICE ];
      components = [
        UISTATE_MESSAGE => new Message(game),
        UISTATE_YESNO => new YesNo(game),
        UISTATE_DIFFICULTY => new Difficulty(game),
        UISTATE_CHOICE => new Choice(game),

        UISTATE_GOALS => new Goals(game),
        UISTATE_LOG => new Log(game),
        UISTATE_TIMELINE => new Timeline(game),
        UISTATE_EVOLUTION => new Evolution(game),
        UISTATE_BODY => new Body(game),
        UISTATE_FINISH => new Finish(game),
        UISTATE_OPTIONS => new Options(game),
        UISTATE_PEDIA => new Pedia(game),
        UISTATE_MAINMENU => new MainMenu(game),
        UISTATE_NEWGAME => new NewGame(game),
        UISTATE_SPOON => new Spoon(game),
        UISTATE_OVUM => new Ovum(game),
        UISTATE_CULT => new Cult(game),
        UISTATE_ABOUT => new About(game),
        UISTATE_PRESETS => new Presets(game),
#if electron
        UISTATE_MODS => new Mods(game),
        UISTATE_SAVES => new Saves(game),
#end
      ];
    }

#if electron
  public function onError(msg: Dynamic, url: String, line: Int, col: Int, err: Dynamic): Bool
    {
      var date = DateTools.format(Date.now(), "%d %b %Y %H:%M:%S");
      var l = date + ' v' + Version.getVersion() + ' ' + msg + ', ' +
        err.stack + ', line ' + line + ', col ' + col + '\n';
      trace(l);
      game.log('An exception has occured and was logged. Please send the log-YYYY-MM-DD.txt file to me (starinfidel@gmail.com).', COLOR_ALERT);
      try {
        HostBridge.logAppend(l);
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

// key releases
  function onKeyUp(e: KeyboardEvent)
    {
      if (e.key == 'Control' &&
          game.scene.controlPressed)
        {
          game.scene.controlPressed = false;
          game.scene.mouse.update(true);
          hud.updateAITooltip();
        }

      if (hud.consoleVisible())
        return;

      // swallow the keyup of a quick-menu second key so it does not double as its
      // gameplay bind (e.g. 't' entering targeting); matched by exact code set on
      // the keydown, so an interleaved release order does not eat the wrong keyup
      if (e.code == quickMenuKeyup)
        {
          quickMenuKeyup = null;
          return;
        }

      // enter targeting mode
      if (e.code == 'KeyT')
        {
          if (!game.isInputLocked() &&
              _state == UISTATE_DEFAULT &&
              hud.state == HUD_DEFAULT &&
              game.location == LOCATION_AREA &&
              game.player.state == PLR_STATE_HOST)
            {
              hud.targeting.enter();
              return;
            }
        }

      if (_state == UISTATE_DEFAULT)
        {
          // shift key - redraw actions list
          if (e.key == 'Shift' && game.config.shiftLongActions)
            {
              shiftPressed = false;
              hud.updateActions();
              return;
            }
        }
    }

// grab key presses
  function onKey(e: KeyboardEvent)
    {
      // street-debug mode owns the keyboard (fly cam / editor / inspector, on their own window
      // listeners) — suppress ALL game input while it is active. backtick toggles it off via
      // StreetView's own listener, so exiting still works
      if (game.location == LOCATION_AREA &&
          game.scene.city3d != null &&
          game.scene.city3d.debugActive())
        return;

      // ctrl enters AI-inspect (magnifier) mode, but not while the console is open
      if (e.key == 'Control' &&
          !game.scene.controlPressed &&
          !hud.consoleVisible())
        {
          game.scene.controlPressed = true;
          game.scene.mouse.update(true);
          hud.updateAITooltip();
        }

      if (hud.consoleVisible())
        return;
//      trace('code:' + e.code + ' alt:' + e.altKey + ' ctrl:' + e.ctrlKey + ' shift:' + e.shiftKey + ' key:' + e.key);

      // prevent F1-F10 from triggering defaults in browser
      // and 0-9
      if ((e.keyCode >= 112 && e.keyCode <= 121) ||
          (e.keyCode >= 48 && e.keyCode <= 57))
        e.preventDefault();

      // hud sub-modes only own the keyboard when no GUI window is open, so an
      // open window's Escape-to-close is not eaten by clearing a live target etc.
      if (_state == UISTATE_DEFAULT &&
          hud.state == HUD_COMMAND_MENU &&
          e.code == 'Escape')
        {
          hud.command.exit();
          return;
        }

      // Escape closes the ground-items submenu
      if (_state == UISTATE_DEFAULT &&
          hud.state == HUD_PICKUP_MENU &&
          e.code == 'Escape')
        {
          hud.state = HUD_DEFAULT;
          game.updateHUD();
          return;
        }

      // handle targeting mode keys
      if (_state == UISTATE_DEFAULT &&
          hud.state == HUD_TARGETING)
        {
          handleTargetingKey(e.key, e.code);
          return;
        }

      // handle quick menu double key press
      if (awaitingNextKey)
        {
          var handled = handleQuickMenu(e.key);
          awaitingNextKey = false;
          if (handled)
            {
              // swallow THIS key's keyup (matched by code) so it does not also
              // fire its gameplay bind; keyed by code, not a shared flag, so a
              // fast release order (q-up before t-up) can't consume it early
              quickMenuKeyup = e.code;
              return;
            }
        }

      // default state
      if (_state == UISTATE_DEFAULT)
        {
          // 3D city view: Space toggles the tactical overhead view (HUD stays up);
          // elsewhere it toggles the HUD
          if (e.code == 'Space')
            {
              if (game.location == LOCATION_AREA &&
                  game.scene.city3d != null &&
                  game.scene.city3d.running)
                game.scene.city3d.toggleTactical();
              else hud.toggle();
              return;
            }

          // enter restarts the game when it is finished
          if (game.state == GAMESTATE_FINISH &&
              (e.key == 'Enter' || e.key == 'r'))
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
                  game.scene.sounds.play('window-open');
                  state = UISTATE_MAINMENU;
                  return;
                }
            }
          // quick menu - set awaiting next key flag
          else if (e.key == 'q')
            {
              awaitingNextKey = true;
              return;
            }
          // shift key - redraw actions list
          else if (e.key == 'Shift' &&
              game.config.shiftLongActions &&
              !shiftPressed)
            {
              shiftPressed = true;
              hud.updateActions();
              return;
            }

          // shoot target
          if (hud.state == HUD_DEFAULT &&
              (e.key == 's' ||
               e.key == 'S'))
            {
              if (hud.targeting.canShootTarget())
                {
                  game.playerArea.attackTargetAction(hud.targeting.target);
                  return;
                }
            }

          // attack target with melee
          if (hud.state == HUD_DEFAULT &&
              (e.key == 'a' ||
               e.key == 'A'))
            {
              if (hud.targeting.canAttackTarget())
                {
                  game.playerArea.attackTargetAction(hud.targeting.target, true);
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

// handle targeting mode keys
  function handleTargetingKey(key: String, code: String)
    {
      if (code == 'ArrowLeft' ||
          code == 'ArrowUp' ||
          code == 'Numpad4' ||
          code == 'Numpad7' ||
          code == 'Numpad8' ||
          code == 'Numpad1')
        hud.targeting.rotate(-1);
      else if (code == 'ArrowRight' ||
          code == 'ArrowDown' ||
          code == 'Numpad6' ||
          code == 'Numpad9' ||
          code == 'Numpad2' ||
          code == 'Numpad3')
        hud.targeting.rotate(1);
      else if (code == 'Enter' ||
          code == 'NumpadEnter' ||
          code == 'Numpad5')
        hud.targeting.confirm();
      else if (code == 'Escape')
        hud.targeting.clear();
    }

// handle quick menu double key press
  function handleQuickMenu(key: String): Bool
    {
      // simulate the key press that handleWindows expects, then always report
      // handled so onKey does not re-process the same letter as a gameplay bind
      // (handleWindows returns false even when it opens a window, so 't' would
      // otherwise open the timeline AND fall through to the Target action)
      switch (key)
        {
          case 'g': // goals - simulate F1
            handleWindows('', 'F1', false, false);
          case 'b': // body - simulate F2
            handleWindows('', 'F2', false, false);
          case 'l': // log - simulate F3
            handleWindows('', 'F3', false, false);
          case 't': // timeline - simulate F4
            handleWindows('', 'F4', false, false);
          case 'e': // evolution - simulate F5
            handleWindows('', 'F5', false, false);
          case 'c': // cult - simulate F6
            handleWindows('', 'F6', false, false);
          default:
            return false;
        }
      return true;
    }

// handle opening and closing windows
  function handleWindows(key: String, code: String, altKey: Bool, ctrlKey: Bool): Bool
    {
      // let the active window consume the key first (e.g. main menu navigation)
      if (components[_state] != null &&
          components[_state].handleKey(key, code, altKey, ctrlKey))
        return true;

      // window open
      if (!Lambda.has(uiNoClose, _state))
        {
          // close windows
          if (key == 'Enter' ||
              key == 'NumpadEnter' ||
              key == 'Escape') 
            {
              game.scene.sounds.play('window-close');
              if (_state == UISTATE_OPTIONS ||
                  _state == UISTATE_PEDIA ||
                  _state == UISTATE_ABOUT ||
                  _state == UISTATE_NEWGAME ||
                  _state == UISTATE_MODS ||
                  _state == UISTATE_SAVES ||
                  _state == UISTATE_SPOON)
                state = UISTATE_MAINMENU;
              else if (_state == UISTATE_PRESETS)
                state = UISTATE_OPTIONS;
              else if (_state == UISTATE_MAINMENU &&
                  !game.isStarted)
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
      var cultPressed = (code == 'Digit6' && altKey) || code == 'F6';
      var optionsPressed = (code == 'Digit9' && altKey) || code == 'F9';
      var exitPressed = (code == 'Digit0' && altKey) || code == 'F10';
      var vstate = _state;

      // resolve the pressed window key to a target state (guards gate availability)
      var target = vstate;
      var keyed = true;
      if (goalsPressed)
        target = UISTATE_GOALS;
      else if (logPressed)
        target = UISTATE_LOG;
      else if (timelinePressed &&
          game.player.vars.timelineEnabled)
        target = UISTATE_TIMELINE;
      else if (evolutionPressed &&
          game.player.state == PLR_STATE_HOST &&
          game.player.evolutionManager.state > 0)
        target = UISTATE_EVOLUTION;
      else if (cultPressed &&
          game.cults[0].state == CULT_STATE_ACTIVE)
        target = UISTATE_CULT;
      else if (optionsPressed)
        target = UISTATE_OPTIONS;
      else if (bodyPressed &&
              (game.player.vars.inventoryEnabled ||
               game.player.vars.skillsEnabled ||
               game.player.vars.organsEnabled))
        target = UISTATE_BODY;
      // exit button: confirm dialog
      else if (exitPressed)
        {
          game.ui.event({
            type: UIEVENT_STATE,
            state: UISTATE_YESNO,
            obj: {
              text: 'Exit the game?',
              sub: 'This will end your current session.',
              danger: true,
              func: function(yes: Bool) {
#if electron
                if (yes)
                  HostBridge.quit();
#end
              }
            }
          });
          return false;
        }
      else keyed = false;

      // a window key resolved: re-pressing its own key while open toggles it shut
      if (keyed)
        {
          if (target == _state)
            {
              game.scene.sounds.play('window-close');
              closeWindow();
            }
          // route through the navbar cell so it clicks/animates like the mouse;
          // options/exit have no nav cell, so fall back to a direct state set
          else if (!pressButton(hud.getMenuButton(target)))
            {
              state = target;
              game.scene.sounds.play('window-open');
            }
        }
      return false;
    }

// simulate a mouse click on a button: brief press visual, then a real click event.
// the click is deferred so the press paints before the action rebuilds/replaces
// the element (most action buttons clear their container on activation). this also
// matches real mouse feel, where :active shows during mousedown before click fires.
// returns false when there is no element so callers can fall back to direct logic.
  public static function pressButton(el: js.html.Element, shift = false): Bool
    {
      if (el == null)
        return false;
      el.classList.add('pressed');
      Browser.window.setTimeout(function() {
        el.classList.remove('pressed');
        el.dispatchEvent(new js.html.MouseEvent('click',
          { bubbles: true, cancelable: true, shiftKey: shift }));
      }, 130);
      return true;
    }

// handle player actions
  function handleActions(key: String, code: String, altKey: Bool, ctrlKey: Bool, shiftKey: Bool): Bool
    {
      // game finished
      if (game.isInputLocked())
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
              hud.pressAction(n, shiftKey);
            else if (components[_state] != null &&
                !pressButton(components[_state].getButton(n), shiftKey))
              components[_state].action(n);
            return true;
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
              if (!pressButton(components[_state].getButton(n)))
                components[_state].action(n);
              return true;
            }
        }

      // no windows open, hud actions
      if (_state == UISTATE_DEFAULT)
        {
          // actions by key
          ret = hud.keyAction(key);
          if (hud.state == HUD_DEFAULT)
            {
              // skip until end of turn (alternative to z)
              if (code == 'Numpad5' ||// key == 'z' ||
                  (game.config.laptopKeyboard && key == 'k'))
                {
                  game.turn();
                  game.updateHUD();
                  ret = true;
                }
            }
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

// check if player cannot move and return
  public function cannotMove(): Bool
    {
      if (hud.state == HUD_DEFAULT)
        return false;
      switch (hud.state)
        {
          case HUD_CHAT, HUD_CONVERSE_MENU:
            game.actionFailed('You cannot move during a conversation.');
          case HUD_TARGETING:
            // no message
          case HUD_COMMAND_MENU:
            game.actionFailed('You cannot move while commanding followers.');
          case HUD_PICKUP_MENU:
            game.actionFailed('You cannot move while picking up items.');
          default:
        }
      return true;
    }

// handle player movement
  function handleMovement(key: String, code: String): Bool
    {
      // game finished or window open
      if (game.isInputLocked() ||
          _state != UISTATE_DEFAULT)
        return false;
      // moving with keyboard hides mouse
//      game.scene.mouse.hide();

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

      // move cursor in base building mode
      if (hud.state == HUD_BASE_BUILDING)
        {
          if (game.location == LOCATION_AREA &&
              game.cults.length > 0 &&
              game.cults[0].base != null)
            return game.cults[0].base.moveCursor(dx, dy);
          return true;
        }

      if (cannotMove())
        return false;

      // street-debug mode owns numpad/arrows for the 3D fly camera
      if (game.location == LOCATION_AREA &&
          game.scene.city3d != null &&
          game.scene.city3d.debugActive())
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

  function get_cult(): ui.Cult
    {
      return cast components[UISTATE_CULT];
    }

  function get_pedia(): ui.Pedia
    {
      return cast components[UISTATE_PEDIA];
    }

  function get_difficulty(): ui.Difficulty
    {
      return cast components[UISTATE_DIFFICULTY];
    }

  function get_mainMenu(): ui.MainMenu
    {
      return cast components[UISTATE_MAINMENU];
    }

// set new GUI state, open and close windows if needed
  public function set_state(vstate: _UIState)
    {
      // clear shift key
      if (shiftPressed && game.config.shiftLongActions)
        {
          shiftPressed = false;
          hud.updateActions();
        }

//      trace(vstate);
//      Const.traceStack();
      var stateChanged = (_state != vstate);
      if (stateChanged)
        game.scene.clearPath();
      var wasWindowOpen = (_state != UISTATE_DEFAULT);
      if (_state != UISTATE_DEFAULT)
        {
          if (components[_state] != null)
            components[_state].hide(wasWindowOpen);
        }

      _state = vstate;
      if (_state != UISTATE_DEFAULT && components[_state] != null)
        {
          if (components[_state] != null)
            components[_state].show(wasWindowOpen);

          if (_state != UISTATE_LOG)
            components[_state].scrollToBegin();
        }

      if (_state == UISTATE_DEFAULT)
        {
          canvas.focus();
          hud.show();
        }
      else hud.hide();
      // navbar persists as a tab row over the six window states (set last, it
      // overrides the hud.show()/hide() navbar toggle above)
      hud.applyNavbarState(_state);
      // atmosphere stays during gameplay/windows but not over the main menu bg
      hud.setAtmoVisible(_state != UISTATE_MAINMENU);

      return _state;
    }

// add event to the GUI queue
  public function event(ev: _UIEvent)
    {
      // ignore highlight events on debug
/*
      if (game.importantMessagesEnabled &&
          ev.type == UIEVENT_HIGHLIGHT)
        return;*/
      uiQueue.add(ev);

      // no windows open, work on event immediately
      if (state == UISTATE_DEFAULT)
        closeWindow();
    }

// clear GUI queue
  public inline function clearEvents()
    {
      uiQueue.clear();
      hud.goals.clearQueue();
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

          // change UI state (open window)
          if (ev.type == UIEVENT_STATE)
            {
              // overall difficulty: auto-set
              if (ev.state == UISTATE_DIFFICULTY &&
                  game.config.difficulty > 0)
                {
                  difficulty.setParams(ev.obj);
                  difficulty.action(game.config.difficulty);
                  return;
                }

              // overall difficulty: presets
              else if (ev.state == UISTATE_DIFFICULTY &&
                  game.config.difficulty < 0)
                {
                  var difficultySetting = game.config.difficulty;
                  var presets = game.profile.object.difficultyPresets;
                  var presetID = - difficultySetting - 1;
                  if (presets.length > presetID)
                    difficultySetting = Reflect.field(
                      presets[presetID], ev.obj);
                  else trace('no difficulty preset for ' + difficultySetting);
                  if (difficultySetting == null)
                    difficultySetting = 1;
                  this.difficulty.setParams(ev.obj);
                  this.difficulty.action(difficultySetting);
                  return;
                }
              // set window params and then open window
              else if (components[ev.state] != null)
                components[ev.state].setParams(ev.obj);
              else
                {
                  trace('component is null for ' + ev.state);
                  state = UISTATE_DEFAULT;
                  return;
                }
              state = ev.state;
            }
          // highlight HUD button
          else if (ev.type == UIEVENT_HIGHLIGHT)
            {
              state = UISTATE_DEFAULT;
              hud.getMenuButton(ev.state).className += ' highlight-button';
              // only needed when debugging
              closeWindow();
            }
          // finish the game
          else if (ev.type == UIEVENT_FINISH)
            {
              game.finish({
                result: ev.obj.result,
                text: ev.obj.condition,
                img: ev.obj.img,
                filter: ev.obj.filter,
              });
            }
          return;
        }

      state = UISTATE_DEFAULT;
      // UI is idle again: play any goal animations deferred while windows were up
      hud.goals.flush();
      if (game.state == GAMESTATE_REBIRTH)
        game.endRebirth();
      game.scene.draw();
    }

// find element
  public function getElement(id: String): Element
    {
      return Browser.document.getElementById(id);
    }

// get component by state
  public inline function getComponent(state: _UIState): UIWindow
    {
      return components[state];
    }

// update currently opened window
  public function updateWindow()
    {
      if (_state != UISTATE_DEFAULT &&
          components[_state] != null)
        components[_state].update();
    }
}

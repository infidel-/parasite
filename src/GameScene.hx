// - has all links to windows and handles input

import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;
import haxe.ui.core.Component;
#if !js
import sys.io.File;
#end

import ui.*;
import game.Game;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
  public var region: RegionView; // region view
  public var mouse: Mouse; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  var uiQueue: List<_UIEvent>; // gui event queue
  public var state(get, set): _UIState;
  var _state: _UIState; // current HUD state (default, evolution, etc)
  var components: Map<_UIState, UIWindow>; // GUI windows (HaxeUI)
  var uiLocked: Array<_UIState>; // list of gui states that lock the player
  public var entityAtlas: TileAtlas; // entity graphics
  public var controlPressed: Bool; // Ctrl key pressed?
  public var shiftPressed: Bool; // Shift key pressed?

  // camera tile x,y
  public var cameraTileX1: Int;
  public var cameraTileY1: Int;
  public var cameraTileX2: Int;
  public var cameraTileY2: Int;

//  var _dx: Int; // movement vars - movement direction (changed in handleInput)
//  var _dy: Int;
  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)


  public function new(g: Game)
    {
      super();
      game = g;
      uiLocked = [];
      _state = UISTATE_DEFAULT;
      uiQueue = new List();
      controlPressed = false;
      shiftPressed = false;
      cameraTileX1 = 0;
      cameraTileY1 = 0;
      cameraTileX2 = 0;
      cameraTileY2 = 0;

      Input.define("ctrl", [ 18 ]); // Alt key
      Input.define("shift", [ Key.SHIFT ]);
      Input.define("up", [ Key.UP, Key.W, Key.NUMPAD_8 ]);
      Input.define("down", [ Key.DOWN, Key.X, Key.NUMPAD_2 ]);
      Input.define("left", [ Key.LEFT, Key.A, Key.NUMPAD_4 ]);
      Input.define("right", [ Key.RIGHT, Key.D, Key.NUMPAD_6 ]);
      Input.define("upleft", [ Key.Q, Key.NUMPAD_7 ]);
      Input.define("upright", [ Key.E, Key.NUMPAD_9 ]);
      Input.define("downleft", [ Key.Z, Key.NUMPAD_1 ]);
      Input.define("downright", [ Key.C, Key.NUMPAD_3 ]);

      Input.define("pageup", [ Key.PAGE_UP ]);
      Input.define("pagedown", [ Key.PAGE_DOWN ]);
      Input.define("home", [ Key.HOME ]);
      Input.define("end", [ Key.END ]);
      Input.define("enter", [ Key.ENTER ]);

      Input.define("action1", [ Key.DIGIT_1 ]);
      Input.define("action2", [ Key.DIGIT_2 ]);
      Input.define("action3", [ Key.DIGIT_3 ]);
      Input.define("action4", [ Key.DIGIT_4 ]);
      Input.define("action5", [ Key.DIGIT_5 ]);
      Input.define("action6", [ Key.DIGIT_6 ]);
      Input.define("action7", [ Key.DIGIT_7 ]);
      Input.define("action8", [ Key.DIGIT_8 ]);
      Input.define("action9", [ Key.DIGIT_9 ]);
      Input.define("action10", [ Key.DIGIT_0 ]);

      Input.define("goalsWindow", [ Key.F1 ]);
      Input.define("inventoryWindow", [ Key.F2 ]);
      Input.define("skillsWindow", [ Key.F3 ]);
      Input.define("logWindow", [ Key.F4 ]);

      Input.define("timelineWindow", [ Key.F5 ]);
      Input.define("evolutionWindow", [ Key.F6 ]);
      Input.define("organsWindow", [ Key.F7 ]);
      Input.define("debugWindow", [ Key.F9 ]);
      Input.define("exit", [ Key.F10 ]);
//      Input.define("test", [ Key.SPACE ]);

      Input.define("skipTurn", [ Key.NUMPAD_5 ]);
      Input.define("closeWindow", [ Key.ESCAPE ]);

//      _dx = 0;
//      _dy = 0;
      _inputState = 0;
    }


  public override function begin()
    {
      // load all entity images into atlas
      entityAtlas = new TileAtlas("gfx/entities.png");
      entityAtlas.prepare(Const.TILE_WIDTH, Const.TILE_HEIGHT);

      // init GUI
      hud = new HUD(game);

      components = [
        UISTATE_DIFFICULTY => new Difficulty(game),
        UISTATE_YESNO => new YesNo(game),
        UISTATE_DOCUMENT => new Document(game),
        UISTATE_MESSAGE => new Message(game),

        UISTATE_GOALS => new Goals(game),
        UISTATE_INVENTORY => new Inventory(game),
        UISTATE_SKILLS => new Skills(game),
        UISTATE_TIMELINE => new Timeline(game),
        UISTATE_EVOLUTION => new Evolution(game),
        UISTATE_ORGANS => new Organs(game),
        UISTATE_LOG => new Log(game),
        UISTATE_DEBUG => new Debug(game),
        UISTATE_FINISH => new Finish(game),
        ];
      uiLocked = [ UISTATE_DIFFICULTY, UISTATE_YESNO, UISTATE_DOCUMENT ];

      // init mouse cursor
      mouse = new Mouse(game);
      HXP.stage.addChild(mouse);

      area = new AreaView(this);
      region = new RegionView(this);

      // init game state
      game.init();
    }


// update camera position
  public function updateCamera()
    {
      var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
      if (game.location == LOCATION_AREA)
        {
          x = game.playerArea.entity.x;
          y = game.playerArea.entity.y;
          w = game.area.width;
          h = game.area.height;
        }

      else if (game.location == LOCATION_REGION)
        {
          x = game.playerRegion.entity.x;
          y = game.playerRegion.entity.y;
          w = game.region.width;
          h = game.region.height;
        }

      x -= HXP.halfWidth;
      y -= HXP.halfHeight;

      if (x + HXP.windowWidth > Const.TILE_WIDTH * w)
        x = Const.TILE_WIDTH * w - HXP.windowWidth;
      if (y + HXP.windowHeight > Const.TILE_HEIGHT * h)
        y = Const.TILE_HEIGHT * h - HXP.windowHeight;

      if (x < 0)
        x = 0;
      if (y < 0)
        y = 0;

      HXP.camera.x = x;
      HXP.camera.y = y;

      // update tile x,y
      cameraTileX1 = Std.int(HXP.camera.x / Const.TILE_WIDTH);
      cameraTileY1 = Std.int(HXP.camera.y / Const.TILE_HEIGHT);
      cameraTileX2 =
        Std.int((HXP.camera.x + HXP.windowWidth) / Const.TILE_WIDTH);
      cameraTileY2 =
        Std.int((HXP.camera.y + HXP.windowHeight) / Const.TILE_HEIGHT);
    }


// handle player input
  function handleInput()
    {
      // show console (;)
      if (Input.released(186))
        {
          hud.showConsole();
          return;
        }

      // run console command
      if (Input.pressed(Key.ENTER) && hud.consoleVisible())
        {
          hud.runConsoleCommand();
          return;
        }

      // toggle control
      if (Input.pressed("ctrl"))
        {
          controlPressed = true;
          return;
        }
      else if (Input.released("ctrl"))
        {
          controlPressed = false;
          return;
        }

      // toggle control
      if (Input.pressed("shift"))
        {
          shiftPressed = true;
          return;
        }
      else if (Input.released("shift"))
        {
          shiftPressed = false;
          return;
        }

      // toggle gui
      if (!hud.consoleVisible())
        {
          if (Input.pressed(Key.SPACE))
            {
              hud.show(false);
              return;
            }
          if (Input.released(Key.SPACE))
            {
              hud.show(true);
              return;
            }
        }
/*
      trace(Input.lastKey);
      if (Input.lastKey != null)
        trace(Key.nameOfKey(Input.lastKey));
*/

      if (!hud.consoleVisible())
        {
          // enter restarts the game when it is finished
          if (game.isFinished && Input.pressed("enter") &&
              _state == UISTATE_DEFAULT)
            {
              game.restart();
              return;
            }

          var ret = handleWindows();
          if (!ret)
            handleMovement();

          // hack: disallow actions when control/alt pressed
          if (!controlPressed)
            handleActions();
        }

      if (Input.pressed("exit"))
        exit();
    }


// set new GUI state, open and close windows if needed
  public function set_state(vstate: _UIState)
    {
      if (_state != UISTATE_DEFAULT)
        {
          if (components[_state] != null)
            components[_state].hide();

          // hack: getting delta clears the mouse wheel flag
          Input.mouseWheelDelta;
        }

      _state = vstate;
      if (_state != UISTATE_DEFAULT)
        {
          if (components[_state] != null)
            components[_state].show();
        }

      return _state;
    }


// get GUI state
  inline function get_state(): _UIState
    {
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


// close the current window
  public function closeWindow()
    {
      // check if there are more UI events in the queue
      if (uiQueue.length > 0)
        {
          // get next event
          var ev = uiQueue.first();
          uiQueue.remove(ev);

          if (components[ev.state] != null)
            components[ev.state].setParams(ev.obj);

          state = ev.state;

          return;
        }

      state = UISTATE_DEFAULT;
    }


// handle opening and closing windows
  function handleWindows(): Bool
    {
      // scrolling text
      if (_state != UISTATE_DEFAULT)
        {
          // get amount of lines
          var lines = 0;
          if (Input.pressed("pageup") ||
            (Input.pressed(Key.K) && shiftPressed))
            lines = -20;
          else if (Input.pressed("pagedown") ||
            (Input.pressed(Key.J) && shiftPressed))
            lines = 20;
          else if (Input.pressed("up") || Input.pressed(Key.K))
            lines = -1;
          else if (Input.pressed("down") || Input.pressed(Key.J))
            lines = 1;

          // hack: disallow movement while in window
          if (Input.pressed("left") ||
              Input.pressed("right")||
              Input.pressed("upleft")||
              Input.pressed("upright")||
              Input.pressed("downleft")||
              Input.pressed("downright"))
            return true;

          // window scrolling
          if (_state != UISTATE_DEFAULT)
            {
              var win: UIWindow = cast components[_state];

              if (lines != 0)
                {
                  win.scroll(lines);
                  return true;
                }

              else if (Input.pressed("end") ||
                (Input.pressed(Key.G) && shiftPressed))
                {
                  win.scrollToEnd();
                  return true;
                }

              else if (Input.pressed("home") || Input.pressed(Key.G))
                {
                  win.scrollToBegin();
                  return true;
                }
            }

          // skip for now
          else if (_state == UISTATE_DIFFICULTY || _state == UISTATE_YESNO)
            1;
        }

      // ui in locked state, do not allow changing windows
      if (Lambda.has(uiLocked, _state))
        return true;

      // window open
      if (_state != UISTATE_DEFAULT)
        {
          if (Input.pressed("enter") && _state == UISTATE_MESSAGE)
            closeWindow();

          // close windows
          if (Input.pressed("closeWindow"))
            closeWindow();
        }

      // no windows open
        {
          var goalsPressed =
            (Input.pressed("action1") && controlPressed) ||
            Input.pressed("goalsWindow");
          var inventoryPressed =
            (Input.pressed("action2") && controlPressed) ||
            Input.pressed("inventoryWindow");
          var skillsPressed =
            (Input.pressed("action3") && controlPressed) ||
            Input.pressed("skillsWindow");
          var logPressed =
            (Input.pressed("action4") && controlPressed) ||
            Input.pressed("logWindow");
          var timelinePressed =
            (Input.pressed("action5") && controlPressed) ||
            Input.pressed("timelineWindow");
          var evolutionPressed =
            (Input.pressed("action6") && controlPressed) ||
            Input.pressed("evolutionWindow");
          var organsPressed =
            (Input.pressed("action7") && controlPressed) ||
            Input.pressed("organsWindow");
          var debugPressed =
            (Input.pressed("action9") && controlPressed) ||
            Input.pressed("debugWindow");

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
            {
              state = UISTATE_LOG;
              var win: Log = cast components[_state];
              win.scrollToEnd();
            }

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

#if mydebug
          // open debug window
          else if (debugPressed && !game.isFinished)
            state = UISTATE_DEBUG;
#end
        }

      return false;
    }


// handle player movement
  function handleMovement()
    {
      // game finished
      if (game.isFinished)
        return;

      var dx = 0;
      var dy = 0;

      if (Input.pressed("up"))
        dy = -1;

      if (Input.pressed("down"))
        dy = 1;

      if (Input.pressed("left"))
        dx = -1;

      if (Input.pressed("right"))
        dx = 1;

      if (Input.pressed("upleft"))
        {
          dx = -1;
          dy = -1;
        }

      if (Input.pressed("upright"))
        {
          dx = 1;
          dy = -1;
        }

      if (Input.pressed("downleft"))
        {
          dx = -1;
          dy = 1;
        }

      if (Input.pressed("downright"))
        {
          dx = 1;
          dy = 1;
        }

      if (dx == 0 && dy == 0)
        return;

      // area mode
      if (game.location == LOCATION_AREA)
        game.playerArea.moveAction(dx, dy);

      // area mode
      else if (game.location == LOCATION_REGION)
        game.playerRegion.moveAction(dx, dy);
    }


// handle player actions
  function handleActions()
    {
      mouse.update();

      // game finished
      if (game.isFinished)
        return;

      // actions from action menu
      for (i in 1...11)
        if (Input.pressed("action" + i))
          {
            var n = i;

            // s + number = 10 + action
            if (_inputState > 0)
              n += 10;

            if (_state == UISTATE_DEFAULT)
              hud.action(n);
            else if (components[_state] != null)
              components[_state].action(n);

            _inputState = 0;
            break;
          }

      if (_state == UISTATE_DEFAULT)
        {
/*
          // test action
          if (Input.pressed("test"))
            hud.test();
*/

          // skip until end of turn
          if (Input.pressed("skipTurn"))
            {
              game.turn();

              // update HUD info
              game.updateHUD();
            }
        }

      // next 10 actions
      if (Input.pressed(Key.S))
        _inputState = 1;
    }


// entity update
  public override function update()
    {
      try {
        // path active, try to move on it
        if (game.location == LOCATION_AREA && game.playerArea.path != null)
          game.playerArea.nextPath();
        else if (game.location == LOCATION_REGION &&
            game.playerRegion.target != null)
          game.playerRegion.nextPath();

        // handle player input
        else handleInput();

        // update camera position
        updateCamera();

        super.update();
        }
      catch (e: Dynamic)
        {
          var stack = haxe.CallStack.toString(
            haxe.CallStack.exceptionStack());
#if !js
          // log to file
          var f = File.append('exceptions.txt', false);
          f.writeString('Exception: ' + e + '\n');
          f.writeString(stack + '\n');
          f.close();
#end

          // write to stdout
          trace('Exception: ' + e);
          trace(stack);

#if !js
          // send exception to web server
          if (game.config.sendExceptions)
            {
              var s = new StringBuf();
              s.add('v' + Version.getVersion() +
                ' (build: ' + Version.getBuild() +
                ') ' + Sys.systemName() + '\n');
              s.add(game.messageList.last() + '\n');
              s.add('Exception: ' + e + '\n');
              s.add(stack + '\n');

              var h = new haxe.Http(
                'http://parasite.in-fi-del.net/exception.php');
              h.addParameter('msg', s.toString());
              h.onData = function(d){
                // show window
                var finishText = "Something broke! An exception was thrown and sent to the Dark Realm (exception gathering server). Unfortunately, the game cannot be continued. Sorry!\n\n" +
                  "P.S. If you want to disable exception gathering thingy for whatever reason, open the parasite.cfg configuration file and set sendExceptions to 0.";
                uiQueue.add({
                  state: UISTATE_FINISH,
                  obj: finishText
                });
                closeWindow();
              }
              h.onError = function(e){
                var finishText = "Something broke! An exception was thrown and saved to exceptions.txt file. Unfortunately, the game cannot be continued. Sorry!\n\n" +
                  "P.S. If you want to help the development, send the contents of the exceptions.txt file to starinfidel_at_gmail_dot_com. Thanks!";
                uiQueue.add({
                  state: UISTATE_FINISH,
                  obj: finishText
                });
                closeWindow();
                trace(e);
              }
              h.request(true);
            }

          else
#end
            {
              // show window
              var finishText =
#if !js
                "Something broke! An exception was thrown and save to exceptions.txt file. Unfortunately, the game cannot be continued. Sorry!\n\n" +
                "P.S. If you want to help the development, send the contents of the exceptions.txt file to starinfidel_at_gmail_dot_com. Thanks!";
#else
                "Something broke! Unfortunately, the game cannot be continued. Sorry!\n" +
                '<font size="12px">Exception: ' + e + '\n' +
                stack + '</font>\n' +
                "P.S. If you want to help the development, make a screenshot of this message and send it to starinfidel_at_gmail_dot_com. Thanks!";
#end
                uiQueue.add({
                  state: UISTATE_FINISH,
                  obj: finishText
                });
                closeWindow();
            }
        }
    }


  public inline function exit()
    {
#if !js
        Sys.exit(1);
#else
#end
    }
}

// UI events (open specific UI, display message, etc)

typedef _UIEvent = {
  var state: _UIState;  // new UI state
  var obj: Dynamic; // parameters
}

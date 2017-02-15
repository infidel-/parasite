// - has all links to windows and handles input

import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;
#if !js
import sys.io.File;
#end

import entities.*;
import game.Game;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view
  public var region: RegionView; // region view
  public var mouse: MouseEntity; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  var hudState: _HUDState; // current HUD state (default, evolution, etc)
  var windows: Map<_HUDState, TextWindow>; // GUI windows
  public var entityAtlas: TileAtlas; // entity graphics
  public var controlPressed: Bool; // Ctrl key pressed?
  public var shiftPressed: Bool; // Shift key pressed?

//  var _dx: Int; // movement vars - movement direction (changed in handleInput)
//  var _dy: Int;
  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)


  public function new(g: Game)
    {
      super();
      game = g;
      hudState = HUDSTATE_DEFAULT;
      controlPressed = false;
      shiftPressed = false;

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
      mouse = new MouseEntity(game);
      add(mouse);
      hud = new HUD(game);

      windows = [
        HUDSTATE_GOALS => new GoalsWindow(game),
        HUDSTATE_INVENTORY => new InventoryWindow(game),
        HUDSTATE_SKILLS => new SkillsWindow(game),
        HUDSTATE_EVOLUTION => new EvolutionWindow(game),
        HUDSTATE_ORGANS => new OrgansWindow(game),
        HUDSTATE_TIMELINE => new TimelineWindow(game),
        HUDSTATE_LOG => new LogWindow(game),
        HUDSTATE_DEBUG => new DebugWindow(game),
        HUDSTATE_MESSAGE => new MessageWindow(game),
        HUDSTATE_FINISH => new FinishWindow(game),
        ];

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
              getState() == HUDSTATE_DEFAULT)
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
  public function setState(vstate: _HUDState)
    {
      if (hudState != HUDSTATE_DEFAULT)
        windows[hudState].hide();

      hudState = vstate;
      if (hudState != HUDSTATE_DEFAULT)
        windows[hudState].show();
    }


// get GUI state
  public function getState(): _HUDState
    {
      return hudState;
    }


// close the current window
  function closeWindow()
    {
      // in case of message window check if there are more messages in the queue
      if (hudState == HUDSTATE_MESSAGE &&
          game.importantMessageQueue.length > 0)
        {
          game.importantMessage = game.importantMessageQueue.first();
          game.importantMessageQueue.remove(game.importantMessage);

          setState(HUDSTATE_MESSAGE);

          return;
        }

      setState(HUDSTATE_DEFAULT);
    }


// handle opening and closing windows
  function handleWindows(): Bool
    {
      // window open
      if (hudState != HUDSTATE_DEFAULT)
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

          if (lines != 0)
            {
              windows[hudState].scroll(lines);
              return true;
            }

          if (Input.pressed("end") ||
            (Input.pressed(Key.G) && shiftPressed))
            {
              windows[hudState].scrollToEnd();
              return true;
            }

          if (Input.pressed("home") || Input.pressed(Key.G))
            {
              windows[hudState].scrollToBegin();
              return true;
            }

          if (Input.pressed("enter") && windows[hudState].exitByEnter)
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
            setState(HUDSTATE_GOALS);

          // open inventory window (if items are learned)
          else if (inventoryPressed &&
              game.player.state == PLR_STATE_HOST &&
              game.player.host.isHuman &&
              game.player.vars.inventoryEnabled)
            setState(HUDSTATE_INVENTORY);

          // open skills window (if skills are learned)
          else if (skillsPressed &&
              game.player.vars.skillsEnabled)
            setState(HUDSTATE_SKILLS);

          // open message log window
          else if (logPressed)
            {
              setState(HUDSTATE_LOG);
              windows[hudState].scrollToEnd();
            }

          // open timeline window
          else if (timelinePressed &&
              game.player.vars.timelineEnabled)
            setState(HUDSTATE_TIMELINE);

          // open evolution window (if enabled)
          else if (evolutionPressed &&
              game.player.state == PLR_STATE_HOST &&
              game.player.evolutionManager.state > 0)
            setState(HUDSTATE_EVOLUTION);

          // open organs window
          else if (organsPressed &&
              game.player.state == PLR_STATE_HOST &&
              game.player.vars.organsEnabled)
            setState(HUDSTATE_ORGANS);

#if mydebug
          // open debug window
          else if (debugPressed && !game.isFinished)
            setState(HUDSTATE_DEBUG);
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

            if (hudState == HUDSTATE_DEFAULT)
              hud.action(n);
            else windows[hudState].action(n);

            _inputState = 0;
            break;
          }

      if (hudState == HUDSTATE_DEFAULT)
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

          // handle mouse input
          mouse.handleInput();
        }

      // next 10 actions
      if (Input.pressed(Key.S))
        _inputState = 1;
    }


// entity update
  public override function update()
    {
      try {
        // handle player input
        handleInput();

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
                game.finishText = "Something broke! An exception was thrown and sent to the Dark Realm (exception gathering server). Unfortunately, the game cannot be continued. Sorry!\n\n" +
                  "P.S. If you want to disable exception gathering thingy for whatever reason, open the parasite.cfg configuration file and set sendExceptions to 0.";
                setState(HUDSTATE_FINISH);
              }
              h.onError = function(e){
                game.finishText = "Something broke! An exception was thrown and saved to exceptions.txt file. Unfortunately, the game cannot be continued. Sorry!\n\n" +
                  "P.S. If you want to help the development, send the contents of the exceptions.txt file to starinfidel_at_gmail_dot_com. Thanks!";
                setState(HUDSTATE_FINISH);
                trace(e);
              }
              h.request(true);
            }

          else
#end
            {
              // show window
              game.finishText =
#if !js
                "Something broke! An exception was thrown and save to exceptions.txt file. Unfortunately, the game cannot be continued. Sorry!\n\n" +
                "P.S. If you want to help the development, send the contents of the exceptions.txt file to starinfidel_at_gmail_dot_com. Thanks!";
#else
                "Something broke! Unfortunately, the game cannot be continued. Sorry!\n" +
                '<font size="12px">Exception: ' + e + '\n' +
                stack + '</font>\n' +
                "P.S. If you want to help the development, make a screenshot of this message and send it to starinfidel_at_gmail_dot_com. Thanks!";
#end
              setState(HUDSTATE_FINISH);
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

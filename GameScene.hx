// - has all links to windows and handles input

import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;

import entities.*;
import game.Game;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var area: AreaView; // area view 
  public var mouse: MouseEntity; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  var hudState: _HUDState; // current HUD state (default, evolution, etc)
  var windows: Map<_HUDState, TextWindow>; // GUI windows
  public var entityAtlas: TileAtlas; // entity graphics

//  var _dx: Int; // movement vars - movement direction (changed in handleInput)
//  var _dy: Int;
  var _inputState: Int; // action input state (0 - 1..9, 1 - 10..19, etc)


  public function new(g: Game)
    {
      super();
      game = g;
      hudState = HUDSTATE_DEFAULT;

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

      Input.define("skipTurn", [ Key.NUMPAD_5, Key.SPACE ]);
      Input.define("closeWindow", [ Key.ESCAPE ]);

//      _dx = 0;
//      _dy = 0;
      _inputState = 0;
    }


  public override function begin()
    {
      // load all entity images into atlas
      entityAtlas = new TileAtlas("gfx/entities.png", Const.TILE_WIDTH, Const.TILE_HEIGHT);

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
        HUDSTATE_DEBUG => new DebugWindow(game)
        ];

      area = new AreaView(this);

      // init game state
      game.init();
    }


// update camera position
  public function updateCamera()
    {
      var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
      if (game.location == Game.LOCATION_AREA)
        {
          x = game.playerArea.entity.x;
          y = game.playerArea.entity.y;
          w = game.area.width;
          h = game.area.height;
        }

      else if (game.location == Game.LOCATION_REGION)
        {
          x = game.region.player.entity.x;
          y = game.region.player.entity.y;
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
/*
      trace(Input.lastKey);
      if (Input.lastKey != null)
        trace(Key.nameOfKey(Input.lastKey));
*/
      var ret = handleWindows();
      if (!ret)
        handleMovement();
      handleActions();
    
      if (Input.pressed("exit"))
        Sys.exit(1);
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


// handle opening and closing windows
  function handleWindows(): Bool
    {
      // window open
      if (hudState != HUDSTATE_DEFAULT)
        {
          // get amount of lines
          var lines = 0;
          if (Input.pressed("up"))
            lines = -1;
          else if (Input.pressed("down"))
            lines = 1;
          else if (Input.pressed("pageup"))
            lines = -20;
          else if (Input.pressed("pagedown"))
            lines = 20;

          if (lines != 0)
            {
              windows[hudState].scroll(lines);
              return true;
            }

          if (Input.pressed("home"))
            {
              windows[hudState].scrollToBegin();
              return true;
            }

          if (Input.pressed("end"))
            {
              windows[hudState].scrollToEnd();
              return true;
            }

          // close windows
          if (Input.pressed("closeWindow"))
            setState(HUDSTATE_DEFAULT);
        }

      // no windows open
//      else if (hudState == HUDSTATE_DEFAULT)
        {
          // open inventory window (if items are learned)
          if (Input.pressed("inventoryWindow") &&
              game.player.state == PLR_STATE_HOST &&
              game.player.host.isHuman &&
              game.player.vars.inventoryEnabled)
            setState(HUDSTATE_INVENTORY);

          // open evolution window (if enabled)
          else if (Input.pressed("evolutionWindow") &&
                   game.player.evolutionManager.state > 0)
            setState(HUDSTATE_EVOLUTION);

          // open skills window (if skills are learned)
          else if (Input.pressed("skillsWindow") &&
                   game.player.vars.skillsEnabled)
            setState(HUDSTATE_SKILLS);

          // open organs window
          else if (Input.pressed("organsWindow") &&
                   game.player.state == PLR_STATE_HOST &&
                   game.player.vars.organsEnabled)
            setState(HUDSTATE_ORGANS);

          // open timeline window
          else if (Input.pressed("timelineWindow") &&
                   game.player.vars.timelineEnabled)
            setState(HUDSTATE_TIMELINE);

          // open message log window
          else if (Input.pressed("logWindow"))
            {
              setState(HUDSTATE_LOG);
              windows[hudState].scrollToEnd();
            }

          // open goals window
          else if (Input.pressed("goalsWindow"))
            setState(HUDSTATE_GOALS);

#if mydebug
          // open debug window
          else if (Input.pressed("debugWindow"))
            setState(HUDSTATE_DEBUG);
#end            
        }

      return false;
    }


// handle player movement
  function handleMovement()
    {
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
      if (game.location == Game.LOCATION_AREA)
        game.playerArea.moveAction(dx, dy);

      // area mode
      else if (game.location == Game.LOCATION_REGION)
        game.region.player.moveAction(dx, dy);
    }


// handle player actions
  function handleActions()
    {
      // actions from action menu
      for (i in 1...11)
        if (Input.pressed("action" + i))
          {
            var n = i;

            // s + number = 10 + action
            if (_inputState > 0)
              n += 10;

            if (game.scene.hudState == HUDSTATE_DEFAULT)
              game.scene.hud.action(n);
            else windows[hudState].action(n);

            _inputState = 0;
            break;
          }

      if (game.scene.hudState == HUDSTATE_DEFAULT)
        {
          // test action
          if (Input.pressed("test"))
            game.scene.hud.test();

          // skip until end of turn
          if (Input.pressed("skipTurn"))
            {
              game.turn();

              // update HUD info
              game.updateHUD();
            }

          // handle mouse input
          game.scene.mouse.handleInput();
        }

      // next 10 actions
      if (Input.pressed(Key.S))
        _inputState = 1;
    }


// entity update
  public override function update()
    {
      // handle player input
      handleInput();

      // update camera position
      updateCamera();

      super.update();
    }
}

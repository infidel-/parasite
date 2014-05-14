// - has all links to windows and handles input

import com.haxepunk.Scene;
import com.haxepunk.HXP;
import com.haxepunk.graphics.atlas.TileAtlas;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;

import entities.*;

class GameScene extends Scene
{
  public var game: Game; // game state link
  public var mouse: MouseEntity; // mouse cursor entity
  public var hud: HUD; // ingame HUD
  public var hudState: String; // current HUD state (default, evolution, etc)
  public var evolutionWindow: EvolutionWindow; // evolution window
  public var inventoryWindow: InventoryWindow; // inventory window
  public var skillsWindow: SkillsWindow; // skills window
  public var organsWindow: OrgansWindow; // organs window
  public var debugWindow: DebugWindow; // debug window
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
      Input.define("inventoryWindow", [ Key.F1 ]);
      Input.define("skillsWindow", [ Key.F2 ]);
      Input.define("evolutionWindow", [ Key.F3 ]);
      Input.define("organsWindow", [ Key.F4 ]);
      Input.define("exit", [ Key.F8 ]);
      Input.define("debugWindow", [ Key.F9 ]);
//      Input.define("test", [ Key.SPACE ]);

      Input.define("skipTurn", [ Key.SPACE ]);
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
      evolutionWindow = new EvolutionWindow(game);
      inventoryWindow = new InventoryWindow(game);
      skillsWindow = new SkillsWindow(game);
      organsWindow = new OrgansWindow(game);
      debugWindow = new DebugWindow(game);

      // init game state
      game.init();
    }


// update camera position
  public function updateCamera()
    {
      var x = 0.0, y = 0.0, w = 0.0, h = 0.0;
      if (game.location == Game.LOCATION_AREA)
        {
          x = game.area.player.entity.x;
          y = game.area.player.entity.y;
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
      handleMovement();
      handleWindows();
      handleActions();
    
      if (Input.pressed("exit"))
        Sys.exit(1);
    }


// handle opening and closing windows
  function handleWindows()
    {
      // close windows
      if (Input.pressed("closeWindow"))
        {
          if (hudState == GameScene.HUDSTATE_EVOLUTION)
            evolutionWindow.hide();
          else if (hudState == GameScene.HUDSTATE_INVENTORY)
            inventoryWindow.hide();
          else if (hudState == GameScene.HUDSTATE_SKILLS)
            skillsWindow.hide();
          else if (hudState == GameScene.HUDSTATE_ORGANS)
            organsWindow.hide();
          else if (hudState == GameScene.HUDSTATE_DEBUG)
            debugWindow.hide();
          else return;

          hudState = GameScene.HUDSTATE_DEFAULT;
        }

      else if (hudState == GameScene.HUDSTATE_DEFAULT)
        {
          // open inventory window
          if (Input.pressed("inventoryWindow") && game.player.state == PLR_STATE_HOST)
            {
              hudState = GameScene.HUDSTATE_INVENTORY;
              inventoryWindow.show();
            }

          // open evolution window
          else if (Input.pressed("evolutionWindow"))
            {
              hudState = GameScene.HUDSTATE_EVOLUTION;
              evolutionWindow.show();
            }

          // open skills window
          else if (Input.pressed("skillsWindow"))
            {
              hudState = GameScene.HUDSTATE_SKILLS;
              skillsWindow.show();
            }

          // open organs window
          else if (Input.pressed("organsWindow") && game.player.state == PLR_STATE_HOST)
            {
              hudState = GameScene.HUDSTATE_ORGANS;
              organsWindow.show();
            }

          // open debug window
          else if (Input.pressed("debugWindow"))
            {
              hudState = GameScene.HUDSTATE_DEBUG;
              debugWindow.show();
            }
        }
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
        game.area.player.actionMove(dx, dy);

      // area mode
      else if (game.location == Game.LOCATION_REGION)
        game.region.player.actionMove(dx, dy);
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

            if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT)
              game.scene.hud.action(n);
            else if (game.scene.hudState == GameScene.HUDSTATE_EVOLUTION)
              game.scene.evolutionWindow.action(n);
            else if (game.scene.hudState == GameScene.HUDSTATE_ORGANS)
              game.scene.organsWindow.action(n);
            else if (game.scene.hudState == GameScene.HUDSTATE_INVENTORY)
              game.scene.inventoryWindow.action(n);
            else if (game.scene.hudState == GameScene.HUDSTATE_DEBUG)
              game.scene.debugWindow.action(n);

            _inputState = 0;
            break;
          }

      if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT)
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


  // hud state constants
  public static var HUDSTATE_DEFAULT = 'default'; // default
  public static var HUDSTATE_EVOLUTION = 'evolution'; // evolution window open
  public static var HUDSTATE_INVENTORY = 'inventory'; // inventory window open
  public static var HUDSTATE_SKILLS = 'skills'; // skills window open
  public static var HUDSTATE_ORGANS = 'organs'; // organs window open
  public static var HUDSTATE_DEBUG = 'debug'; // debug window open
}

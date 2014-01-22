// player entity

package entities;

import com.haxepunk.HXP;
import com.haxepunk.Entity;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;

class PlayerEntity extends PawnEntity
{
  var player: Player; // player link

  var dx: Int; // movement vars - movement direction
  var dy: Int;

  public function new(g: Game, xx: Int, yy: Int)
    {
      super(g, xx, yy, Const.ROW_PARASITE); 

      player = game.player;
      type = "player";

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
      Input.define("inventoryWindow", [ Key.F1 ]);
      Input.define("skillsWindow", [ Key.F2 ]);
      Input.define("evolutionWindow", [ Key.F3 ]);
      Input.define("organsWindow", [ Key.F4 ]);
      Input.define("exit", [ Key.F8 ]);
      Input.define("debugWindow", [ Key.F9 ]);
//      Input.define("test", [ Key.SPACE ]);

      Input.define("skipTurn", [ Key.SPACE ]);
      Input.define("closeWindow", [ Key.ESCAPE ]);

      dx = 0;
      dy = 0;
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
          if (game.scene.hudState == GameScene.HUDSTATE_EVOLUTION)
            game.scene.evolutionWindow.hide();
          else if (game.scene.hudState == GameScene.HUDSTATE_INVENTORY)
            game.scene.inventoryWindow.hide();
          else if (game.scene.hudState == GameScene.HUDSTATE_SKILLS)
            game.scene.skillsWindow.hide();
          else if (game.scene.hudState == GameScene.HUDSTATE_ORGANS)
            game.scene.organsWindow.hide();
          else if (game.scene.hudState == GameScene.HUDSTATE_DEBUG)
            game.scene.debugWindow.hide();
          else return;

          game.scene.hudState = GameScene.HUDSTATE_DEFAULT;
        }

      else if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT)
        {
          // open inventory window
          if (Input.pressed("inventoryWindow") && game.player.state == Player.STATE_HOST)
            {
              game.scene.hudState = GameScene.HUDSTATE_INVENTORY;
              game.scene.inventoryWindow.show();
            }

          // open evolution window
          else if (Input.pressed("evolutionWindow"))
            {
              game.scene.hudState = GameScene.HUDSTATE_EVOLUTION;
              game.scene.evolutionWindow.show();
            }

          // open skills window
          else if (Input.pressed("skillsWindow"))
            {
              game.scene.hudState = GameScene.HUDSTATE_SKILLS;
              game.scene.skillsWindow.show();
            }

          // open organs window
          else if (Input.pressed("organsWindow") && game.player.state == Player.STATE_HOST)
            {
              game.scene.hudState = GameScene.HUDSTATE_ORGANS;
              game.scene.organsWindow.show();
            }

          // open debug window
          else if (Input.pressed("debugWindow"))
            {
              game.scene.hudState = GameScene.HUDSTATE_DEBUG;
              game.scene.debugWindow.show();
            }
        }
    }


// handle player movement
  function handleMovement()
    {
      dx = 0;
      dy = 0;

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
    }


// handle player actions
  function handleActions()
    {
      // actions from action menu
      for (i in 1...10)
        if (Input.pressed("action" + i))
          {
            if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT)
              game.scene.hud.action(i);
            else if (game.scene.hudState == GameScene.HUDSTATE_EVOLUTION)
              game.scene.evolutionWindow.action(i);
            else if (game.scene.hudState == GameScene.HUDSTATE_ORGANS)
              game.scene.organsWindow.action(i);
            else if (game.scene.hudState == GameScene.HUDSTATE_DEBUG)
              game.scene.debugWindow.action(i);
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
    }


// entity update
  public override function update()
    {
      // handle player input
      handleInput();

      // emulate keyboard delay for movement
      if (dx != 0 || dy != 0)
        {
          // frob the AI
          var ai = game.area.getAI(player.x + dx, player.y + dy);
          if (ai != null)
            {
              player.frobAI(ai);
              return;
            }

          // try to move to the new location
          player.moveBy(dx, dy);
        }

      // update camera position
      game.scene.updateCamera();

      super.update();
    }


// update entity position from game state
  public inline function updatePosition()
    {
      moveTo(player.x * Const.TILE_WIDTH, player.y * Const.TILE_HEIGHT);
    }
}

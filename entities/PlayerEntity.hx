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
      Input.define("evolutionWindow", [ Key.F1 ]);
      Input.define("debugWindow", [ Key.F9 ]);
//      Input.define("test", [ Key.SPACE ]);
      Input.define("skipTurn", [ Key.SPACE ]);
      Input.define("closeWindow", [ Key.ESCAPE ]);
      Input.define("exit", [ Key.F4 ]);

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
          else if (game.scene.hudState == GameScene.HUDSTATE_DEBUG)
            game.scene.debugWindow.hide();
          else return;
          game.scene.hudState = GameScene.HUDSTATE_DEFAULT;
        }

      // open evolution window
      else if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT &&
          Input.pressed("evolutionWindow"))
        {
          game.scene.hudState = GameScene.HUDSTATE_EVOLUTION;
          game.scene.evolutionWindow.show();
        }

      // open debug window
      else if (game.scene.hudState == GameScene.HUDSTATE_DEFAULT &&
          Input.pressed("debugWindow"))
        {
          game.scene.hudState = GameScene.HUDSTATE_DEBUG;
          game.scene.debugWindow.show();
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
              game.endTurn();

              // update HUD info
              game.updateHUD();
            }

          // mouse click - cell and ai info
          if (Input.mouseReleased)
            {
              var x = Std.int(game.scene.mouseX / Const.TILE_WIDTH);
              var y = Std.int(game.scene.mouseY / Const.TILE_HEIGHT);
              trace('(' + x + ',' + y + ') ' + game.area.getType(x, y) +
                ' player vis: ' + 
                game.area.isVisible(game.player.x, game.player.y, x, y, true));
              var ai = game.area.getAI(x, y);
              if (ai != null)
                Const.debugObject(ai);
            }
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

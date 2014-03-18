package entities;

import com.haxepunk.HXP;
import com.haxepunk.Entity;
import com.haxepunk.graphics.Spritemap;
import com.haxepunk.utils.Input;
import flash.ui.Mouse;

class MouseEntity extends Entity
{
  var game: Game;

  var _map: Spritemap; // sprite map
  var _frame: Int; // current frame index
  var _mode: Int; // cursor mode - default, debug
  var _oldMode: Int;

  public function new(g: Game)
	{
      super(0, 0);

      game = g;

      _oldMode = _mode = MODE_DEFAULT;
      _frame = CURSOR_DEFAULT;
      _map = new Spritemap("gfx/mouse.png", CURSOR_WIDTH, CURSOR_HEIGHT);
      _map.centerOrigin();
      graphic = _map;
      layer = Const.LAYER_MOUSE;

      Mouse.hide(); // hide the mouse cursor

	}

/*
// set different mouse cursor
  public function set(key: String)
    {
      if (key == CURSOR_ATTACK)
        graphic = imgAttack;
      else graphic = imgDefault;
    }
*/

// update cursor
  public override function update()
	{
      super.update();

      // position unchanged, return
      if (x == scene.mouseX && y == scene.mouseY && _oldMode == _mode)
        return;

      x = scene.mouseX;
      y = scene.mouseY;

      var ax = Std.int(scene.mouseX / Const.TILE_WIDTH);
      var ay = Std.int(scene.mouseY / Const.TILE_HEIGHT);

      var newframe = _frame;
      if (_mode == MODE_DEFAULT)
        {
          var ai = game.area.getAI(ax, ay);
          if (game.player.state == Player.STATE_HOST && ai != null &&
              ai != game.player.host)
            newframe = CURSOR_ATTACK;
          else newframe = CURSOR_DEFAULT;
        }
      else newframe = CURSOR_DEBUG;

      // cursor changed, update spritemap
      if (_frame != newframe)
        {
          _map.setFrame(newframe);
          _frame = newframe;
        }
	}


// event: on wheel scroll
  function onWheel(delta: Int)
    {
      // switch mouse mode
      _oldMode = _mode;
      _mode = (_mode == MODE_DEFAULT ? MODE_DEBUG : MODE_DEFAULT);
      update();
    }


// handle mouse input
  public function handleInput()
    {
      // mouse click
      if (Input.mouseReleased)
        {
          var x = Std.int(game.scene.mouseX / Const.TILE_WIDTH);
          var y = Std.int(game.scene.mouseY / Const.TILE_HEIGHT);
          var ai = game.area.getAI(x, y);

          // debug: cell and ai info
          if (_mode == MODE_DEBUG)
            {
              trace('(' + x + ',' + y + ') ' + game.area.getType(x, y) +
                ' player vis: ' + 
                game.area.isVisible(game.player.x, game.player.y, x, y, true));
              if (game.player.x == x && game.player.y == y)
                Const.debugObject(game.player);
              if (ai != null)
                Const.debugObject(ai);
/*
              var p = game.area.getPath(game.player.x, game.player.y, x, y);
              if (p != null)
                for (n in p)
                  trace(n.x + ',' + n.y);
              else trace('no path');
*/              
            }

          // default: attack
          else if (_mode == MODE_DEFAULT)
            {
              if (game.player.state == Player.STATE_HOST && ai != null &&
                  ai != game.player.host)
                game.player.actionAttack(ai);
            }
        }

      // mouse wheel - change mouse action
      if (Input.mouseWheel)
        onWheel(Input.mouseWheelDelta);
    }


// ==========================================================================

// mouse cursor images
  public static var CURSOR_DEFAULT = 0;
  public static var CURSOR_ATTACK = 1;
  public static var CURSOR_DEBUG = 2;

// mouse cursor modes
  public static var MODE_DEFAULT = 0;
  public static var MODE_DEBUG = 1;

// size in pixels
  public static var CURSOR_WIDTH = 24;
  public static var CURSOR_HEIGHT = 24;
}
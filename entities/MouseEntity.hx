package entities;

import com.haxepunk.HXP;
import com.haxepunk.Entity;
import com.haxepunk.graphics.Image;
import flash.ui.Mouse;

class MouseEntity extends Entity
{
  var game: Game;

  var imgDefault: Image; // default cursor
  var imgAttack: Image; // attack cursor

  public function new(g: Game)
	{
      super(0, 0);

      game = g;

      imgDefault = new Image("gfx/mouse.png");
      imgDefault.centerOrigin();
      graphic = imgDefault;
      imgAttack = new Image("gfx/mouse_attack.png");
      imgAttack.centerOrigin();

      Mouse.hide(); // hide the mouse cursor

      layer = Const.LAYER_MOUSE;
	}


// set different mouse cursor
  public function set(key: String)
    {
      if (key == CURSOR_ATTACK)
        graphic = imgAttack;
      else graphic = imgDefault;
    }


// update cursor
  public override function update()
	{
      super.update();

      // position unchanged, return
      if (x == scene.mouseX && y == scene.mouseY)
        return;

      x = scene.mouseX;
      y = scene.mouseY;

      var ax = Std.int(scene.mouseX / Const.TILE_WIDTH);
      var ay = Std.int(scene.mouseY / Const.TILE_HEIGHT);

      var ai = game.area.getAI(ax, ay);
      set(ai != null ? CURSOR_ATTACK : CURSOR_DEFAULT);
	}


// ==========================================================================

  public static var CURSOR_DEFAULT = '';
  public static var CURSOR_ATTACK = 'attack';
}

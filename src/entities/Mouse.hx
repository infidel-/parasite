// openfl mouse cursor

package entities;

import com.haxepunk.HXP;
import openfl.Assets;
import openfl.display.Sprite;
import openfl.display.Bitmap;
import openfl.geom.Rectangle;
import openfl.events.MouseEvent;
import com.haxepunk.utils.Input;
import com.haxepunk.utils.Key;

import game.Game;

class Mouse extends Sprite
{
  var game: Game;
  var rect: Rectangle;
  var cursor: Int;
  var sceneState: _UIState;
  var oldx: Float;
  var oldy: Float;

  public function new(g: Game)
    {
      super();
      game = g;
      cursor = 0;
      oldx = 0;
      oldy = 0;
      sceneState = game.scene.state;

      var b = new Bitmap(Assets.getBitmapData('gfx/mouse.png'));
      rect = new Rectangle(0, 0, CURSOR_WIDTH, CURSOR_HEIGHT);
      b.scrollRect = rect;
      addChild(b);
      mouseEnabled = false;

#if mydebug
      HXP.stage.addEventListener(MouseEvent.CLICK, onClick);
#end

      b.x = 0;
      b.y = 0;
    }


// click in debug mode
#if mydebug
  function onClick(e: Dynamic)
    {
      // not in debug mode
      if (cursor != CURSOR_DEBUG || game.location != LOCATION_AREA)
        return;

      var pos = getXY();
      var ai = game.area.getAI(pos.x, pos.y);
      trace('(' + pos.x + ',' + pos.y + ') ' +
        game.area.getCellType(pos.x, pos.y) + ' ' +
        game.area.getCellTypeString(pos.x, pos.y) +
        ' player vis: ' +
        game.area.isVisible(game.playerArea.x,
          game.playerArea.y, pos.x, pos.y, true));
      if (game.playerArea.x == pos.x && game.playerArea.y == pos.y)
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
#end


// update mouse cursor
  public function update()
    {
#if mydebug
      // control key pressed, change to debug cursor
      if (game.scene.state == UISTATE_DEFAULT)
        {
          if (Input.pressed(Key.CONTROL) && cursor != CURSOR_DEBUG)
            setCursor(CURSOR_DEBUG);

          // ctrl released, mark as changed
          else if (Input.released(Key.CONTROL) && cursor == CURSOR_DEBUG)
            oldx = -1;
        }
#end

      // position and state unchanged, return
      if (oldx == HXP.stage.mouseX &&
          oldy == HXP.stage.mouseY &&
          sceneState == game.scene.state)
        return;

      x = HXP.stage.mouseX - CURSOR_WIDTH / 2;
      y = HXP.stage.mouseY - CURSOR_HEIGHT / 2;
      oldx = HXP.stage.mouseX;
      oldy = HXP.stage.mouseY;

      // window open, reset state
      if (game.scene.state != UISTATE_DEFAULT)
        {
          setCursor(CURSOR_DEFAULT);
          sceneState = game.scene.state;

          return;
        }

#if mydebug
      // control key held, do not change cursor
      if (Input.check(Key.CONTROL))
        return;
#end

      // in area
      if (game.location == LOCATION_AREA)
        updateArea();

      sceneState = game.scene.state;
    }


// get tile x,y that mouse cursor is on
  public inline function getXY(): { x: Int, y: Int }
    {
      return {
        x: Std.int(game.scene.mouseX / Const.TILE_WIDTH),
        y: Std.int(game.scene.mouseY / Const.TILE_HEIGHT)
        };
    }


// area mode
  function updateArea()
    {
      var c = CURSOR_DEFAULT;

      // attack cursor
      var pos = getXY();
      var ai = game.area.getAI(pos.x, pos.y);
      if (game.player.state == PLR_STATE_HOST && ai != null &&
          ai != game.player.host &&
          game.area.isVisible(game.playerArea.x, game.playerArea.y,
            pos.x, pos.y))
        c = CURSOR_ATTACK;

      // mouse click in attack mode on target
      if (Input.mouseReleased && c == CURSOR_ATTACK)
        {
          game.playerArea.attackAction(ai);
        }

      setCursor(c);
    }


// set new cursor image
  function setCursor(c: Int)
    {
      if (cursor == c)
        return;

      cursor = c;
      rect.x = cursor * CURSOR_WIDTH;
    }


// mouse cursor images
  public static var CURSOR_DEFAULT = 0;
  public static var CURSOR_ATTACK = 1;
  public static var CURSOR_DEBUG = 2;

// size in pixels
  public static var CURSOR_WIDTH = 24;
  public static var CURSOR_HEIGHT = 24;
}

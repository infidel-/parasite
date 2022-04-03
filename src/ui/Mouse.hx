// mouse cursor

package ui;

import h2d.Anim;
import h2d.Bitmap;
import h2d.Tile;
import hxd.BitmapData;
import hxd.Key;
import hxd.Cursor;
import game.Game;
import ai.AI;

class Mouse
{
  var game: Game;
  var cursor: Int;
  var sceneState: _UIState;
  var oldx: Float;
  var oldy: Float;
  public var atlas: Array<Cursor>;
  public var forceNextUpdate: Int; // kludge for update
  public var ignoreNextClick: Bool; // kludge for regaining focus and hud buttons
  var oldPos: { x: Int, y: Int };

  public function new(g: Game)
    {
      game = g;
      cursor = -1;
      oldx = 0;
      oldy = 0;
      oldPos = { x: -1, y: -1 };
      sceneState = game.ui.state;
      forceNextUpdate = 0;
      ignoreNextClick = false;
      atlas = null;

      // config - mouse disabled
      if (!game.config.mouseEnabled)
        return;

      var res = hxd.Res.load('graphics/mouse64.png').toImage();
      var bmp = res.toBitmap();
      atlas = [];
      var size = (game.config.mapScale == 1 ? CURSOR_SIZE :
        Std.int(CURSOR_SIZE * game.config.mapScale));
      for (i in 0...CURSOR_ATTACK_RANGED + 1)
        {
          var tmp = bmp.sub(i * CURSOR_SIZE, 0, CURSOR_SIZE, CURSOR_SIZE);
          var cursor = Custom(new CustomCursor([ tmp ], 1,
            i == 0 ? 0 : Std.int(CURSOR_SIZE / 2),
            i == 0 ? 0 : Std.int(CURSOR_SIZE / 2)));
          atlas.push(cursor);
        }
      hxd.System.setCursor = function(cur)
        {
          if (cur == Default)
            hxd.System.setNativeCursor(atlas[cursor]);
          else hxd.System.setNativeCursor(cur);
        }
    }


// mouse click
  public function onClick(button: Int)
    {
      // config - mouse disabled
      if (!game.config.mouseEnabled)
        return;

      // skip next click once
      if (ignoreNextClick)
        {
          ignoreNextClick = false;
          return;
        }

      var pos = getXY();
      if (pos.x < 0 || pos.y < 0 ||
          pos.x >= game.area.width || pos.y >= game.area.height)
        return;
#if mydebug
      // debug mode
      if (button == Key.MOUSE_MIDDLE)
        {
          if (game.location == LOCATION_AREA)
            onClickDebug(pos);
          return;
        }
#end
      // some window open
      if (game.isFinished || game.ui.state != UISTATE_DEFAULT)
        return;

      // area mode - click moves or attacks
      if (game.location == LOCATION_AREA)
        onClickArea(pos);

      // region mode
      else if (game.location == LOCATION_REGION)
        onClickRegion(pos);
    }


// DEBUG: on click
#if mydebug
  function onClickDebug(pos)
    {
      var ai = game.area.getAI(pos.x, pos.y);
      trace('(' + pos.x + ',' + pos.y + ') ' +
        game.area.getCellType(pos.x, pos.y) + ' ' +
        game.area.getCellTypeString(pos.x, pos.y) +
        ' player vis: ' +
        game.area.isVisible(game.playerArea.x,
          game.playerArea.y, pos.x, pos.y, true) +
        ' walk: ' + game.area.isWalkable(pos.x, pos.y));
      if (game.playerArea.x == pos.x && game.playerArea.y == pos.y)
        Const.debugObject(game.player);
      if (ai != null)
        Const.debugObject(ai);
    }
#end


// on click in area mode
  function onClickArea(pos)
    {
      // attack AI or move
      var ai = game.area.getAI(pos.x, pos.y);
      var isVisible = game.scene.area.isVisible(pos.x, pos.y);
      if (isVisible)
        {
          // try to attack
          if (canAttack(ai))
            {
              game.playerArea.attackAction(ai);
              return;
            }

          // generate a path
          else if (game.area.isWalkable(pos.x, pos.y))
            game.playerArea.setPath(pos.x, pos.y);
        }
    }


// on click in region mode
  function onClickRegion(pos)
    {
      var pos = getXY();
      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        return;
      if (!game.scene.region.isKnown(area))
        return;

      // generate a path
      game.playerRegion.setTarget(pos.x, pos.y);
    }


// update mouse cursor
  public function update(?force = false)
    {
      // config - mouse disabled
      if (!game.config.mouseEnabled)
        return;

      if (forceNextUpdate > 0)
        force = true;

      // position and state unchanged, return
      if (!force)
        {
          if (oldx == game.scene.mouseX &&
              oldy == game.scene.mouseY &&
              sceneState == game.ui.state)
            return;
        }
      if (force)
        cursor = - 1;

      oldx = game.scene.mouseX;
      oldy = game.scene.mouseY;

      // window open, reset state
      if (game.isFinished || game.ui.state != UISTATE_DEFAULT)
        {
          setCursor(CURSOR_ARROW);
          sceneState = game.ui.state;
          if (forceNextUpdate > 0)
            forceNextUpdate--;

          return;
        }

      // in area
      if (game.location == LOCATION_AREA)
        updateArea(force);

      // in region
      else if (game.location == LOCATION_REGION)
        updateRegion(force);

      sceneState = game.ui.state;
      if (forceNextUpdate > 0)
        forceNextUpdate--;
    }


// get tile x,y that mouse cursor is on
  public inline function getXY(): { x: Int, y: Int }
    {
      return {
        x: Math.floor((game.scene.cameraX + game.scene.mouseX) / Const.TILE_SIZE),
        y: Math.floor((game.scene.cameraY + game.scene.mouseY) / Const.TILE_SIZE)
      };
    }


// area mode
  function updateArea(force: Bool)
    {
      var c = CURSOR_BLOCKED;
      var pos = getXY();
      if (pos.x < 0 || pos.y < 0 ||
          pos.x >= game.area.width || pos.y >= game.area.height)
        {
          oldPos = pos;
          game.scene.area.clearPath();
          setCursor(c);
          return;
        }
      var posChanged = false;
      if (oldPos.x != pos.x || oldPos.y != pos.y || force)
        {
          oldPos = pos;
          posChanged = true;
        }
      var isVisible = game.scene.area.isVisible(pos.x, pos.y);
      var ai = game.area.getAI(pos.x, pos.y);
      if (isVisible)
        {
          // attack cursor
          if (canAttack(ai))
            {
              var weapon = game.playerArea.getWeapon();
              c = (weapon.isRanged ? CURSOR_ATTACK_RANGED : CURSOR_ATTACK);
              if (!weapon.isRanged &&
                  !ai.isNear(game.playerArea.x, game.playerArea.y))
                c = CURSOR_BLOCKED;
              game.scene.area.clearPath();
            }

          // move cursor and path
          else if (game.area.isWalkable(pos.x, pos.y))
            {
              c = CURSOR_MOVE;

              // check if tile position changed
              if (posChanged)
                game.scene.area.updatePath(
                  game.playerArea.x, game.playerArea.y,
                  pos.x, pos.y);
            }

          // clear path
          else game.scene.area.clearPath();
        }

      // clear path
      else game.scene.area.clearPath();

      setCursor(c);
    }


// region mode
  function updateRegion(force: Bool)
    {
      // check if tile position changed
      var pos = getXY();
      if (oldPos.x == pos.x && oldPos.y == pos.y && !force)
        return;

      var c = CURSOR_BLOCKED;

      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        {
          setCursor(c);
          return;
        }
      var isKnown = game.scene.region.isKnown(area);
      if (isKnown)
        {
          game.scene.region.updatePath(
            game.playerRegion.x, game.playerRegion.y,
            pos.x, pos.y);
          c = CURSOR_MOVE;
        }

      setCursor(c);
    }


// check if player can attack that AI
  inline function canAttack(ai: AI)
    {
      return (game.player.state == PLR_STATE_HOST && ai != null &&
        ai != game.player.host);
    }


// set new cursor image
  public function setCursor(c: Int)
    {
      // config - mouse disabled
      if (!game.config.mouseEnabled)
        return;

      if (cursor == c)
        return;

      cursor = c;
      hxd.System.setCursor(atlas[cursor]);
    }


// mouse cursor images
  public static var CURSOR_ARROW = 0;
  public static var CURSOR_MOVE = 1;
  public static var CURSOR_BLOCKED = 2;
  public static var CURSOR_ATTACK = 3;
  public static var CURSOR_ATTACK_RANGED = 4;

// size in pixels
  public static var CURSOR_SIZE = 32;
}

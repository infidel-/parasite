// mouse cursor

package ui;

import h2d.Anim;
import h2d.Bitmap;
import h2d.Tile;
import hxd.Key;
import game.Game;
import ai.AI;

class Mouse
{
  var game: Game;
  var cursor: Int;
  var sceneState: _UIState;
  var oldx: Float;
  var oldy: Float;
  var atlas: Array<Tile>;
  var _body: Anim;
  var oldPos: { x: Int, y: Int };

  public function new(g: Game)
    {
      game = g;
      cursor = -1;
      oldx = 0;
      oldy = 0;
      oldPos = { x: -1, y: -1 };
      sceneState = game.scene.state;

      hxd.System.setNativeCursor(Hide);
      var res = hxd.Res.load('graphics/mouse64.png').toTile();
      atlas = res.gridFlatten(CURSOR_SIZE);
//      atlas[0] = atlas[0].sub(0, 0, atlas[0].width, atlas[0]);
      for (i in 1...atlas.length)
        atlas[i] = atlas[i].center();

      _body = new Anim(atlas, 15);
      _body.pause = true;
      _body.visible = true;
      game.scene.add(_body, Const.LAYER_MOUSE);
    }


// mouse click
  public function onClick(button: Int)
    {
      var pos = getXY();
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
      if (game.scene.state != UISTATE_DEFAULT)
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
      // position and state unchanged, return
      if (!force)
        {
          if (oldx == game.scene.mouseX &&
              oldy == game.scene.mouseY &&
              sceneState == game.scene.state)
            return;
        }

      _body.x = game.scene.mouseX;
      _body.y = game.scene.mouseY;
      oldx = game.scene.mouseX;
      oldy = game.scene.mouseY;

      // window open, reset state
      if (game.scene.state != UISTATE_DEFAULT)
        {
          setCursor(CURSOR_ARROW);
          sceneState = game.scene.state;

          return;
        }

      // in area
      if (game.location == LOCATION_AREA)
        updateArea();

      // in region
      else if (game.location == LOCATION_REGION)
        updateRegion();

      sceneState = game.scene.state;
    }


// get tile x,y that mouse cursor is on
  public inline function getXY(): { x: Int, y: Int }
    {
      return {
        x: Std.int((game.scene.cameraX + game.scene.mouseX) / Const.TILE_WIDTH),
        y: Std.int((game.scene.cameraY + game.scene.mouseY) / Const.TILE_HEIGHT)
        };
    }


// area mode
  function updateArea()
    {
      var c = CURSOR_BLOCKED;

      var pos = getXY();
      var posChanged = false;
      if (oldPos.x != pos.x || oldPos.y != pos.y)
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
  function updateRegion()
    {
      // check if tile position changed
      var pos = getXY();
      if (oldPos.x == pos.x && oldPos.y == pos.y)
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
  function setCursor(c: Int)
    {
      if (cursor == c)
        return;

      cursor = c;
      _body.currentFrame = cursor;
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

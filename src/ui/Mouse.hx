// openfl mouse cursor

package ui;

import h2d.Bitmap;
import h2d.Tile;
import hxd.Key;
import game.Game;
import ai.AI;

class Mouse
{
  var _body: Bitmap;
  var game: Game;
  var cursor: Int;
  var sceneState: _UIState;
  var oldx: Float;
  var oldy: Float;
  var atlas: Array<Array<Tile>>;
  var cursors: Array<Bitmap>;

  public function new(g: Game)
    {
      game = g;
      cursor = -1;
      oldx = 0;
      oldy = 0;
      sceneState = game.scene.state;

      hxd.System.setNativeCursor(Hide);
      var res = hxd.Res.load('graphics/mouse.png').toTile();
      atlas = res.grid(CURSOR_SIZE);
      cursors = [];
      for (i in 0...atlas.length)
        {
          cursors[i] = new Bitmap(atlas[i][0]);
          cursors[i].tile = cursors[i].tile.center();
          cursors[i].visible = false;
          game.scene.add(cursors[i], Const.LAYER_MOUSE);
        }

      _body = null;
      setCursor(CURSOR_DEFAULT);
    }


// mouse click
  public function onClick()
    {
      var pos = getXY();
#if mydebug
      // debug mode
      if (cursor == CURSOR_DEBUG)
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
          game.playerArea.y, pos.x, pos.y, true));
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
  public function update()
    {
#if mydebug
//      trace(Key.isPressed(Key.CTRL) + ' ' +  cursor);
      // control key pressed, change to debug cursor
      if (game.scene.state == UISTATE_DEFAULT)
        {
          if (Key.isPressed(Key.CTRL) && cursor != CURSOR_DEBUG)
            setCursor(CURSOR_DEBUG);

          // ctrl released, mark as changed
          else if (!Key.isPressed(Key.CTRL) && cursor == CURSOR_DEBUG)
            oldx = -1;
        }
#end

      // position and state unchanged, return
      if (oldx == game.scene.mouseX &&
          oldy == game.scene.mouseY &&
          sceneState == game.scene.state)
        return;

      _body.x = game.scene.mouseX;
      _body.y = game.scene.mouseY;
      oldx = game.scene.mouseX;
      oldy = game.scene.mouseY;

      // window open, reset state
      if (game.scene.state != UISTATE_DEFAULT)
        {
          setCursor(CURSOR_DEFAULT);
          sceneState = game.scene.state;

          return;
        }

#if mydebug
      // control key held, do not change cursor
      if (Key.isPressed(Key.CTRL))
        return;
#end

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

      // attack cursor
      var pos = getXY();
      var isVisible = game.scene.area.isVisible(pos.x, pos.y);
      var ai = game.area.getAI(pos.x, pos.y);
      if (isVisible)
        {
          if (canAttack(ai))
            c = CURSOR_ATTACK;

          else if (game.area.isWalkable(pos.x, pos.y))
            c = CURSOR_DEFAULT;
        }

      setCursor(c);
    }


// region mode
  function updateRegion()
    {
      var c = CURSOR_BLOCKED;

      var pos = getXY();
      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        {
          setCursor(c);
          return;
        }
      var isKnown = game.scene.region.isKnown(area);
      if (isKnown)
        c = CURSOR_DEFAULT;

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
      if (_body != null)
        _body.visible = false;

      _body = cursors[c];
      _body.x = game.scene.mouseX;
      _body.y = game.scene.mouseY;
      _body.visible = true;
    }


// mouse cursor images
  public static var CURSOR_DEFAULT = 0;
  public static var CURSOR_ATTACK = 1;
  public static var CURSOR_DEBUG = 2;
  public static var CURSOR_BLOCKED = 3;

// size in pixels
  public static var CURSOR_SIZE = 24;
}

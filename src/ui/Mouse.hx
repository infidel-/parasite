// mouse cursor

package ui;

import game.Game;
import ai.AI;
import js.Browser;
import js.html.MouseEvent;
import objects.AreaObject;
import objects.base.RivalBaseOrganObject;

class Mouse
{
  var game: Game;
  var cursor: Int;
  var sceneState: _UIState;
  var oldx: Float;
  var oldy: Float;
  public var forceNextUpdate: Int; // kludge for update
  var oldPos: { x: Int, y: Int };
  var oldPlayerX: Int; // last player cell the cursor/path was resolved against (3D view: camera + player
  var oldPlayerY: Int; // move under a still cursor, so a stale-check on mouse px alone would freeze it)
  var playerMoved: Bool; // did the player cell change since the last update? (3D view: re-path so it shortens)
  var kbMoved: Bool; // player moved by keyboard: hover path stays hidden until the mouse really moves
  var wasFrozen: Bool; // was the hover path frozen last update? (re-path once the walk fully ends)

  public function new(g: Game)
    {
      game = g;
      cursor = -1;
      oldx = 0;
      oldy = 0;
      oldPos = { x: -1, y: -1 };
      oldPlayerX = -1;
      oldPlayerY = -1;
      kbMoved = false;
      wasFrozen = false;
      sceneState = game.ui.state;
      forceNextUpdate = 0;
    }

// a real mousemove event (as opposed to the per-frame re-pick the 3D view does under a still
// cursor): the cursor genuinely moved, so a path preview hidden by a keyboard move comes back
  public function onMove()
    {
      // force when a keyboard move had hidden the preview: update()'s stale-check would otherwise
      // early-return for a cursor that stayed inside the same tile and leave it hidden
      var wasKb = kbMoved;
      kbMoved = false;
      update(wasKb);
    }

// the player moved with the keyboard: hide the hover path preview until the mouse really moves
// again, instead of re-pathing it from the new cell every step under a still cursor
  public function onKeyboardMove()
    {
      kbMoved = true;
      game.scene.area.clearPath();
    }

// is the hover path preview frozen? true while the player walks a clicked path, and on through the
// last step's slide animation so it only clears once the actor has visibly landed on the final cell
  inline function pathFrozen(): Bool
    {
      return (game.playerArea != null &&
        (game.playerArea.path != null ||
         (street() && !game.scene.view3d.playerSettled())));
    }

// is the 3D street view currently showing? cursor picking / path / cursor art route through it then
  inline function street(): Bool
    {
      return (game.scene.view3d != null &&
        game.scene.view3d.running);
    }

// LOS test that works in both views: the 2D tile cache (area.isVisible) is only maintained while the
// 2D view draws, so in the 3D view fall back to the player's own vision (the source
// render.Actors.pickTarget uses for its AI arm)
  inline function seesTile(x: Int, y: Int): Bool
    {
      if (street())
        return (!game.player.vars.losEnabled ||
          game.playerArea.sees(x, y));
      return game.scene.area.isVisible(x, y);
    }

// mouse click (through canvas directly)
  public function onClick(e: MouseEvent)
    {
      // config - mouse disabled
      if (!game.config.mouseEnabled)
        return;

      var pos = getXY();
      if (pos.x < 0 ||
          pos.y < 0 ||
          (game.location == LOCATION_AREA &&
           (pos.x >= game.area.width ||
            pos.y >= game.area.height)) ||
          (game.location == LOCATION_REGION &&
           (pos.x >= game.region.width ||
            pos.y >= game.region.height)))
        return;
      if (game.ui.hud.state == HUD_TARGETING)
        {
          game.ui.hud.targeting.selectByMouse(pos.x, pos.y);
          return;
        }
      if (game.location == LOCATION_AREA &&
          game.ui.hud.state == HUD_BASE_BUILDING)
        {
          onClickBase(pos);
          return;
        }
      // debug mode (middle mouse button) — only honored when debug sentinel active
      if (Const.isDebug && e.button == 1)
        {
          if (game.location == LOCATION_AREA)
            onClickDebug(pos);
          return;
        }
      // some window open
      if (game.isInputLocked() ||
          game.ui.state != UISTATE_DEFAULT)
        return;

      // area mode - click moves or attacks
      if (game.location == LOCATION_AREA)
        onClickArea(pos);

      // region mode
      else if (game.location == LOCATION_REGION)
        onClickRegion(pos);
    }


// DEBUG: on click — only invoked when Const.isDebug
  function onClickDebug(pos: _Point)
    {
      trace('(' + pos.x + ',' + pos.y + ') ' +
        game.area.getCellType(pos.x, pos.y) + ' ' +
        game.area.getCellTypeString(pos.x, pos.y) +
        ' player vis: ' +
        game.area.isVisible(game.playerArea.x,
          game.playerArea.y, pos.x, pos.y, true) +
        ' walk: ' + game.area.isWalkable(pos.x, pos.y));
      if (game.scene.areaLighting != null)
        {
          for (line in AreaLightingDebug.getTileLightDebugLines(
              game.scene.areaLighting,
              game.area, pos.x, pos.y))
            trace(line);
          for (line in AreaLightingDebug.getTileDynamicShadowDebugLines(
              game.scene.areaLighting,
              game.area, pos.x, pos.y))
            trace(line);
        }
    }


// on click in area mode
  function onClickArea(pos)
    {
      if (game.ui.cannotMove())
        return;
      // attack AI or move
      var ai = game.area.getAI(pos.x, pos.y);
      var obj = getAttackableObject(pos.x, pos.y);
      var isVisible = seesTile(pos.x, pos.y);
      if (isVisible)
        {
          // try to attack
          if (canAttack(ai))
            {
              game.playerArea.attackAction(ai);
              return;
            }
          if (canAttackObject(obj))
            {
              game.playerArea.attackObjectAction(obj);
              return;
            }

          // generate a path
          else if (game.area.isWalkable(pos.x, pos.y))
            game.playerArea.setPath(pos.x, pos.y);
        }
    }

// on click in forma mode
  function onClickBase(pos)
    {
      if (game.location != LOCATION_AREA ||
          game.cults.length == 0 ||
          game.cults[0].base == null)
        return;
      game.cults[0].base.setCursor(pos.x, pos.y);
    }


// on click in region mode
  function onClickRegion(pos)
    {
      var pos = getXY();
      var area = game.region.getXY(pos.x, pos.y);
      if (area == null)
        return;
      if (pos.x == game.playerRegion.x &&
          pos.y == game.playerRegion.y)
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
        {
          // route through setCursorCSS: in the 3D view #view covers #canvas, so writing the
          // hide to #canvas alone left the cursor visible. -1 so re-enabling re-applies the art
          setCursorCSS('none');
          cursor = -1;
          game.scene.area.clearPath();
          return;
        }

      if (forceNextUpdate > 0)
        force = true;

      // the hover path is frozen while the player walks a clicked path; when that releases, force
      // one update so it re-paths even though the cursor never moved
      var frozen = pathFrozen();
      if (wasFrozen && !frozen)
        force = true;
      wasFrozen = frozen;

      // position and state unchanged, return
      if (!force)
        {
          // 3D view: the camera + player move under a still cursor, so a raw mouse-px check would
          // freeze the hover — re-pick the ground cell and also gate on the player cell (the path
          // re-shortens as the player advances). ui.Mouse is ticked every frame in that view
          if (street() &&
              game.playerArea != null)
            {
              var pos = getXY();
              if (pos.x == oldPos.x &&
                  pos.y == oldPos.y &&
                  oldPlayerX == game.playerArea.x &&
                  oldPlayerY == game.playerArea.y &&
                  sceneState == game.ui.state)
                return;
            }
          else if (oldx == game.scene.mouseX &&
              oldy == game.scene.mouseY &&
              sceneState == game.ui.state)
            return;
        }
      if (force)
        cursor = - 1;

      oldx = game.scene.mouseX;
      oldy = game.scene.mouseY;
      // track the player cell for the 3D re-path (area mode only; playerArea is null in region/menu)
      if (game.playerArea != null)
        {
          playerMoved = (oldPlayerX != game.playerArea.x ||
            oldPlayerY != game.playerArea.y);
          oldPlayerX = game.playerArea.x;
          oldPlayerY = game.playerArea.y;
        }

      // window open, reset state
      if (game.isInputLocked() ||
          game.ui.state != UISTATE_DEFAULT)
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
      // 3D view: unproject the cursor onto the ground plane (mouseX/Y is device px, pickCell wants
      // CSS client px, so divide out the dpr)
      if (street())
        {
          var dpr = Browser.window.devicePixelRatio;
          return game.scene.view3d.pickCell(game.scene.mouseX / dpr, game.scene.mouseY / dpr);
        }
      return {
        x: Math.floor((game.scene.cameraX + game.scene.mouseX) / Const.TILE_SIZE),
        y: Math.floor((game.scene.cameraY + game.scene.mouseY) / Const.TILE_SIZE)
      };
    }


// area mode
  function updateArea(force: Bool)
    {
      // targeting mode - cursor locked
      var pos = getXY();
      if (game.ui.hud.state == HUD_TARGETING)
        {
          game.scene.area.clearPath();
          if (pos.x >= 0 &&
              pos.y >= 0 &&
              pos.x < game.area.width &&
              pos.y < game.area.height)
            game.ui.hud.targeting.hoverByMouse(pos.x, pos.y);
          setCursor(CURSOR_MOVE);
          return;
        }

      // forma mode, no path
      if (game.ui.hud.state == HUD_BASE_BUILDING)
        {
          game.scene.area.clearPath();
          if (pos.x < 0 ||
              pos.y < 0 ||
              pos.x >= game.area.width ||
              pos.y >= game.area.height ||
              game.cults.length == 0 ||
              game.cults[0].base == null ||
              !game.cults[0].base.canUseCursorTile(pos.x, pos.y))
            setCursor(CURSOR_BLOCKED);
          else setCursor(CURSOR_MOVE);
          return;
        }

      // the player is walking a clicked path: freeze the preview exactly as it was drawn — no
      // re-path, no clear — until the walk ends AND its last step has landed, when update() forces
      // one update and the preview re-paths from the new position
      if (pathFrozen())
        return;

      // out of bounds check
      var c = CURSOR_BLOCKED;
      if (pos.x < 0 || pos.y < 0 ||
          pos.x >= game.area.width || pos.y >= game.area.height)
        {
          oldPos = pos;
          game.scene.area.clearPath();
          if (isInspectMode())
            c = CURSOR_INFO;
          setCursor(c);
          return;
        }

      // check if tile position changed
      var posChanged = false;
      if (oldPos.x != pos.x || oldPos.y != pos.y || force)
        {
          oldPos = pos;
          posChanged = true;
        }
      var isVisible = seesTile(pos.x, pos.y);
      var ai = game.area.getAI(pos.x, pos.y);
      var obj = getAttackableObject(pos.x, pos.y);
      if (isVisible)
        {
          // attack cursor
          if (canAttack(ai))
            {
              var weapon = game.playerArea.getCurrentWeapon();
              c = (weapon.isRanged ? CURSOR_ATTACK_RANGED : CURSOR_ATTACK);
              if (!weapon.isRanged &&
                  !ai.isNear(game.playerArea.x, game.playerArea.y))
                c = CURSOR_BLOCKED;
              game.scene.area.clearPath();
            }
          else if (canAttackObject(obj))
            {
              var weapon = game.playerArea.getCurrentWeapon();
              c = (weapon.isRanged ? CURSOR_ATTACK_RANGED : CURSOR_ATTACK);
              if (!weapon.isRanged &&
                  !isNearObject(obj))
                c = CURSOR_BLOCKED;
              game.scene.area.clearPath();
            }

          // move cursor and path
          else if (game.area.isWalkable(pos.x, pos.y))
            {
              c = CURSOR_MOVE;

              // no preview after a keyboard move: it would re-path from the new cell every step
              // under a still cursor. it comes back on the next real mouse move
              if (kbMoved)
                game.scene.area.clearPath();

              // rebuild the path when the hovered tile changed, or (3D view) when the player advanced
              // along it so the preview re-shortens to the remaining route
              else if (posChanged ||
                  (street() && playerMoved))
                game.scene.area.updatePath(
                  game.playerArea.x, game.playerArea.y,
                  pos.x, pos.y);
            }

          // clear path
          else game.scene.area.clearPath();
        }

      // clear path
      else game.scene.area.clearPath();

      // info cursor
      if (isInspectMode())
        c = CURSOR_INFO;

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
      if (c == CURSOR_BLOCKED &&
          game.playerRegion.target == null)
        game.scene.clearPath();

      setCursor(c);
    }


// check if player can attack that AI
  inline function canAttack(ai: AI)
    {
      return (game.player.state == PLR_STATE_HOST &&
        ai != null && ai != game.player.host);
    }

// returns attackable object at the tile
  function getAttackableObject(x: Int, y: Int): AreaObject
    {
      for (o in game.area.getObjectsAt(x, y))
        if (o.isAttackableByFriend())
          return o;
      return null;
    }

// check if player can attack that object
  inline function canAttackObject(obj: AreaObject)
    {
      return (game.player.state == PLR_STATE_HOST &&
        obj != null &&
        obj.isAttackableByFriend());
    }

// checks whether player is near object tile
  inline function isNearObject(obj: AreaObject)
    {
      if (Math.abs(obj.x - game.playerArea.x) <= 1 &&
          Math.abs(obj.y - game.playerArea.y) <= 1)
        return true;
      if (Std.isOfType(obj, RivalBaseOrganObject))
        {
          var rivalObj: RivalBaseOrganObject = cast obj;
          return rivalObj.getAttackPartNear(
            game.playerArea.x, game.playerArea.y) != null;
        }
      return false;
    }

// returns true if area inspect mode is active
  inline function isInspectMode(): Bool
    {
      return (
        game.location == LOCATION_AREA &&
        game.ui.state == UISTATE_DEFAULT &&
        game.ui.hud.state == HUD_DEFAULT &&
        !game.isInputLocked() &&
        game.scene.controlPressed
      );
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
      setCursorCSS(cursorCSS(c));
    }

// the CSS cursor value for a cursor id — the themed SVG cursors (the --ui-cursor* vars in app.css),
// shared by every view (2D area, region, 3D street). mods retheme them by overriding the vars in
// their mod.css
  function cursorCSS(c: Int): String
    {
      if (c == CURSOR_MOVE)
        return 'var(--ui-cursor)';
      if (c == CURSOR_BLOCKED)
        return 'var(--ui-cursor-disabled)';
      if (c == CURSOR_ATTACK)
        return 'var(--ui-cursor-attack)';
      if (c == CURSOR_ATTACK_RANGED)
        return 'var(--ui-cursor-attack-ranged)';
      if (c == CURSOR_INFO)
        return 'var(--ui-cursor-help)';
      return 'var(--ui-cursor-default)';
    }

// write the cursor CSS to the active view's canvas: #view in the 3D view (it covers #canvas),
// else the 2D #canvas
  inline function setCursorCSS(css: String)
    {
      if (street())
        game.scene.view3d.setCursorCSS(css);
      else game.ui.canvas.style.cursor = css;
    }

// mouse cursor images
  public static var CURSOR_ARROW = 0;
  public static var CURSOR_MOVE = 1;
  public static var CURSOR_BLOCKED = 2;
  public static var CURSOR_ATTACK = 3;
  public static var CURSOR_ATTACK_RANGED = 4;
  public static var CURSOR_INFO = 5;

// size in pixels
  public static var CURSOR_SIZE = 32;
}

// targeting helper
package ui;

import ai.AI;
import game.Game;
import ui.HUD;

class Targeting
{
  var game: Game;
  var hud: HUD;
  var list: Array<AI>;
  var index: Int;
  public var target: AI;
  public var targetingAI: AI;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      list = [];
      index = -1;
      target = null;
      targetingAI = null;
    }

// enter targeting mode
  public function enter(): Bool
    {
      if (game.location != LOCATION_AREA ||
          game.player.state != PLR_STATE_HOST)
        return false;
      list = buildList();
      if (list.length == 0)
        {
          game.actionFailed('No visible targets.');
          return false;
        }
      index = 0;
      targetingAI = list[0];
      if (target != null)
        {
          var i = 0;
          for (ai in list)
            {
              if (ai == target)
                {
                  index = i;
                  targetingAI = ai;
                  break;
                }
              i++;
            }
        }
      hud.state = HUD_TARGETING;
      game.updateHUD();
      if (game.location == LOCATION_AREA)
        {
          game.scene.mouse.update(true);
          game.scene.area.draw();
        }
      return true;
    }

// exit targeting mode
  public function exit(?updateUI: Bool = true)
    {
      hud.state = HUD_DEFAULT;
      list = [];
      index = -1;
      targetingAI = null;
      if (updateUI)
        {
          game.scene.mouse.update(true);
          game.updateHUD();
          if (game.location == LOCATION_AREA)
            game.scene.area.draw();
        }
    }

// rotate current targeting selection
  public function rotate(dir: Int)
    {
      if (hud.state != HUD_TARGETING ||
          list.length == 0)
        return;
      if (dir < 0)
        {
          index--;
          if (index < 0)
            index = list.length - 1;
        }
      else if (dir > 0)
        {
          index++;
          if (index >= list.length)
            index = 0;
        }
      targetingAI = list[index];
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
    }

// confirm target and exit targeting
  public function confirm()
    {
      if (hud.state != HUD_TARGETING)
        return;
      if (targetingAI != null)
        target = targetingAI;
      exit();
    }

// select target by mouse click and exit targeting
  public function selectByMouse(x: Int, y: Int): Bool
    {
      if (hud.state != HUD_TARGETING ||
          game.location != LOCATION_AREA ||
          list.length == 0)
        return false;

      var ai = game.area.getAI(x, y);
      if (ai == null)
        return false;

      var i = 0;
      for (entry in list)
        {
          if (entry == ai)
            {
              index = i;
              targetingAI = ai;
              target = ai;
              exit();
              return true;
            }
          i++;
        }
      return false;
    }

// update targeting ai from mouse hover
  public function hoverByMouse(x: Int, y: Int): Bool
    {
      if (hud.state != HUD_TARGETING ||
          game.location != LOCATION_AREA ||
          list.length == 0)
        return false;

      var ai = game.area.getAI(x, y);
      if (ai == null)
        return false;

      var i = 0;
      for (entry in list)
        {
          if (entry == ai)
            {
              if (index == i)
                return false;
              index = i;
              targetingAI = ai;
              game.scene.area.draw();
              return true;
            }
          i++;
        }
      return false;
    }

// clear target and exit targeting
  public function clear()
    {
      if (hud.state != HUD_TARGETING)
        return;
      clearTarget();
      exit();
    }

// clear current target
  public function clearTarget()
    {
      target = null;
    }

// clear target if it matches this ai
  public function clearTargetIf(ai: AI)
    {
      if (target == null ||
          target != ai)
        return;
      clearTarget();
      game.updateHUD();
    }

// check whether target is visible on screen
  public function isTargetVisibleOnScreen(): Bool
    {
      if (target == null)
        return false;
      if (game.location != LOCATION_AREA)
        return false;
      if (!game.area.inVisibleRect(target.x, target.y))
        return false;
      return game.playerArea.sees(target.x, target.y);
    }

// check whether target can be shot
  public function canShootTarget(): Bool
    {
      if (game.player.state != PLR_STATE_HOST ||
          target == null)
        return false;
      var weapon = game.playerArea.getCurrentWeapon();
      if (!weapon.isRanged)
        return false;
      return isTargetVisibleOnScreen();
    }

// check whether target can be attacked with melee
  public function canAttackTarget(): Bool
    {
      if (game.player.state != PLR_STATE_HOST ||
          target == null)
        return false;
      if (!isTargetVisibleOnScreen())
        return false;
      if (!target.isNear(game.playerArea.x, game.playerArea.y))
        return false;

      if (game.playerArea.getKnownMeleeWeapon() != null)
        return true;

      // allow melee attack when currently using fists
      var weaponInfo = game.player.host.getCurrentWeaponItemInfo();
      if (weaponInfo.id == 'fists')
        return true;

      return false;
    }

// build a list of visible ai for targeting
  function buildList(): Array<AI>
    {
      var list: Array<{ ai: AI, angle: Float }> = [];
      for (ai in game.area.getAllAI())
        {
          if (ai.state == AI_STATE_DEAD ||
              ai == game.player.host)
            continue;
          if (!game.area.inVisibleRect(ai.x, ai.y))
            continue;
          if (!game.playerArea.sees(ai.x, ai.y))
            continue;
          var dx = ai.x - game.playerArea.x;
          var dy = ai.y - game.playerArea.y;
          var angle = Math.atan2(dy, dx);
          if (angle < 0)
            angle += Math.PI * 2;
          list.push({
            ai: ai,
            angle: angle,
          });
        }
      list.sort(function (a, b) {
        if (a.angle < b.angle)
          return -1;
        if (a.angle > b.angle)
          return 1;
        return 0;
      });
      var out: Array<AI> = [];
      for (entry in list)
        out.push(entry.ai);
      return out;
    }
}

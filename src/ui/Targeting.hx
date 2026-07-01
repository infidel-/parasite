// targeting helper
package ui;

import ai.AI;
import game.Game;
import objects.AreaObject;
import objects.base.RivalBaseOrganObject;
import ui.HUD;

class Targeting
{
  var game: Game;
  var hud: HUD;
  var list: Array<AttackTarget>;
  var index: Int;
  public var target: AttackTarget;
  public var targetingTarget: AttackTarget;

  public function new(g: Game, h: HUD)
    {
      game = g;
      hud = h;
      list = [];
      index = -1;
      target = null;
      targetingTarget = null;
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
      targetingTarget = list[0];
      if (target != null)
        {
          var i = 0;
          for (entry in list)
            {
              if (sameTarget(entry, target))
                {
                  index = i;
                  targetingTarget = entry;
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
      targetingTarget = null;
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
      targetingTarget = list[index];
      if (game.location == LOCATION_AREA)
        game.scene.area.draw();
    }

// confirm target and exit targeting
  public function confirm()
    {
      if (hud.state != HUD_TARGETING)
        return;
      if (targetingTarget != null)
        target = targetingTarget;
      exit();
    }

// select target by mouse click and exit targeting
  public function selectByMouse(x: Int, y: Int): Bool
    {
      if (hud.state != HUD_TARGETING ||
          game.location != LOCATION_AREA ||
          list.length == 0)
        return false;

      var i = getTargetIndexAt(x, y);
      if (i < 0)
        return false;

      index = i;
      targetingTarget = list[index];
      target = targetingTarget;
      exit();
      return true;
    }

// update targeting target from mouse hover
  public function hoverByMouse(x: Int, y: Int): Bool
    {
      if (hud.state != HUD_TARGETING ||
          game.location != LOCATION_AREA ||
          list.length == 0)
        return false;

      var i = getTargetIndexAt(x, y);
      if (i < 0 ||
          index == i)
        return false;

      index = i;
      targetingTarget = list[index];
      game.scene.area.draw();
      return true;
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
          target.type != TARGET_AI ||
          target.ai != ai)
        return;
      clearTarget();
      game.updateHUD();
    }

// returns current target as AI, or null for object targets
  public function getAITarget(): AI
    {
      if (target == null ||
          target.type != TARGET_AI)
        return null;
      return target.ai;
    }

// checks whether this AI is currently highlighted in targeting mode
  public function isTargetingAI(ai: AI): Bool
    {
      return targetingTarget != null &&
        targetingTarget.type == TARGET_AI &&
        targetingTarget.ai == ai;
    }

// checks whether this AI is the stored target
  public function isTargetedAI(ai: AI): Bool
    {
      return target != null &&
        target.type == TARGET_AI &&
        target.ai == ai &&
        isTargetVisibleOnScreen();
    }

// checks whether this object is currently highlighted in targeting mode
  public function isTargetingObject(obj: AreaObject): Bool
    {
      if (obj.getTargetObject() != obj)
        return false;
      return targetingTarget != null &&
        targetingTarget.type == TARGET_OBJECT &&
        targetingTarget.obj.getTargetKey() == obj.getTargetKey();
    }

// checks whether this object is the stored target
  public function isTargetedObject(obj: AreaObject): Bool
    {
      if (obj.getTargetObject() != obj)
        return false;
      return target != null &&
        target.type == TARGET_OBJECT &&
        target.obj.getTargetKey() == obj.getTargetKey() &&
        isTargetVisibleOnScreen();
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
      if (target.type == TARGET_OBJECT &&
          !target.obj.isAttackableByFriend())
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
      if (!isTargetNear(target))
        return false;

      // any known melee weapon in inventory works
      if (game.playerArea.getKnownMeleeWeapon() != null)
        return true;

      // or the current weapon is melee (fists, animal attack, equipped melee)
      return !game.playerArea.getCurrentWeapon().isRanged;
    }

// build a list of visible attack targets
  function buildList(): Array<AttackTarget>
    {
      var list: Array<{ target: AttackTarget, angle: Float }> = [];
      var objectTargets = new Map<String, Bool>();
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
            target: {
              game: game,
              type: TARGET_AI,
              ai: ai,
            },
            angle: angle,
          });
        }
      for (obj in game.area.getObjects())
        {
          if (!obj.isAttackableByFriend())
            continue;
          if (!game.area.inVisibleRect(obj.x, obj.y))
            continue;
          if (!game.playerArea.sees(obj.x, obj.y))
            continue;
          var targetObj = obj.getTargetObject();
          var key = targetObj.getTargetKey();
          if (objectTargets.exists(key))
            continue;
          objectTargets.set(key, true);
          var dx = targetObj.getTargetCenterX() - (game.playerArea.x + 0.5);
          var dy = targetObj.getTargetCenterY() - (game.playerArea.y + 0.5);
          var angle = Math.atan2(dy, dx);
          if (angle < 0)
            angle += Math.PI * 2;
          list.push({
            target: {
              game: game,
              type: TARGET_OBJECT,
              ai: null,
              obj: targetObj,
            },
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
      var out: Array<AttackTarget> = [];
      for (entry in list)
        out.push(entry.target);
      return out;
    }

// returns index of target at a tile, preferring AI over objects
  function getTargetIndexAt(x: Int, y: Int): Int
    {
      var ai = game.area.getAI(x, y);
      if (ai != null)
        for (i in 0...list.length)
          {
            var entry = list[i];
            if (entry.type == TARGET_AI &&
                entry.ai == ai)
              return i;
          }

      for (obj in game.area.getObjectsAt(x, y))
        for (i in 0...list.length)
          {
            var entry = list[i];
            if (!obj.isAttackableByFriend())
              continue;
            if (entry.type == TARGET_OBJECT &&
                entry.obj.getTargetKey() == obj.getTargetObject().getTargetKey())
              return i;
          }

      return -1;
    }

// checks whether two target wrappers reference the same entity
  function sameTarget(a: AttackTarget, b: AttackTarget): Bool
    {
      if (a == null ||
          b == null ||
          a.type != b.type)
        return false;
      switch (a.type)
        {
          case TARGET_AI:
            return a.ai == b.ai;
          case TARGET_OBJECT:
            return a.obj.getTargetKey() == b.obj.getTargetKey();
          case TARGET_PLAYER:
            return true;
        }
    }

// checks whether current player host is close enough for melee target attack
  function isTargetNear(target: AttackTarget): Bool
    {
      if (target.isNear(game.playerArea.x, game.playerArea.y))
        return true;
      if (target.type == TARGET_OBJECT &&
          Std.isOfType(target.obj, RivalBaseOrganObject))
        {
          var rivalObj: RivalBaseOrganObject = cast target.obj;
          return rivalObj.getAttackPartNear(
            game.playerArea.x, game.playerArea.y) != null;
        }
      return false;
    }
}

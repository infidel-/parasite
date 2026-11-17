package objects.base;

import ai.CommonLogic;
import const.CultBaseConst;
import game.Game;

class SpineTurret extends BaseOrganObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, organID: Int,
      ?basePartIndex: Int = 0)
    {
      super(g, vaid, vx, vy, organID, basePartIndex);
    }

// init object appearance
  public override function init()
    {
      super.init();
      name = N('Turris Spinarum');
    }

// fires down the chosen cardinal line, at the first foes in it by level
  public override function turn()
    {
      var organ = getOrgan();
      if (organ == null ||
          !organ.isWorking())
        return;
      var dx = 0;
      var dy = 0;
      switch (organ.direction)
        {
          case 0:
            dy = -1;
          case 1:
            dx = 1;
          case 2:
            dy = 1;
          case 3:
            dx = -1;
          default:
            dy = -1;
        }
      var dmg = CultBaseConst.turretDamage(organ.level);
      var shots = CultBaseConst.turretTargets(organ.level);
      var tx = x + dx;
      var ty = y + dy;
      while (tx >= 0 &&
          ty >= 0 &&
          tx < game.area.width &&
          ty < game.area.height &&
          game.area.canSeeThrough(tx, ty))
        {
          var ai = game.area.getAI(tx, ty);
          if (ai != null &&
              !ai.isPlayerCultist() &&
              !ai.isCustos &&
              !ai.isPlayerHost() &&
              ai.state != AI_STATE_PRESERVED)
            {
              var weapon: WeaponInfo = {
                isRanged: true,
                skill: SKILL_ATTACK,
                minDamage: dmg.min,
                maxDamage: dmg.max,
                textMiss: T('{attacker:The} tries to shoot a spine at {target:the}, but misses.'),
                textMissYou: T('{attacker:The} tries to shoot a spine at you, but misses.'),
                textHit: T('{attacker:The} shoots a spine at {target:the} for {damage} damage.'),
                textHitYou: T('{attacker:The} shoots a spine at you for {damage} damage.'),
                type: WEAPON_KINETIC,
                projectile: 'needle',
                canConceal: false,
                sound: {
                  file: 'action-paralysis-spit',
                  radius: 8,
                  alertness: 12,
                },
              };
              CommonLogic.logicAttack(
                Attacker.fromObject(game, this, weapon, 100, true), {
                  game: game,
                  type: TARGET_AI,
                  ai: ai
                });
              shots--;
              if (shots <= 0)
                return;
            }
          tx += dx;
          ty += dy;
        }
    }
}

package objects.base;

import ai.CommonLogic;
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
      name = 'Turris Spinarum';
    }

// fires down the chosen cardinal line
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
              !ai.isCustos)
            {
              var weapon: WeaponInfo = {
                isRanged: true,
                skill: SKILL_ATTACK,
                minDamage: 1,
                maxDamage: 4,
                verb1: 'shoot a spine at',
                verb2: 'shoots a spine at',
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
              return;
            }
          tx += dx;
          ty += dy;
        }
    }
}

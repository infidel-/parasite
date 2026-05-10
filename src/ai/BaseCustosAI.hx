// fleshcrafted base guardian AI helpers
package ai;

import game.Game;

class BaseCustosAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
    }

// init common custos metadata
  public function initCustosBase(typeID: String, displayName: String)
    {
      type = typeID;
      isHuman = false;
      isNameKnown = true;
      isCustos = true;
      isGuard = true;
      isAggressive = true;
      isRelentless = true;
      soundsID = 'dog';
      name = {
        real: displayName,
        realCapped: Const.capitalize(displayName),
        unknown: displayName,
        unknownCapped: Const.capitalize(displayName)
      };
    }

// finalize custos stats after variant init
  public function finishCustosInit()
    {
      recalc();
      energy = maxEnergy;
      health = maxHealth;
      skills.addID(SKILL_ATTACK, 65);
    }

// cannot be attached by parasite
  public override function canAttach(): Bool
    {
      return false;
    }
}

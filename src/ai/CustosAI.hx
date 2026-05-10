// fleshcrafted base guardian AI
package ai;

import game.Game;

class CustosAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int,
      ?variant: _CustosType)
    {
      super(g, vx, vy);
      if (variant == null)
        variant = FIRMUS;
      init();
      custosType = variant;
      applyCustosType(true);
      initPost(false);
    }

// init Custos metadata and default stats
  public override function init()
    {
      super.init();
      type = 'custos';
      isHuman = false;
      isCustos = true;
      isGuard = true;
      isAggressive = true;
      isRelentless = true;
      soundsID = 'dog';
      name = {
        real: 'custos',
        realCapped: 'Custos',
        unknown: 'custos',
        unknownCapped: 'Custos'
      };
      custosType = FIRMUS;
    }

// applies variant stats to the guardian
  public function applyCustosType(?fillHealth: Bool = false)
    {
      isCustos = true;
      switch (custosType)
        {
          case FIRMUS:
            strength = 8 + Std.random(3) - 1;
            constitution = 12 + Std.random(3) - 1;
            intellect = 2;
            psyche = 7;
            name.real = name.realCapped = 'Firmus';
            name.unknown = name.unknownCapped = 'Firmus';
          case MORDAX:
            strength = 10 + Std.random(3) - 1;
            constitution = 7 + Std.random(3) - 1;
            intellect = 2;
            psyche = 6;
            name.real = name.realCapped = 'Mordax';
            name.unknown = name.unknownCapped = 'Mordax';
        }
      recalc();
      energy = maxEnergy;
      if (fillHealth ||
          health <= 0)
        health = maxHealth;
      else if (health > maxHealth)
        health = maxHealth;
      skills.addID(SKILL_ATTACK, 65);
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

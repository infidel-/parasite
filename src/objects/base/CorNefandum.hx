package objects.base;

import ai.AI;
import ai.CustosLogic;
import game.Game;

class CorNefandum extends BaseOrganObject
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
      name = 'Cor Nefandum';
    }

// alerts custodes when the heart takes combat damage
  public override function onDamage(damage: Int, ?attacker: AI)
    {
      CustosLogic.onHeartAttacked(attacker);
      var base = game.cults[0].base;
      var organ = getOrgan();
      if (base != null && organ != null)
        base.damageOrgan(organ, damage);
    }
}

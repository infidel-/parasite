// raw smash combat stimulant effect

package effects;

import ai.AI;
import game.Effect;
import game.Game;
import ItemInfo;

class Smash extends Effect
{
// creates smash effect instance
  public function new(game: Game, points: Int)
    {
      super(game, EFFECT_SMASH, points, true);
      init();
      initPost(false);
    }

// sets effect defaults
  public override function init()
    {
      super.init();
      name = 'smash';
    }

// emits unsettling wail while smash is active
  public override function turn(ai: AI, time: Int)
    {
      super.turn(ai, time);
      if (ai == null)
        return;
      if (Std.random(100) >= 35)
        return;

      ai.emitSound({
        text: '*WAIL*',
        radius: 6,
        alertness: 12
      });
    }

// adds extra melee damage while smash is active
  public override function damageMods(weapon: WeaponInfo): Array<_DamageBonus>
    {
      if (weapon.isRanged ||
          weapon.type != WEAPON_MELEE)
        return [];

      return [{
        name: 'smash 1d4',
        min: 1,
        max: 4
      }];
    }
}

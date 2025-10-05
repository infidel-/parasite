// defines stunner melee weapon
package items;

import game.Game;
import ItemInfo;

class Stunner extends ItemInfo
{
// builds stunner weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'stunner';
      name = 'stunner';
      type = 'weapon';
      unknown = 'elongated object';
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2,
        maxDamage: 8,
        verb1: 'stun',
        verb2: 'stuns',
        type: WEAPON_STUN,
        sound: {
          file: 'attack-stunner',
          radius: 3,
          alertness: 10,
        },
      };
    }
}

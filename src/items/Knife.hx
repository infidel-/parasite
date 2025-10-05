// defines knife melee weapon
package items;

import game.Game;
import ItemInfo;

class Knife extends ItemInfo
{
// builds knife weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'knife';
      name = 'knife';
      type = 'weapon';
      unknown = 'small blade';
      weapon = {
        isRanged: false,
        skill: SKILL_ATTACK,
        minDamage: 1,
        maxDamage: 6,
        verb1: 'stab',
        verb2: 'stabs',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-knife',
          radius: 4,
          alertness: 8,
        },
      };
    }
}

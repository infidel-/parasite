// defines machete melee weapon
package items;

import game.Game;
import ItemInfo;

class Machete extends ItemInfo
{
// builds machete weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'machete';
      name = 'machete';
      type = 'weapon';
      unknown = 'broad blade';
      weapon = {
        isRanged: false,
        skill: SKILL_ATTACK,
        minDamage: 3,
        maxDamage: 8,
        verb1: 'slash',
        verb2: 'slashes',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-machete',
          radius: 5,
          alertness: 10,
        },
      };
    }
}

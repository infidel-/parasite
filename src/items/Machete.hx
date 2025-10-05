// defines machete melee weapon
package items;

import game.Game;

class Machete extends Weapon
{
// builds machete weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'machete';
      name = 'machete';
      unknown = 'broad blade';
      weapon = {
        isRanged: false,
        skill: SKILL_MACHETE,
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

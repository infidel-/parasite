// defines katana melee weapon
package items;

import game.Game;

class Katana extends Weapon
{
// builds katana weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'katana';
      name = 'katana';
      type = 'weapon';
      unknown = 'long curved blade';
      weapon = {
        isRanged: false,
        minDamage: 1,
        maxDamage: 10,
        verb1: 'cut',
        verb2: 'cuts',
        skill: SKILL_KATANA,
        type: WEAPON_MELEE,
      };
    }
}

// defines brass knuckles melee weapon
package items;

import game.Game;

class BrassKnuckles extends Weapon
{
// builds brass knuckles weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'brassKnuckles';
      name = 'brass knuckles';
      unknown = 'heavy rings';
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2,
        maxDamage: 5,
        verb1: 'slug',
        verb2: 'slugs',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-fists',
          radius: 4,
          alertness: 6,
        },
      };
    }
}

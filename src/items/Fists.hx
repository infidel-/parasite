// defines fists special weapon
package items;

import game.Game;
import ItemInfo;

class Fists extends ItemInfo
{
// builds fists weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'fists';
      name = 'fists';
      type = 'weapon';
      unknown = 'fists';
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 1,
        maxDamage: 3,
        verb1: 'punch',
        verb2: 'punches',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-fists',
          radius: 5,
          alertness: 5,
        },
      };
    }
}

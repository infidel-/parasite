// defines baseball bat melee weapon
package items;

import game.Game;
import ItemInfo;

class BaseballBat extends ItemInfo
{
// builds baseball bat weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'baseballBat';
      name = 'baseball bat';
      type = 'weapon';
      unknown = 'wooden club';
      weapon = {
        isRanged: false,
        skill: SKILL_BATON,
        minDamage: 2,
        maxDamage: 8,
        verb1: 'club',
        verb2: 'clubs',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-baton',
          radius: 5,
          alertness: 10,
        },
      };
    }
}

// defines baseball bat melee weapon
package items;

import game.Game;

class BaseballBat extends Weapon
{
// builds baseball bat weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'baseballBat';
      name = 'baseball bat';
      unknown = 'wooden club';
      weapon = {
        isRanged: false,
        skill: SKILL_CLUB,
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

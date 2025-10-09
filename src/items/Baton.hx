// defines baton melee weapon
package items;

import game.Game;

class Baton extends Weapon
{
// builds baton weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'baton';
      name = 'baton';
      unknown = 'elongated object';
      weapon = {
        isRanged: false,
        skill: SKILL_BATON,
        minDamage: 1,
        maxDamage: 6,
        verb1: 'hit',
        verb2: 'hits',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-baton',
          radius: 5,
          alertness: 10,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 10,
        },
      };
    }
}

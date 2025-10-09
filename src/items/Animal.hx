// defines animal attack special weapon
package items;

import game.Game;

class Animal extends Weapon
{
// builds animal attack info
  public function new(game: Game)
    {
      super(game);
      id = 'animal';
      name = 'animal BUG!!!';
      unknown = 'animal BUG!!!';
      weapon = {
        isRanged: false,
        skill: SKILL_ATTACK,
        minDamage: 1,
        maxDamage: 4,
        verb1: 'attack',
        verb2: 'attacks',
        type: WEAPON_MELEE,
        sound: {
          file: 'attack-bite',
          radius: 5,
          alertness: 3,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 3,
        },
      };
    }
}

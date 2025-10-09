// defines knife melee weapon
package items;

import game.Game;

class Knife extends Weapon
{
// builds knife weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'knife';
      name = 'knife';
      unknown = 'small blade';
      weapon = {
        isRanged: false,
        skill: SKILL_KNIFE,
        minDamage: 1,
        maxDamage: 6,
        verb1: 'stab',
        verb2: 'stabs',
        type: WEAPON_MELEE,
        spawnBlood: true,
        sound: {
          file: 'attack-knife',
          radius: 4,
          alertness: 8,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 4,
          alertness: 8,
        },
      };
    }
}

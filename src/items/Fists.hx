// defines fists special weapon
package items;

import game.Game;

class Fists extends Weapon
{
// builds fists weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'fists';
      name = 'fists';
      unknown = 'fists';
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 1,
        maxDamage: 3,
        verb1: 'punch',
        verb2: 'punches',
        type: WEAPON_MELEE,
        canConceal: true,
        sound: {
          file: 'attack-fists',
          radius: 5,
          alertness: 5,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 5,
        },
      };
    }
}

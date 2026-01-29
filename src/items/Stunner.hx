// defines stunner melee weapon
package items;

import game.Game;

class Stunner extends Weapon
{
// builds stunner weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'stunner';
      name = 'stunner';
      unknown = 'elongated object';
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2,
        maxDamage: 8,
        verb1: 'stun',
        verb2: 'stuns',
        type: WEAPON_STUN,
        canConceal: true,
        sound: {
          file: 'attack-stunner',
          radius: 3,
          alertness: 10,
        },
      };
    }
}

// defines pistol ranged weapon
package items;

import game.Game;

class Pistol extends Weapon
{
// builds pistol weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'pistol';
      name = 'pistol';
      unknown = 'metallic object';
      weapon = {
        isRanged: true,
        skill: SKILL_PISTOL,
        minDamage: 1,
        maxDamage: 10,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        canConceal: true,
        sound: {
          file: 'attack-pistol',
          radius: 15,
          alertness: 30,
        },
      };
    }
}

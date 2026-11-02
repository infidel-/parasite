// defines assault rifle ranged weapon
package items;

import game.Game;

class AssaultRifle extends Weapon
{
// builds assault rifle weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'assaultRifle';
      name = N('assault rifle');
      unknown = N('elongated metallic object');
      weapon = {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2,
        maxDamage: 12,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        canConceal: false,
        sound: {
          file: 'attack-assault-rifle',
          radius: 15,
          alertness: 40,
        },
      };
    }
}

// defines combat shotgun ranged weapon
package items;

import game.Game;

class CombatShotgun extends Weapon
{
// builds combat shotgun weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'combatShotgun';
      name = N('combat shotgun');
      unknown = N('elongated metallic object');
      weapon = {
        isRanged: true,
        skill: SKILL_SHOTGUN,
        minDamage: 4,
        maxDamage: 24,
        verb1: 'shoot',
        verb2: 'shoots',
        type: WEAPON_KINETIC,
        canConceal: false,
        sound: {
          file: 'attack-shotgun',
          radius: 10,
          alertness: 30,
        },
      };
    }
}

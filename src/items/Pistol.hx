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
      name = N('pistol');
      unknown = N('metallic object');
      weapon = {
        isRanged: true,
        skill: SKILL_PISTOL,
        minDamage: 1,
        maxDamage: 10,
        textMiss: T('{attacker:The} tries to shoot {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to shoot you, but misses.'),
        textHit: T('{attacker:The} shoots {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} shoots you for {damage} damage.'),
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

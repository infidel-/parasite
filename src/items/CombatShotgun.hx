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
        textMiss: T('{attacker:The} tries to shoot {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to shoot you, but misses.'),
        textHit: T('{attacker:The} shoots {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} shoots you for {damage} damage.'),
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

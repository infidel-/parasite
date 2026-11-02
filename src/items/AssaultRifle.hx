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
        textMiss: T('{attacker:The} tries to shoot {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to shoot you, but misses.'),
        textHit: T('{attacker:The} shoots {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} shoots you for {damage} damage.'),
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

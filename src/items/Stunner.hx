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
      name = N('stunner');
      unknown = N('elongated object');
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2,
        maxDamage: 8,
        textMiss: T('{attacker:The} tries to stun {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to stun you, but misses.'),
        textHit: T('{attacker:The} stuns {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} stuns you for {damage} damage.'),
        textStun: T('{attacker:The} stuns {target:the} for {rounds, plural, one{# round} other{# rounds}}.'),
        type: WEAPON_STUN,
        attackEffect: STUN,
        canConceal: true,
        sound: {
          file: 'attack-stunner',
          radius: 3,
          alertness: 10,
        },
      };
    }
}

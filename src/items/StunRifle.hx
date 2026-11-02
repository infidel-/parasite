// defines stun rifle ranged weapon
package items;

import game.Game;

class StunRifle extends Weapon
{
// builds stun rifle weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'stunRifle';
      name = N('stun rifle');
      unknown = N('elongated metallic object');
      weapon = {
        isRanged: true,
        skill: SKILL_RIFLE,
        minDamage: 2,
        maxDamage: 10,
        textMiss: T('{attacker:The} tries to stun {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to stun you, but misses.'),
        textHit: T('{attacker:The} stuns {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} stuns you for {damage} damage.'),
        textStun: T('{attacker:The} stuns {target:the} for {rounds, plural, one{# round} other{# rounds}}.'),
        type: WEAPON_STUN,
        canConceal: false,
        sound: {
          file: 'attack-stun-rifle',
          radius: 10,
          alertness: 20,
        },
      };
    }
}

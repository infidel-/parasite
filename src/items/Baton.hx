// defines baton melee weapon
package items;

import game.Game;

class Baton extends Weapon
{
// builds baton weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'baton';
      name = N('baton');
      unknown = N('elongated object');
      weapon = {
        isRanged: false,
        skill: SKILL_BATON,
        minDamage: 1,
        maxDamage: 6,
        textMiss: T('{attacker:The} tries to hit {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to hit you, but misses.'),
        textHit: T('{attacker:The} hits {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} hits you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: BLUNT,
        canConceal: true,
        sound: {
          file: 'attack-baton',
          radius: 5,
          alertness: 10,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 10,
        },
      };
    }
}

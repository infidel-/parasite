// defines animal attack special weapon
package items;

import game.Game;

class Animal extends Weapon
{
// builds animal attack info
  public function new(game: Game)
    {
      super(game);
      id = 'animal';
      name = 'animal BUG!!!';
      unknown = 'animal BUG!!!';
      weapon = {
        isRanged: false,
        skill: SKILL_ATTACK,
        minDamage: 1,
        maxDamage: 4,
        textMiss: T('{attacker:The} tries to attack {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to attack you, but misses.'),
        textHit: T('{attacker:The} attacks {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} attacks you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: BITE,
        canConceal: true,
        sound: {
          file: 'attack-bite',
          radius: 5,
          alertness: 3,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 3,
        },
      };
    }
}

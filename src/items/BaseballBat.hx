// defines baseball bat melee weapon
package items;

import game.Game;

class BaseballBat extends Weapon
{
// builds baseball bat weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'baseballBat';
      name = N('baseball bat');
      unknown = N('wooden club');
      weapon = {
        isRanged: false,
        skill: SKILL_CLUB,
        minDamage: 2,
        maxDamage: 8,
        textMiss: T('{attacker:The} tries to club {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to club you, but misses.'),
        textHit: T('{attacker:The} clubs {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} clubs you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: BLUNT,
        canConceal: false,
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

// defines machete melee weapon
package items;

import game.Game;

class Machete extends Weapon
{
// builds machete weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'machete';
      name = N('machete');
      unknown = N('broad blade');
      weapon = {
        isRanged: false,
        skill: SKILL_MACHETE,
        minDamage: 3,
        maxDamage: 8,
        textMiss: T('{attacker:The} tries to slash {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to slash you, but misses.'),
        textHit: T('{attacker:The} slashes {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} slashes you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: SLASH_HEAVY,
        spawnBlood: true,
        canConceal: true,
        sound: {
          file: 'attack-machete',
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

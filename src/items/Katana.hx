// defines katana melee weapon
package items;

import game.Game;

class Katana extends Weapon
{
// builds katana weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'katana';
      name = N('katana');
      type = 'weapon';
      unknown = N('long curved blade');
      weapon = {
        isRanged: false,
        minDamage: 1,
        maxDamage: 10,
        textMiss: T('{attacker:The} tries to cut {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to cut you, but misses.'),
        textHit: T('{attacker:The} cuts {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} cuts you for {damage} damage.'),
        skill: SKILL_KATANA,
        type: WEAPON_MELEE,
        attackEffect: SLASH_HEAVY,
        spawnBlood: true,
        canConceal: false,
        sound: {
          file: 'attack-machete',
          radius: 6,
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

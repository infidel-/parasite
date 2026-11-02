// defines knife melee weapon
package items;

import game.Game;

class Knife extends Weapon
{
// builds knife weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'knife';
      name = N('knife');
      unknown = N('small blade');
      weapon = {
        isRanged: false,
        skill: SKILL_KNIFE,
        minDamage: 1,
        maxDamage: 6,
        textMiss: T('{attacker:The} tries to stab {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to stab you, but misses.'),
        textHit: T('{attacker:The} stabs {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} stabs you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: SLASH_LIGHT,
        spawnBlood: true,
        canConceal: true,
        sound: {
          file: 'attack-knife',
          radius: 4,
          alertness: 8,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 4,
          alertness: 8,
        },
      };
    }
}

// defines fists special weapon
package items;

import game.Game;

class Fists extends Weapon
{
// builds fists weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'fists';
      name = N('fists');
      unknown = N('fists');
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 1,
        maxDamage: 3,
        textMiss: T('{attacker:The} tries to punch {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to punch you, but misses.'),
        textHit: T('{attacker:The} punches {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} punches you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: PUNCH,
        canConceal: true,
        sound: {
          file: 'attack-fists',
          radius: 5,
          alertness: 5,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 5,
          alertness: 5,
        },
      };
    }
}

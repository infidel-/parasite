// defines brass knuckles melee weapon
package items;

import game.Game;

class BrassKnuckles extends Weapon
{
// builds brass knuckles weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'brassKnuckles';
      name = N('brass knuckles');
      unknown = N('heavy rings');
      weapon = {
        isRanged: false,
        skill: SKILL_FISTS,
        minDamage: 2,
        maxDamage: 5,
        textMiss: T('{attacker:The} tries to slug {target:the}, but misses.'),
        textMissYou: T('{attacker:The} tries to slug you, but misses.'),
        textHit: T('{attacker:The} slugs {target:the} for {damage} damage.'),
        textHitYou: T('{attacker:The} slugs you for {damage} damage.'),
        type: WEAPON_MELEE,
        attackEffect: PUNCH,
        canConceal: true,
        sound: {
          file: 'attack-fists',
          radius: 4,
          alertness: 6,
        },
        soundMiss: {
          file: 'attack-melee-miss',
          radius: 4,
          alertness: 6,
        },
      };
    }
}

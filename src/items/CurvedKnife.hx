// defines curved knife melee weapon
package items;

import ai.AI;
import game.Game;

class CurvedKnife extends Weapon
{
// builds curved knife weapon info
  public function new(game: Game)
    {
      super(game);
      id = 'curvedKnife';
      name = N('curved knife');
      unknown = N('curved piece of metal');
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

// applies bleeding after successful hits
  public override function logicAttackPost(ai: AI, target: AttackTarget, isAttackerPlayer: Bool): Void
    {
      switch (target.type)
        {
          case TARGET_AI:
            target.ai.onEffect(new effects.Bleeding(game, 3));
            target.ai.log(T('{ai:The} is bleeding!', { ai: target.ai }));
          case TARGET_PLAYER:
            // does not work on player
          default:
        }
    }
}

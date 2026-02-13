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
      name = 'curved knife';
      unknown = 'curved piece of metal';
      weapon = {
        isRanged: false,
        skill: SKILL_KNIFE,
        minDamage: 1,
        maxDamage: 6,
        verb1: 'stab',
        verb2: 'stabs',
        type: WEAPON_MELEE,
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
  public override function logicAttackPost(ai: AI, target: AITarget, isAttackerPlayer: Bool): Void
    {
      switch (target.type)
        {
          case TARGET_AI:
            target.ai.onEffect(new effects.Bleeding(game, 3));
            target.ai.log(' is bleeding!');
          case TARGET_PLAYER:
            // does not work on player
          default:
        }
    }
}

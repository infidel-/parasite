// AI for dogs 

package ai;

import ai.AI;
import _AIState;

class DogAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'dog';
      name = {
        real: 'the dog',
        realCapped: 'The dog',
        unknown: 'the dog',
        unknownCapped: 'The dog'
        };
      sounds = [
        '' + REASON_DAMAGE => [
          { text: '*WHIMPER*', radius: 2, alertness: 5, params: null },
          { text: '*WHINE*', radius: 2, alertness: 5, params: null },
          { text: '*YELP*', radius: 3, alertness: 5, params: null },
          ],
        '' + AI_STATE_IDLE => [
          { text: '*GROWL*', radius: 2, alertness: 5, params: { minAlertness: 25 }  },
          ],
        '' + AI_STATE_ALERT => [
          { text: '*BARK*', radius: 5, alertness: 10, params: null },
          ],
        '' + AI_STATE_HOST => [
          { text: '*whimper*', radius: 2, alertness: 3, params: null },
          { text: '*whine*', radius: 2, alertness: 3, params: null },
          { text: '*growl*', radius: 2, alertness: 3, params: null },
          { text: '*GROWL*', radius: 2, alertness: 3, params: null },
          ]
        ];

      strength = 2 + Std.random(3);
      constitution = 2 + Std.random(3);
      intellect = 1;
      psyche = 1 + Std.random(1);

      derivedStats();
    }
}

// AI for dogs 

package ai;

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
        AI.STATE_ALERT => [
          { text: '*GROWL*', radius: 2, alertness: 5  },
          { text: '*BARK*', radius: 5, alertness: 10 },
          ]
        ];

      strength = 2 + Std.random(3);
      constitution = 2 + Std.random(3);
      intellect = 1;
      psyche = 1 + Std.random(1);

      derivedStats();
    }
}

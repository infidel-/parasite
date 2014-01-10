// AI for dogs 

class DogAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'dog';
      name =
        {
          real: 'the dog',
          realCapped: 'The dog',
          unknown: 'the dog',
          unknownCapped: 'The dog'
        };

      strength = 2 + Std.random(3);
      constitution = 2 + Std.random(3);
      intellect = 1;
      psyche = 1 + Std.random(1);

      derivedStats();
    }
}

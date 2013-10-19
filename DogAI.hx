// AI for dogs 

class DogAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'dog';
      name = 'The dog';

      strength = 2 + Std.random(3);
      psyche = 1 + Std.random(1);
      hostExpiryTurns = (5 + strength) * 10;
    }
}

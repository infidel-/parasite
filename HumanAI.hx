// AI for humans (should not be used in the game itself)

class HumanAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'human';
      name.real = name.realCapped = 'Joe Smith';

      strength = 4 + Std.random(4);
      constitution = 4 + Std.random(4);
      intellect = 4 + Std.random(4);
      psyche = 4 + Std.random(4);

      derivedStats();
    }
}

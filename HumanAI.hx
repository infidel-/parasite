// AI for humans

class HumanAI extends AI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'human';
      name = 'Joe Smith';

      strength = 4 + Std.random(4);
    }
}
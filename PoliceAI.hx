// AI for police 

class PoliceAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'police';
      isAggressive = true;

      inventory.addID('pistol');
      skills.addID('pistol', 25 + Std.random(25));
    }
}

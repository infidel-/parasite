// AI for police 

class PoliceAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'police';
      name.unknown = 'police officer';
      name.unknownCapped = 'Police officer';
      isAggressive = true;
      inventory.addID('baton');
      skills.addID('baton', 50 + Std.random(25));
    }
}

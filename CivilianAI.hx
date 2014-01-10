// AI for civilians 

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'civilian';
      name.unknown = 'random civilian';
      name.unknownCapped = 'Random civilian';
    }


// event: on state change
  public override function onStateChange()
    {
      // try to call police on next turn if not struggling with parasite
      if (state == AI.STATE_ALERT && !parasiteAttached)
        game.areaManager.addAI(this, AreaManager.EVENT_CALL_POLICE, 1);
    }
}

// AI for civilians 

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'civilian';
    }


// event: on state change
  public override function onStateChange()
    {
      // try to call police on next turn
      if (state == AI.STATE_ALERT)
        game.areaManager.addAI(this, AreaManager.EVENT_CALL_POLICE, 1);
    }
}

// AI for civilians 

package ai;

class CivilianAI extends HumanAI
{
  public function new(g: Game, vx: Int, vy: Int)
    {
      super(g, vx, vy);
      type = 'civilian';
      name.unknown = 'random civilian';
      name.unknownCapped = 'Random civilian';
      sounds = [
        AI.STATE_IDLE => [
          { text: 'Huh?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'Whu?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'What the?', radius: 0, alertness: 0, params: { minAlertness: 50 } },
          ],
        AI.STATE_ALERT => [
          { text: '*SCREAM*', radius: 7, alertness: 15, params: null },
          ]
        ];
    }


// event: on state change
  public override function onStateChange()
    {
      // try to call police on next turn if not struggling with parasite
      if (state == AI.STATE_ALERT && !parasiteAttached)
        game.areaManager.addAI(this, AreaManager.EVENT_CALL_POLICE, 1);
    }
}

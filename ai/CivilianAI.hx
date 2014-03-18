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
        AI.REASON_DAMAGE => [
          { text: 'Ouch!', radius: 2, alertness: 5, params: null },
          { text: '*GROAN*', radius: 2, alertness: 5, params: null },
          ],
        AI.STATE_IDLE => [
          { text: 'Huh?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'Whu?', radius: 0, alertness: 0, params: { minAlertness: 25 } },
          { text: 'What the?', radius: 0, alertness: 0, params: { minAlertness: 50 } },
          { text: '*GASP*', radius: 0, alertness: 0, params: { minAlertness: 75 } },
          ],
        AI.STATE_ALERT => [
          { text: '*SCREAM*', radius: 7, alertness: 15, params: null },
          ],
        AI.STATE_HOST => [
          { text: '*moan*', radius: 2, alertness: 5, params: null },
          { text: '*MOAN*', radius: 3, alertness: 5, params: null },
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
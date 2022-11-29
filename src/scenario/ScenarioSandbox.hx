// scenario - sandbox

package scenario;

import scenario.Scenario;
import const.WorldConst;

class ScenarioSandbox extends Scenario
{
  public function new()
    {
      super();
      name = 'Sandbox';
      startEvent = 'dummy';
      playerStartEvent = 'dummy';
      defaultAlertness = 0;
      goals = [];
      eventObjectActions = [];
      eventObjectActionsFuncs = [];
      eventObjectActionsHooks = [];
      names = [];
      flow = [
        'dummy' => {
          name: 'dummy',
          notes: [ '', '', '' ],
          location: {},
          npc: [],
        },
      ];
    }
}

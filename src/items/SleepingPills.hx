// defines sleeping pills junk item
package items;

import game.Game;
import ItemInfo;

class SleepingPills extends ItemInfo
{
// builds sleeping pills info
  public function new(game: Game)
    {
      super(game);
      id = 'sleepingPills';
      name = 'bottle of sleeping pills';
      type = 'junk';
      unknown = 'small plastic container';
    }

// unlocks preservator goal sequence when conditions met
  public override function onLearn(): Void
    {
      if (game.goals.completed(GOAL_CREATE_HABITAT))
        {
          game.goals.receive(GOAL_LEARN_PRESERVATOR, SILENT_SYSTEM);
          game.goals.complete(GOAL_LEARN_PRESERVATOR, SILENT_SYSTEM);
        }
    }
}

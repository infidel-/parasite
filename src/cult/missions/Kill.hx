// kill mission sample
package cult.missions;

import game.Game;
import cult.Mission;

class Kill extends Mission
{
  public var targetID: Int;

  public function new(g: Game)
    {
      super(g);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = MISSION_KILL;
      name = 'Eliminate Target';
      note = 'A specific target must be eliminated.';
      targetID = 0;
    }
}

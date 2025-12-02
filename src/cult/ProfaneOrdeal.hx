// base class for profane ordeals
package cult;

import game.Game;
import cult.Mission;

class ProfaneOrdeal extends Ordeal
{
  public var timer: Int;
  public var missions: Array<Mission>;

  public function new(g: Game)
    {
      super(g);
      timer = 0;
      missions = [];
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = ORDEAL_PROFANE;
    }
}

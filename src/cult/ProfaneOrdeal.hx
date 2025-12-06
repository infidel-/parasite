// base class for profane ordeals
package cult;

import game.Game;

class ProfaneOrdeal extends Ordeal
{
  public var timer: Int;

  public function new(g: Game)
    {
      super(g);
      timer = 0;
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = ORDEAL_PROFANE;
    }
}

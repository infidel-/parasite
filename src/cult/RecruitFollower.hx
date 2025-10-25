// recruit follower ordeal - seek the pure
package cult;

import game.Game;
import cult.Cult;

class RecruitFollower extends Ordeal
{
  public function new(g: Game, c: Cult)
    {
      super(g, c);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'Seek the pure';
      type = ORDEAL_COMMUNAL;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

// recruit follower ordeal - seek the pure
package cult;

import game.Game;
import cult.Cult;
import ai.AIData;
import ai.CorpoAI;

class RecruitFollower extends Ordeal
{
  public var target: AIData;

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
      // we pick target on creation
      var ai = new CorpoAI(game, 0, 0);
      target = ai.cloneData();
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }
}

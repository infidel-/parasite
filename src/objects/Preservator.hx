// habitat - preservator

package objects;

import game.Game;

class Preservator extends HabitatObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int, l: Int)
    {
      super(g, vaid, vx, vy, l);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      name = 'preservator';
      spawnMessage = 'You feel cold signaling the activation of the host preservator.';
      imageRow = Const.ROW_GROWTH1;
      imageCol = Const.FRAME_PRESERVATOR + level;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    { return true; }

// update actions
  override function updateActionList()
    {
      if (game.player.state != PLR_STATE_HOST)
        return;

      game.ui.hud.addAction({
        id: 'preserveHost',
        type: ACTION_OBJECT,
        name: 'Preserve host',
        energy: 10,
        obj: this
      });
    }

// ACTION: action handling
  override function onAction(id: String): Bool
    {
      // preserve host
      if (id == 'preserveHost')
        {
          game.log('You release the host into the cold embrace of the preservator.');
          game.playerArea.leaveHostAction('preservator');
          return true;
        }

      return false;
    }
}


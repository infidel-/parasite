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

// return improvement id
  public override function getImprovementID(): _Improv
    {
      return IMP_PRESERVATOR;
    }

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
  override function onAction(action: _PlayerAction): Bool
    {
      // preserve host
      if (action.id == 'preserveHost')
        {
          if (x == game.playerArea.x && y == game.playerArea.y)
            {
              game.actionFailed('Move to any free side of the preservator first.');
              return true;
            }
          // count preserved hosts around
          var cnt = 0;
          for (i in 0...Const.dir4x.length)
            {
              var ai = game.area.getAI(x + Const.dir4x[i], y + Const.dir4y[i]);
              if (ai != null && ai.state == AI_STATE_PRESERVED)
                cnt++;
            }
          var params = getParams();
          if (cnt >= params.hostAmount)
            {
              game.actionFailed('This preservator is full.');
              return true;
            }

          game.scene.sounds.play('object-preservator');
          game.log('You release the host into the cold embrace of the preservator.');
          game.playerArea.leaveHostAction('preservator');
          return true;
        }

      return false;
    }
}


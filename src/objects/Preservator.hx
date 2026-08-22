// habitat - preservator

package objects;

import ai.AI;
import game.Game;
import lighting.AtmosphereLightProfiles;

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

// a grown body is solid: nothing walks through it. this is also what retires the see-through fade
// for this prop — the ghost batch in render.world.ObjModels only ever serves the placement the
// player is STANDING on, and nothing can stand here now
  public override function isWalkable(): Bool
    { return false; }

// the hosts this preservator has hold of: preserved AI on any of its four sides. THE definition —
// the capacity check below, the tooltip row and the 3D tethers all read it, so what the player is
// shown and what the game counts can never disagree.
// a host between two preservators is held by both, which is what the capacity check has always done
  public override function getLinkedAI(): Array<AI>
    {
      var list = [];
      for (i in 0...Const.dir4x.length)
        {
          var ai = game.area.getAI(x + Const.dir4x[i], y + Const.dir4y[i]);
          if (ai != null &&
              ai.state == AI_STATE_PRESERVED)
            list.push(ai);
        }
      return list;
    }

// tooltip: how full it is
  public override function getTooltipRows(): Array<objects.AreaObject.TooltipRow>
    {
      return [ {
        name: 'preserved',
        value: getLinkedAI().length + ' / ' + getParams().hostAmount,
      } ];
    }

// every habitat object shares the 'habitat' type, so the 3D prop lookup keys on this instead
  public override function getModelKey(): String
    { return 'habitat_preservator'; }

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
          if (x == game.playerArea.x &&
              y == game.playerArea.y)
            {
              game.actionFailed('Move to any free side of the preservator first.');
              return true;
            }
          // cannot preserve cultists
          // NOTE: this brings a bunch of problems: summoning, cult destroying while the player in other area and maybe more
          if (game.player.host.isCultist)
            {
              game.actionFailed('You cannot preserve cultists.');
              return true;
            }
          // count preserved hosts around
          var params = getParams();
          if (getLinkedAI().length >= params.hostAmount)
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

// get static atmosphere light emitted by this object
  public override function getAtmosphereLight(): _AtmosphereLightMeta
    {
      return AtmosphereLightProfiles.HABITAT_PRESERVATOR;
    }

// get atmosphere light stamp kind used by this object
  public override function getAtmosphereLightKind(): String
    {
      return 'habitat-preservator';
    }
}

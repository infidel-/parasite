// dumpster - a street refuse bin the parasite can slip into to hide from pursuit

package objects;

import game.Game;

class Dumpster extends AreaObject
{
  public function new(g: Game, vaid: Int, vx: Int, vy: Int)
    {
      super(g, vaid, vx, vy);
      init();
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      imageRow = Const.ROW_OBJECT2;
      imageCol = Const.FRAME_DUMPSTER;
      type = 'dumpster';
      name = 'dumpster';
      isStatic = true;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }

// update actions
  override function updateActionList()
    {
      // a parasite gripping a victim is in no position to climb anywhere
      if (game.player.state == PLR_STATE_ATTACHED)
        return;
      game.ui.hud.addAction({
        id: 'hideDumpster',
        type: ACTION_OBJECT,
        name: 'Hide in dumpster',
        energy: 5,
        obj: this,
      });
    }

// activate - slip inside, leaving any host behind. refused while an alerted enemy has the parasite
// in sight, because the point is to vanish and nobody vanishes in front of a witness
  override function onAction(action: _PlayerAction): Bool
    {
      var pa = game.playerArea;
      if (game.area.hostileSees(pa.x, pa.y))
        {
          game.actionFailed('You cannot hide while someone is watching you.');
          return false;
        }
      if (game.player.state == PLR_STATE_HOST)
        {
          game.log('You release the host.');
          pa.leaveHostAction('default');
        }
      pa.hideIn(this);
      game.log('You slither into the dumpster and go still under the refuse.');
      return true;
    }

// the 3D view draws a different bin per city tier
  public override function getModelKey(): String
    {
      return (game.area.typeID == AREA_CITY_LOW ? 'dumpster_slums' : 'dumpster_city');
    }

  public override function known(): Bool
    { return true; }

  public override function sensable(): Bool
    { return true; }

  public override function isGroundDecal(): Bool
    { return false; }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    { return true; }

// a solid steel bin: nobody walks through it, everybody sees over it
  public override function isWalkable(): Bool
    { return false; }
}

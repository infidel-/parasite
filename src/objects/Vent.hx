// ventilation cover

package objects;

import game.Game;

class Vent extends AreaObject
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
      imageCol = Const.FRAME_VENTILATION;
      type = 'vent';
      name = 'vent';
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
      game.ui.hud.addAction({
        id: 'enterVent',
        type: ACTION_OBJECT,
        name: 'Enter ventilation',
        energy: 10,
        obj: this
      });
    }

// activate - leave area
  override function onAction(action: _PlayerAction): Bool
    {
      if (game.player.state != PLR_STATE_PARASITE)
        {
          game.actionFailed("You can only enter the ventilation without a host.");
          return false;
        }

      // find spot player is coming from
      var idx = -1;
      for (i in 0...Const.dir4x.length)
        if (x + Const.dir4x[i] == game.playerArea.x &&
            y + Const.dir4y[i] == game.playerArea.y)
          {
            idx = i;
            break;
          }
      var idxto = Const.opposite4[idx];

      // NOTE: ignore the walkable check due to decoration everywhere
      var ret = game.playerArea.moveTo(
        x + Const.dir4x[idxto],
        y + Const.dir4y[idxto]);
      if (!ret)
        {
          game.actionFailed("There is something blocking the exit on the other side.");
          return false;
        }
      game.log("You quietly slither through the ventilation emerging outside after some time.");

      return true;
    }

  public override function sensable(): Bool
    { return true; }

// can be activated when player is next to it?
  public override function canActivateNear(): Bool
    { return true; }
}

// rival cult mission objective
package objects;

import game.Game;

class RivalSanctum extends AreaObject
{
  public var missionID: Int;
  public var health: Int;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, missionID: Int)
    {
      super(g, vaid, vx, vy);
      this.missionID = missionID;
      init();
      initPost(false);
    }

// init object fields
  public override function init()
    {
      super.init();
      type = 'rival_sanctum';
      name = 'rival sanctum';
      health = 30;
      imageRow = Const.ROW_GROWTH1;
      imageCol = Const.FRAME_PRESERVATOR;
      isStatic = true;
    }

// always known in rival attack mission
  public override function known(): Bool
    {
      return true;
    }

// can be activated near it
  public override function canActivateNear(): Bool
    {
      return true;
    }

// update action list
  override function updateActionList()
    {
      game.ui.hud.addAction({
        id: 'destroyRivalSanctum',
        type: ACTION_OBJECT,
        name: 'Destroy sanctum',
        energy: 10,
        obj: this
      });
    }

// damage sanctum and complete mission on destruction
  override function onAction(action: _PlayerAction): Bool
    {
      health -= Const.roll(6, 12);
      if (health > 0)
        {
          game.log('The sanctum shudders.');
          return true;
        }
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission != null &&
          !mission.isCompleted)
        mission.success();
      game.area.removeObject(this);
      game.log('The rival sanctum collapses.');
      return true;
    }
}

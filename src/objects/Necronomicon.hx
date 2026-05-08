// special Metamorphosis Phase I mission book
package objects;

import game.Game;

class Necronomicon extends AreaObject
{
  public var missionID: Int;

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
      type = 'necronomicon';
      name = 'Necronomicon';
      imageRow = Const.ROW_OBJECT;
      imageCol = Const.FRAME_BOOK;
      isStatic = true;
    }

// known after cult unlock flow begins
  public override function known(): Bool
    {
      return true;
    }

// can be activated from adjacent tile
  public override function canActivateNear(): Bool
    {
      return true;
    }

// update object actions
  override function updateActionList()
    {
      game.ui.hud.addAction({
        id: 'takeNecronomicon',
        type: ACTION_OBJECT,
        name: 'Take Necronomicon',
        energy: 0,
        obj: this
      });
    }

// complete the linked mission and remove book
  override function onAction(action: _PlayerAction): Bool
    {
      var mission = game.cults[0].ordeals.getMissionByID(missionID);
      if (mission != null &&
          !mission.isCompleted)
        mission.success();
      game.area.removeObject(this);
      game.log('You secure the Necronomicon into your possession. You can now proceed with the next phase.');
      return true;
    }
}

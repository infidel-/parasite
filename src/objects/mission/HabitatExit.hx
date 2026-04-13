// habitat exit object used in sewer-style habitat areas

package objects.mission;

import game.Game;
import objects.AreaObject;

class HabitatExit extends AreaObject
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
      imageCol = Const.FRAME_SEWER_EXIT;
      type = 'habitat_exit';
      name = 'sewer exit';
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
        id: 'leaveArea',
        type: ACTION_OBJECT,
        name: 'Leave area',
        energy: 0,
        isAgreeable: true,
        obj: this
      });
    }

// activate habitat exit and leave the area
  override function onAction(action: _PlayerAction): Bool
    {
      var ret = game.playerArea.leaveAreaAction(action);
      if (ret)
        game.scene.sounds.play('object-sewers');
      return ret;
    }

  public override function known(): Bool
    { return true; }
}

// special event object
// NOTE: infoID can change dynamically, always use link

package objects;

import scenario.Scenario;
import game.Game;
import game.Player;

class EventObject extends AreaObject
{
  public var infoID: String;

  public function new(g: Game, vaid: Int, vx: Int, vy: Int, name: String, infoID: String)
    {
      super(g, vaid, vx, vy);
      init();
      this.name = name;
      this.infoID = infoID;
      initPost(false);
    }

// init object before loading/post creation
  public override function init()
    {
      super.init();
      type = 'event_object';
      isStatic = true;
      imageCol = Const.FRAME_EVENT_OBJECT;
    }

// called after load or creation
  public override function initPost(onLoad: Bool)
    {
      super.initPost(onLoad);
    }


// update actions
  override function updateActionList()
    {
      var actions = game.timeline.scenario.eventObjectActions[infoID];
      for (info in actions)
        {
          var action: _PlayerAction = Reflect.copy(info.action);
          action.obj = this;
          game.ui.hud.addAction(action);
        }
    }


// handle special action
  override function onAction(id: String): Bool
    {
      var actions = game.timeline.scenario.eventObjectActions[infoID];
      for (info in actions)
        if (info.action.id == id)
          info.func(game, game.player, id);

      return true;
    }
}

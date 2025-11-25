// special event object
// NOTE: infoID can change dynamically, always use link

package objects;

import game.Game;

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
      // static event object actions
      var actions = game.timeline.scenario.eventObjectActions[infoID];
      if (actions != null)
        for (info in actions)
          {
            var action: _PlayerAction = Reflect.copy(info.action);
            action.obj = this;
            game.ui.hud.addAction(action);
          }
      // player inventory actions
      // called function returns a list of available player actions
      var func = game.timeline.scenario.eventObjectActionsFuncs[infoID];
      if (func != null)
        {
          var list = func(game, game.player);
          if (list != null)
            for (action in list)
              {
                action.obj = this;
                game.ui.hud.addAction(action);
              }
        }
    }


// handle special action
// returns true on successful action
  override function onAction(action: _PlayerAction): Bool
    {
      // static event object actions
      var actions = game.timeline.scenario.eventObjectActions[infoID];
      if (actions != null)
        for (info in actions)
          if (info.action.id == action.id)
            info.func(game, game.player, action.id);
      // player inventory actions
      // calling available action hook
      var func = game.timeline.scenario.eventObjectActionsHooks[infoID];
      if (func != null)
        return func(game, game.player, action);

      return true;
    }

  public override function known(): Bool
    { return true; }
}

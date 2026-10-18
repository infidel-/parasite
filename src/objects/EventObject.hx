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


// key the 3D view looks a glb prop up by: the scenario role and not the bare type, because every
// event object in the game shares the one type and they are not one object — a spaceship, its
// startup console and its parts slots are three different things.
//
// infoID IS MUTATED AT RUNTIME (spaceshipStart -> spaceshipSuccess -> spaceshipFailure as the
// mission resolves) and the prop batches are only rebuilt when an object is ADDED or REMOVED, so
// the key can change under a batch nobody is going to rebuild. That is harmless only while all
// three of those ids sit on ONE row of render.world.ObjModels.MODELS, which groups by model path —
// splitting them into separate rows would give a ship that vanishes the moment the mission ends,
// with nothing in the diff pointing at it
  public override function getModelKey(): String
    { return 'event_' + infoID; }

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

// can be activated when player is next to it?
//
// TRUE FOR EVERY EVENT OBJECT, because none of them is a thing you stand on. The crash-landing
// scenario's console and its three slots stand on the study pad's own unwalkable concrete
// (src/scenario/GoalsAlienCrashLanding.hx), one tile closer to the ship than the walkable ring, and
// the ship itself has always been unreachable — an object only usable from its own cell would be
// dead there rather than merely awkward. game.PlayerArea reaches the EIGHT neighbours, so a prop on
// a pad CORNER is worked from the ring cell facing it
  public override function canActivateNear(): Bool
    { return true; }
}

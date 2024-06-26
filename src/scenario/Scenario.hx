// base scenario class

package scenario;

import game.*;

class Scenario
{
  public var name: String; // scenario name
  public var startEvent: String; // scenario starting event
  public var playerStartEvent: String; // player start location event
  public var defaultAlertness: Int; // default location alertness

  public var names: Map<String, Array<String>>; // name templates
  public var flow: Map<String, EventInfo>; // scenario flow (map of events)
  public var goals: Map<_Goal, GoalInfo>; // scenario goals (link to static map)
  public var eventObjectActions: _EventObjectActionsList;
  public var eventObjectActionsFuncs: _EventObjectActionsFuncs;
  public var eventObjectActionsHooks: _EventObjectActionsHooks;
/// unneeded for now
//  public var onInit: Game -> Void;

  public function new()
    {
      name = 'unnamed scenario';
      startEvent = '';
      playerStartEvent = '';
      defaultAlertness = 0;
//      onInit = null;

      names = new Map();
      flow = new Map();
      goals = new Map();
    }
}


// scenario event

typedef EventInfo = {
  name: String, // event name
  ?next: String, // next event id
  ?nextOR: Map<String, Int>, // multiple next ids for OR with chances
  ?isHidden: Bool, // event hidden?
  ?notes: Array<String>, // event notes
  ?location: LocationInfo, // event location
  ?npc: Map<String, Int>, // event npcs (ai type is "<type>:<parent>")

  ?init: Timeline -> Void, // init function that runs when event is added to timeline
  ?onLearnNote: Game -> Int -> Void, // runs when player learns event note
  ?onLearnLocation: Game -> Void, // runs when player learns event location
}


// scenario location

typedef LocationInfo = {
  ?id: String, // unique location id (optional)
  ?type: _AreaType, // location type
  ?name: String, // location name template
  ?near: String, // location is near this event id
  ?sameAs: String, // location is copied over from this event id
  ?alertness: Int, // area alertness
}

typedef _EventObjectAction = {
  action: _PlayerAction,
  func: Game -> Player -> String -> Void,
}
typedef _EventObjectActionsFunc = Game -> Player -> Array<_PlayerAction>;
typedef _EventObjectActionsHook = Game -> Player -> _PlayerAction -> Bool;
typedef _EventObjectActionsList = Map<String, Array<_EventObjectAction>>;
typedef _EventObjectActionsFuncs = Map<String, _EventObjectActionsFunc>;
typedef _EventObjectActionsHooks = Map<String, _EventObjectActionsHook>;

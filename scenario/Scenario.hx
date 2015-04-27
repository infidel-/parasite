// base scenario class

package scenario;

class Scenario
{
  public var name: String; // scenario name
  public var startEvent: String; // scenario starting event
  public var playerStartEvent: String; // player start location event 
  public var defaultInterest: Int; // default location interest
  public var defaultAlertness: Int; // default location alertness 

  public var names: Map<String, Array<String>>; // name templates
  public var flow: Map<String, EventInfo>; // scenario flow (map of events)

  public function new()
    {
      name = 'unnamed scenario';
      startEvent = '';
      playerStartEvent = '';
      defaultAlertness = 0;
      defaultInterest = 0;

      names = new Map();
      flow = new Map();
    }
}


// scenario event 

typedef EventInfo = {
  name: String, // event name
  ?next: String, // next event id
  ?nextOR: Map<String, Int>, // multiple next ids for OR with chances
  ?isHidden: Bool, // event hidden?
  ?setVariables: Map<String, Dynamic>, // variables to set if this event happens
  // function that can set some variables
  ?setVariablesFunc: Void -> Array<{ key: String, val: Dynamic }>, 
  ?notes: Array<String>, // event notes
  ?location: LocationInfo, // event location
  ?npc: Map<String, Int>, // event npcs (ai type is "<type>:<parent>")
}


// scenario location

typedef LocationInfo = {
  ?id: String, // unique location id (optional)
  ?type: _AreaType, // location type
  ?name: String, // location name template
  ?near: String, // location is near this event id
  ?sameAs: String, // location is copied over from this event id
  ?alertness: Int, // area alertness
  ?interest: Int, // area interest
}


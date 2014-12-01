// base scenario class

package scenario;

class Scenario
{
  public var name: String; // scenario name
  public var startEvent: String; // scenario starting event
  public var playerStartLocation: String; // player starting location
  public var names: Map<String, Array<String>>; // name templates
  public var flow: Map<String, EventInfo>; // scenario flow (map of events)

  public function new()
    {
      name = 'unnamed scenario';
      startEvent = '';
      playerStartLocation = '';
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
  ?npc: Map<String, Int>, // event npcs
}


// scenario location

typedef LocationInfo = {
  ?id: String, // unique location id (optional)
  ?type: String, // location type
  ?name: String, // location name template
  ?near: String, // location is near this event id
  ?sameAs: String // location is copied over from this event id
}


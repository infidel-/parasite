// scenario event

package scenario;

class Event
{
  public var num: Int; // event number
  public var isHidden: Bool; // event hidden?
  public var id: String; // event id
  public var name: String; // event name
  public var notes: Array<EventNote>; // event notes 
  public var location: Location; // event location link (can be null)
  public var locationKnown: Bool; // event location known?
  public var npc: Array<NPC>; // event npcs 

  public function new(vid: String)
    {
      id = vid;
      name = 'unnamed event';
      notes = [];
      npc = []; 
    }
}


typedef EventNote = {
  var text: String; // note text
  var isKnown: Bool; // note known?
  var clues: Int; // amount of note clues known
}

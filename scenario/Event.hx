// scenario event

package scenario;

class Event
{
  public var id: String; // event id
  public var name: String; // event name
  public var notes: Array<{ text: String, isKnown: Bool }>; // event notes 

  public function new(vid: String)
    {
      id = vid;
      name = 'unnamed event';
      notes = [];
    }
}

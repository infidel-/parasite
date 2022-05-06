// area event type
package game;

import ai.AI;

@:structInit class AreaEvent extends _SaveObject
{
  static var _ignoredFields = [ 'ai' ];
  public var id: Int;
  public var ai: AI; // ai event origin - can be null
  public var objectID: Int; // area object event origin (-1: unused)
  public var details: String; // event details - can be null
  public var x: Int;
  public var y: Int;
  public var type: _AreaManagerEventType; // event type
  public var turns: Int; // turns left until the event
  public var params: Dynamic; // additional parameters

  public function new(id, ai, objectID, details, x, y, type, turns, params)
    {
      this.id = id;
      this.ai = ai;
      this.objectID = objectID;
      this.details = details;
      this.x = x;
      this.y = y;
      this.type = type;
      this.turns = turns;
      this.params = params;
    }
}

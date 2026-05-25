// UI events (open specific UI, display message, etc)
typedef _UIEvent = {
  var type: _UIEventType;
  var state: _UIState;  // new UI state
  @:optional var obj: Dynamic; // parameters
}

enum abstract _UIEventType(String) to String from String
{
  var UIEVENT_STATE = 'UIEVENT_STATE'; // change ui state (open window)
  var UIEVENT_HIGHLIGHT = 'UIEVENT_HIGHLIGHT'; // highlight menu button for this state
  var UIEVENT_FINISH = 'UIEVENT_FINISH'; // finish the game
}

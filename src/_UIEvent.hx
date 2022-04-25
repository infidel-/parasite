// UI events (open specific UI, display message, etc)
typedef _UIEvent = {
  var type: _UIEventType;
  var state: _UIState;  // new UI state
  @:optional var obj: Dynamic; // parameters
}

enum _UIEventType {
  UIEVENT_STATE; // change ui state (open window)
  UIEVENT_HIGHLIGHT; // highlight menu button for this state
  UIEVENT_FINISH; // finish the game
}

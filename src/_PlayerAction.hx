import game.Player;

typedef _PlayerAction = {
  var id: String; // action id
  var type: _PlayerActionType; // action type
  var name: String; // action name
  @:optional var canRepeat: Bool; // can be repeated continuously?
  @:optional var energy: Int; // energy to complete
  @:optional var obj: Dynamic; // bound object to act on
  // func that returns energy activation cost (should return < 0 if action is not available)
  @:optional var energyFunc: Player -> Int;
  @:optional var key: String; // keyboard shortcut
}

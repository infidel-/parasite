import game.*;

typedef _PlayerAction = {
  var id: String; // action id
  var type: _PlayerActionType; // action type
  var name: String; // action name
  @:optional var canRepeat: Bool; // can be repeated continuously?
  @:optional var energy: Int; // energy to complete
  @:optional var obj: Dynamic; // bound object to act on
  @:optional var item: _Item; // bound inventory item to act on
  // func that returns energy activation cost (should return < 0 if action is not available)
  @:optional var energyFunc: Player -> Int;
  @:optional var key: String; // keyboard shortcut
  @:optional var isAgreeable: Bool; // agreeable host will reduce cost to 1
  @:optional var isVirtual: Bool; // virtual actions do not pass time
  @:optional var f: Void -> Void; // action function to run
}

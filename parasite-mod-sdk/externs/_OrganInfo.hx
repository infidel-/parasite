// organ definition attached to an improvement (mirrors engine
// const.EvolutionConst.OrganInfo). present only on improvements that grow a
// physical organ on the host.

typedef _OrganInfo = {
  // organ display name shown in the evolution/organ UI
  var name: String;
  // organ description text
  var note: String;
  // genome-point cost to grow the organ
  var gp: Int;
  // optional: true marks the organ as a construction mold (placeable)
  @:optional var isMold: Bool;
  // optional bound player action granted while the organ is active
  @:optional var action: _PlayerAction;
  // optional: true if the organ's action has an activation timeout
  @:optional var hasTimeout: Bool;
  // optional callback fired when the organ is grown; receives the game and player
  @:optional var onGrow: game.Game -> game.Player -> Void;
  // optional callback fired when the organ's action runs; receives the game and
  // player, returns Bool success
  @:optional var onAction: game.Game -> game.Player -> Bool;
}

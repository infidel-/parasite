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
  // optional bound player action granted while the organ is active.
  // Dynamic: engine _PlayerAction shape — typed engine externs pending (§14)
  @:optional var action: Dynamic;
  // optional: true if the organ's action has an activation timeout
  @:optional var hasTimeout: Bool;
  // optional callback fired when the organ is grown.
  // Dynamic: receives engine (game, player) — typed engine externs pending (§14)
  @:optional var onGrow: Dynamic;
  // optional callback fired when the organ's action runs; returns Bool success.
  // Dynamic: receives engine (game, player) — typed engine externs pending (§14)
  @:optional var onAction: Dynamic;
}

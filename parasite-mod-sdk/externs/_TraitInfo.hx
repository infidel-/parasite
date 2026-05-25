// AI trait info shape (mirrors engine src/_TraitInfo.hx)
// supplied to ModContentApi.registerTrait.

typedef _TraitInfo = {
  // trait id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerTrait; collisions in same group = last-wins + log)
  var id: _AITraitType;
  // display name shown in cult member rosters, console, etc.
  var name: String;
  // one-line description shown in tooltips and the add-trait console help
  var note: String;
  // whether this trait counts as negative (affects random-trait pool filters)
  var isNegative: Bool;
  // optional one-shot effect applied when the trait is granted to an AI
  // (e.g. boost a skill, adjust base attributes)
  @:optional var onInit: (game: game.Game, ai: ai.AIData) -> Void;
  // optional per-turn tick run while the AI carries the trait
  // (e.g. addict withdrawal, flagellant self-heal)
  @:optional var turn: (game: game.Game, ai: ai.AIData) -> Void;
}

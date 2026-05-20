// evolution improvement info shape (mirrors engine
// const.EvolutionConst.ImprovInfo). supplied to ModContentApi.registerEvolution.

typedef _ImprovInfo = {
  // improvement id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerEvolution; id collision = last-wins + log)
  var id: _Improv;
  // category: TYPE_BASIC (leveled tree) or TYPE_SPECIAL (unique organ)
  var type: _ImprovType;
  // improvement display name shown in the evolution UI
  var name: String;
  // improvement description text
  var note: String;
  // highest level this improvement can reach (1-based; basic tree caps apply)
  var maxLevel: Int;
  // per-level description lines, indexed by level (length should cover maxLevel)
  var levelNotes: Array<String>;
  // per-level gameplay parameters, indexed by level; shape is improvement-
  // specific and read by the engine effect that consumes this improvement
  var levelParams: Array<Dynamic>;
  // optional advanced description builder.
  // Dynamic: engine (info, level) -> String — typed engine externs pending (§14)
  @:optional var noteFunc: Dynamic;
  // optional organ grown by this improvement (see _OrganInfo)
  @:optional var organ: _OrganInfo;
  // optional bound player action added while the improvement is owned.
  // Dynamic: engine _PlayerAction shape — typed engine externs pending (§14)
  @:optional var action: Dynamic;
  // optional callback fired when the improvement is upgraded.
  // Dynamic: receives (level, game, player) — typed engine externs pending (§14)
  @:optional var onUpgrade: Dynamic;
}

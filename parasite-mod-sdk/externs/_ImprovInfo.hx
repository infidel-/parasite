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
  // optional advanced description builder; receives (info, level) and returns
  // the description. Dynamic args mirror the engine signature, which leaves
  // both args untyped (info shape varies per improvement, level is an Int)
  @:optional var noteFunc: Dynamic -> Dynamic -> String;
  // optional organ grown by this improvement (see _OrganInfo)
  @:optional var organ: _OrganInfo;
  // optional bound player action added while the improvement is owned
  @:optional var action: _PlayerAction;
  // optional callback fired when the improvement is upgraded; receives the new
  // level, the game, and the player
  @:optional var onUpgrade: Int -> game.Game -> game.Player -> Void;
}

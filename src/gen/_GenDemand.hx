package gen;

// one entry of a quota: how many blocks of a kind an area must end up with, and what makes a rect a
// good home for one.
//
// THIS TYPE EXISTS BECAUSE DICE DO NOT SATISFY REQUIREMENTS. game.FacilityAreaGenerator
// .assignRoomThemes rolls `Std.random(100) < 60` for the washroom, so 40% of compounds have no
// washroom at all — not because anyone decided a compound might lack one, but because a roll was
// the easy way to express "usually". A quota says the thing that was meant: at least `min`, at most
// `max`, and here is how to pick which rect gets it.
typedef _GenDemand = {
  // the node kind dealt rects get. what gen.GenTree.build then looks a filler up by
  var kind: String;
  // how many of this kind the area MUST have. a quota that cannot be met is a generator bug and is
  // reported rather than silently dropped
  var min: Int;
  // and how many it may have at most, once every other demand's min is satisfied
  var max: Int;
  // the smallest rect that can hold one. a rect below either is never dealt this kind
  var minW: Int;
  var minH: Int;
  // how much this rect suits this kind, higher is better; ties break on rect area. this is where
  // "parking wants to touch the sidewalk", "the hangar wants the far side from the road" and "the
  // park would rather be a strip" live — one function per demand instead of a placement rule buried
  // in the middle of a filler. absent means every rect that clears minW/minH suits equally
  @:optional var fit: _GenNode -> Int;
  // and a HARD one: a rect this rejects can never take this kind, however well it scores.
  //
  // `fit` cannot express a requirement — it is a preference, and a preference loses to whatever was
  // dealt first. Measured: the facility's parking lot wants to touch the street frontage so its gate
  // can reach the pavement, and said so with `fit`. The two lab buildings are dealt ahead of it
  // (fewest legal homes goes first), they took both frontage plots, and 1 compound in 1000 came out
  // with its entry mouth opening onto a building wall. A `must` is counted by `homes` instead, so
  // the demand becomes the constrained one, gets dealt first, and a split that cannot house it is
  // re-rolled by the caller like any other unsatisfiable quota
  @:optional var must: _GenNode -> Bool;
}

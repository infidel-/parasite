// trait info
import game.Game;
import ai.AIData;

typedef _TraitInfo =
{
  var id: _AITraitType; // trait id
  var name: String; // trait name
  var note: String; // trait note
  var isNegative: Bool; // whether trait is negative
  @:optional var onInit: (game: Game, ai: AIData) -> Void;
  @:optional var turn: (game: Game, ai: AIData) -> Void;
}

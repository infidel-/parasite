// cult event choice definition

import game.Game;
import cult.Cult;

typedef _CultEventChoice = {
  var button: String;
  var text: String;
  var f: Game -> Cult -> Int -> Void;
}

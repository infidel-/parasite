import game.Game;
import game.Player;
import game.AreaGame;

typedef GoalInfo = {
  id: _Goal, // goal id
  ?isHidden: Bool, // is this goal hidden?
  ?isStarting: Bool, // goal received on game start?
  ?isOptional: Bool, // is this goal optional?
  name: String, // goal name
  note: String, // goal note (static part)
  ?noteFunc: Game -> String, // dynamic note function, called on display

  ?messageReceive: String, // message on receiving goal
  ?messageComplete: String, // message on goal completion
  ?messageFailure: String, // message on goal failure
  ?imageComplete: String, // image on goal completion
  ?imageFailure: String, // image on goal failure

  ?onTurn: Game -> Player -> Void, // called each turn while this goal is active
  ?onReceive: Game -> Player -> Void, // called on receive
  ?onComplete: Game -> Player -> Void, // called on completion
  ?onFailure: Game -> Player -> Void, // called on failure
  ?onEnter: Game -> Void, // called on entering area
  ?aiInit: Game -> ai.AI -> Void, // called in ai constructor
  ?leaveAreaPre: Game -> Player -> AreaGame -> Bool, // runs when player tries to leave any location, if false, player cannot leave
}

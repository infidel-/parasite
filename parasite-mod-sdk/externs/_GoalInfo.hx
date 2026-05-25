// goal info shape (mirrors engine GoalInfo). supplied to
// ModContentApi.registerGoal.

typedef _GoalInfo = {
  // goal id; mod-registered ids must start with `mod-<modID>-`
  // (prefix enforced at registerGoal; id collision = last-wins + log)
  var id: _Goal;
  // optional: true hides the goal from the goal list and suppresses its
  // received/completed/failed log lines (used for internal/"fake" goals)
  @:optional var isHidden: Bool;
  // optional: true grants this goal automatically at game start
  @:optional var isStarting: Bool;
  // optional: true marks the goal optional (side branch, not required to win)
  @:optional var isOptional: Bool;
  // goal display name shown in the goal list
  var name: String;
  // static goal note / hint text (shown when goal is selected)
  var note: String;
  // optional dynamic note builder, called on display; receives the game and
  // returns the note text
  @:optional var noteFunc: game.Game -> String;
  // optional message shown when the goal is received
  @:optional var messageReceive: String;
  // optional message shown when the goal is completed
  @:optional var messageComplete: String;
  // optional message shown when the goal is failed
  @:optional var messageFailure: String;
  // optional event image override shown with the completion message
  // (default derives from id: 'event/<id>_complete')
  @:optional var imageComplete: String;
  // optional event image override shown with the failure message
  @:optional var imageFailure: String;
  // optional callback fired each turn while the goal is active; receives the
  // game and player
  @:optional var onTurn: game.Game -> game.Player -> Void;
  // optional callback fired when the goal is received; receives the game and player
  @:optional var onReceive: game.Game -> game.Player -> Void;
  // optional callback fired when the goal is completed; receives the game and player
  @:optional var onComplete: game.Game -> game.Player -> Void;
  // optional callback fired when the goal is failed; receives the game and player
  @:optional var onFailure: game.Game -> game.Player -> Void;
  // optional callback fired when the player enters an area while goal active;
  // receives the game
  @:optional var onEnter: game.Game -> Void;
  // optional callback fired in the AI constructor for each spawned AI; receives
  // the game and the AI
  @:optional var aiInit: game.Game -> ai.AI -> Void;
  // optional gate run when the player tries to leave an area; return false to
  // block leaving. receives the game, player, and target area
  @:optional var leaveAreaPre: game.Game -> game.Player -> game.AreaGame -> Bool;
}

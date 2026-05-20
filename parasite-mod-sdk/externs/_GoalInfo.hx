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
  // optional dynamic note builder, called on display.
  // Dynamic: engine (game) -> String — typed engine externs pending (§14)
  @:optional var noteFunc: Dynamic;
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
  // optional callback fired each turn while the goal is active.
  // Dynamic: engine (game, player) -> Void — typed engine externs pending (§14)
  @:optional var onTurn: Dynamic;
  // optional callback fired when the goal is received.
  // Dynamic: engine (game, player) -> Void — typed engine externs pending (§14)
  @:optional var onReceive: Dynamic;
  // optional callback fired when the goal is completed.
  // Dynamic: engine (game, player) -> Void — typed engine externs pending (§14)
  @:optional var onComplete: Dynamic;
  // optional callback fired when the goal is failed.
  // Dynamic: engine (game, player) -> Void — typed engine externs pending (§14)
  @:optional var onFailure: Dynamic;
  // optional callback fired when the player enters an area while goal active.
  // Dynamic: engine (game) -> Void — typed engine externs pending (§14)
  @:optional var onEnter: Dynamic;
  // optional callback fired in the AI constructor for each spawned AI.
  // Dynamic: engine (game, ai) -> Void — typed engine externs pending (§14)
  @:optional var aiInit: Dynamic;
  // optional gate run when the player tries to leave an area; return false to
  // block leaving.
  // Dynamic: engine (game, player, area) -> Bool — typed engine externs pending (§14)
  @:optional var leaveAreaPre: Dynamic;
}

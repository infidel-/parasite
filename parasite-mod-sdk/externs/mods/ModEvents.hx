// per-mod event-subscription facade extern
// mirrors engine src/mods/ModEvents.hx public surface
// engine fires named events at hook sites; handlers are typed per event.
// no unsubscribe — mods cannot reload mid-session. handler throws are
// isolated + logged; they never break the engine hook site (turn loop, etc.)
package mods;

typedef ModEvents = {
  // turn:pre — fires at the start of each game turn, before the player acts
  // and before the turn counter increments
  function onTurnPre(handler: ModTurnEvent -> Void): Void;
  // turn:post — fires at the end of a fully-processed turn (after the counter
  // increments); skipped when the turn aborts early (game over, transition)
  function onTurnPost(handler: ModTurnEvent -> Void): Void;
  // area:enter — fires after the player enters an area
  function onAreaEnter(handler: ModAreaEvent -> Void): Void;
  // area:leave — fires as the player leaves an area (before the switch)
  function onAreaLeave(handler: ModAreaEvent -> Void): Void;
  // ai:spawn — fires when an AI actor is added to an area
  function onAISpawn(handler: ModAIEvent -> Void): Void;
  // ai:die-pre — fires inside AI.die() after the dead state is set but before
  // AreaGame.removeAI nulls ai.entity. Payload carries the still-live entity
  // ref (for icon snapshots) plus the attacker if combat-driven
  function onAIDiePre(handler: ModAIDiePreEvent -> Void): Void;
  // ai:die — fires when an AI actor dies in the current area (after the AI's
  // own onDeath() hook runs); area-mode only. ai.entity is already null here
  function onAIDie(handler: ModAIEvent -> Void): Void;
  // item:learn — fires when the player learns about an item (after the
  // item's info.onLearn() runs and the id is added to known items)
  function onItemLearn(handler: ModItemLearnEvent -> Void): Void;
  // game:finish-pre — fires from Game.finish() after the engine builds the
  // default finish text, before the UI window is shown. payload is mutable:
  // handlers may overwrite e.text and e.img to customize the game-over
  // screen. last handler wins; engine reads back e.text / e.img after dispatch
  function onGameFinishPre(handler: ModGameFinishPreEvent -> Void): Void;
}

// shared base for every mod-event payload; the engine sets `game`
// on every payload so method handlers can reach the live game without
// closing over init()'s parasite parameter. mods that also need their
// runtime (settings/api/host) must stash it on a static field at init()
typedef ModEventBase = {
  // the live engine game instance
  var game: game.Game;
}

// payload for turn:pre / turn:post
typedef ModTurnEvent = {
  > ModEventBase,
  // turn counter: pre = turn about to run, post = turn just completed
  var turn: Int;
}

// payload for area:enter / area:leave
typedef ModAreaEvent = {
  > ModEventBase,
  // the area being entered or left
  var area: game.AreaGame;
}

// payload for ai:spawn
typedef ModAIEvent = {
  > ModEventBase,
  // the AI actor that spawned
  var ai: ai.AI;
  // the area it was added to
  var area: game.AreaGame;
}

// payload for item:learn
typedef ModItemLearnEvent = {
  > ModEventBase,
  // the item the player just learned about
  var item: game._Item;
}

// payload for ai:die-pre — fired before AreaGame.removeAI nulls ai.entity
typedef ModAIDiePreEvent = {
  > ModEventBase,
  // the AI actor about to be removed from the area
  var ai: ai.AI;
  // the area it dies in
  var area: game.AreaGame;
  // live entity ref captured before removeAI nulls ai.entity; use this for
  // icon snapshots (imageName/ix/iy/isMaleAtlas live on the entity object)
  var entity: entities.AIEntity;
  // attack source if the death was combat-driven; null for organ decay, cult
  // cull, console kill, and effect ticks (Bleeding, BlackNoise, etc.)
  var attacker: Null<Attacker>;
}

// payload for game:finish-pre — fired before the game-over UI window.
// `text`, `img` and `filter` start with engine defaults; handlers may mutate
// them to override the message, event image and its grade on the finish screen.
typedef ModGameFinishPreEvent = {
  > ModEventBase,
  // 'win' or 'lose'
  var result: String;
  // mutable: finish-screen body text (engine default already filled in)
  var text: String;
  // mutable: event image key (engine default may be null on win)
  var img: String;
  // mutable: svg filter grading the image — 'lose' | 'alien' | 'cult'. null is
  // NOT ungraded: ui.Finish falls back to the 'lose' grade, so a mod swapping in
  // its own win image must set this or the image renders like a death screen
  var filter: String;
}

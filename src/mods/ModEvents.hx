// per-mod event-subscription facade exposed as parasite.events.
// records modID for error attribution; delegates to ModEventRegistry.
// typed handlers per event; no unsubscribe (mods can't reload mid-session).
package mods;

import game.AreaGame;
import game.Game;
import game._Item;
import ai.AI;
import entities.AIEntity;
import js.Browser.console;

class ModEvents
{
  var modID: String;

  function new(modID: String)
    { this.modID = modID; }

// subscribe to turn:pre — fires at the start of each game turn, before the
// player acts and before the turn counter increments
  public function onTurnPre(handler: ModTurnEvent -> Void): Void
    { sub(ModEventRegistry.TURN_PRE, cast handler); }

// subscribe to turn:post — fires at the end of a fully-processed turn (after
// the counter increment); skipped if the turn aborts early (game over, etc.)
  public function onTurnPost(handler: ModTurnEvent -> Void): Void
    { sub(ModEventRegistry.TURN_POST, cast handler); }

// subscribe to area:enter — fires after the player enters an area
  public function onAreaEnter(handler: ModAreaEvent -> Void): Void
    { sub(ModEventRegistry.AREA_ENTER, cast handler); }

// subscribe to area:leave — fires as the player leaves an area
  public function onAreaLeave(handler: ModAreaEvent -> Void): Void
    { sub(ModEventRegistry.AREA_LEAVE, cast handler); }

// subscribe to ai:spawn — fires when an AI actor is added to an area
  public function onAISpawn(handler: ModAIEvent -> Void): Void
    { sub(ModEventRegistry.AI_SPAWN, cast handler); }

// subscribe to ai:die-pre — fires inside AI.die() after the dead state is set
// but before AreaGame.removeAI nulls ai.entity. Payload carries the still-live
// entity ref (for icon snapshots) and the attacker if the death was combat-driven
  public function onAIDiePre(handler: ModAIDiePreEvent -> Void): Void
    { sub(ModEventRegistry.AI_DIE_PRE, cast handler); }

// subscribe to ai:die — fires when an AI actor dies in the current area
// (after the AI's own onDeath() hook runs); area-mode only
  public function onAIDie(handler: ModAIEvent -> Void): Void
    { sub(ModEventRegistry.AI_DIE, cast handler); }

// subscribe to item:learn — fires when the player learns about an item
// (after info.onLearn() runs and the id is added to known items)
  public function onItemLearn(handler: ModItemLearnEvent -> Void): Void
    { sub(ModEventRegistry.ITEM_LEARN, cast handler); }

// subscribe to game:finish-pre — fires from Game.finish() after the engine
// builds the default finish text, before the UI window is shown. payload is
// mutable: handlers may overwrite e.text and e.img to customize the game-over
// screen. last handler wins; engine reads back e.text / e.img after dispatch.
  public function onGameFinishPre(handler: ModGameFinishPreEvent -> Void): Void
    { sub(ModEventRegistry.GAME_FINISH_PRE, cast handler); }

// shared: record subscription + log on devtools console
  function sub(event: String, handler: Dynamic -> Void)
    {
      ModEventRegistry.subscribe(event, modID, handler);
      console.log('[mods] subscribe ' + event + ': ' + modID);
    }

// build a per-mod facade (records modID for logging/attribution)
  public static function forMod(modID: String): ModEvents
    return new ModEvents(modID);
}

// shared base for every mod-event payload; the engine sets `game`
// on every payload so method handlers can reach the live game without
// closing over init()'s parasite parameter. mods that also need their
// runtime (settings/api/host) must stash it on a static field at init()
typedef ModEventBase =
{
  // the live engine game instance
  var game: Game;
}

// payload for turn:pre / turn:post
typedef ModTurnEvent =
{
  > ModEventBase,
  // turn counter: pre = turn about to run, post = turn just completed
  var turn: Int;
}

// payload for area:enter / area:leave
typedef ModAreaEvent =
{
  > ModEventBase,
  // the area being entered or left
  var area: AreaGame;
}

// payload for ai:spawn
typedef ModAIEvent =
{
  > ModEventBase,
  // the AI actor that spawned
  var ai: AI;
  // the area it was added to
  var area: AreaGame;
}

// payload for item:learn
typedef ModItemLearnEvent =
{
  > ModEventBase,
  // the item the player just learned about
  var item: _Item;
}

// payload for ai:die-pre — fires before AreaGame.removeAI nulls ai.entity
typedef ModAIDiePreEvent =
{
  > ModEventBase,
  // the AI actor about to be removed from the area
  var ai: AI;
  // the area it dies in
  var area: AreaGame;
  // live entity ref captured before removeAI nulls ai.entity; use this for
  // icon snapshots (imageName/ix/iy/isMaleAtlas live on the entity)
  var entity: AIEntity;
  // attack source if the death was combat-driven; null for organ decay, cult
  // cull, console kill, and effect ticks (Bleeding, BlackNoise, etc.)
  var attacker: Null<Attacker>;
}

// payload for game:finish-pre — fired before the game-over UI window.
// `text` and `img` start with engine defaults; handlers may mutate them to
// override the message and event image shown on the finish screen.
typedef ModGameFinishPreEvent =
{
  > ModEventBase,
  // 'win' or 'lose'
  var result: String;
  // mutable: finish-screen body text (engine default already filled in)
  var text: String;
  // mutable: event image key (engine default may be null on win)
  var img: String;
}

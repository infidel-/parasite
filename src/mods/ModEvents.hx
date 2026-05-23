// per-mod event-subscription facade exposed as parasite.events.
// records modID for error attribution; delegates to ModEventRegistry.
// typed handlers per event; no unsubscribe (mods can't reload mid-session).
package mods;

import game.AreaGame;
import game.Game;
import game._Item;
import ai.AI;
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

// subscribe to item:learn — fires when the player learns about an item
// (after info.onLearn() runs and the id is added to known items)
  public function onItemLearn(handler: ModItemLearnEvent -> Void): Void
    { sub(ModEventRegistry.ITEM_LEARN, cast handler); }

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

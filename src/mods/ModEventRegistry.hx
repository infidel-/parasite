// runtime event bus backing store for mods.
// engine fires named events at hook sites; mods subscribe via
// parasite.events (ModEvents facade). no persistence, no removal.
package mods;

import js.Browser.console;

class ModEventRegistry
{
  // canonical event names; engine hook sites + facade share these
  public static inline var TURN_PRE = 'turn:pre';
  public static inline var TURN_POST = 'turn:post';
  public static inline var AREA_ENTER = 'area:enter';
  public static inline var AREA_LEAVE = 'area:leave';
  public static inline var AI_SPAWN = 'ai:spawn';

  // event-name -> ordered list of subscribers (mod load order)
  public static var subscribers: Map<String, Array<ModEventSub>> = new Map();

// register a handler for an event; modID recorded for error attribution
  public static function subscribe(event: String, modID: String,
      handler: Dynamic -> Void)
    {
      var list = subscribers.get(event);
      if (list == null)
        {
          list = [];
          subscribers.set(event, list);
        }
      list.push({ modID: modID, handler: handler });
    }

// fire an event: invoke each subscriber with payload, isolating throws so
// one bad handler cannot break the engine hook site (turn loop, etc.)
  public static function fire(event: String, payload: Dynamic)
    {
      var list = subscribers.get(event);
      if (list == null)
        return;
      for (sub in list)
        {
          try { sub.handler(payload); }
          catch (e: Dynamic)
            {
              console.error('[mods] event handler threw (' + sub.modID +
                ') on ' + event + ': ' + e);
#if electron
              try { HostBridge.logAppend('MOD EVENT THROW [' + sub.modID +
                '] ' + event + ': ' + e + '\n'); }
              catch (e2: Dynamic) {}
#end
            }
        }
    }
}

// one event subscription: owning mod + its handler
typedef ModEventSub =
{
  var modID: String;
  var handler: Dynamic -> Void;
}

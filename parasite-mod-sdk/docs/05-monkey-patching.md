# Monkey-patching & event hooks

Registration ([04](04-registering-content.md)) adds new content. To **change
existing behavior** — or to touch a table not yet wrapped by a registration API
— you patch engine classes directly. The mod realm has full access; there is no
capability boundary.

For common moments (turn boundaries, area transitions, AI spawns) you don't
need to patch at all — subscribe to an **event hook** instead (see
[Event hooks](#event-hooks) below). Patch when no hook covers what you need.

## Reaching a class

Engine classes live in `$hxClasses`, exposed to you as `parasite.hxClasses` (and
as the `window.parasiteHx` global the generated externs target). Index by the
dotted Haxe name:

```haxe
var AI: Dynamic = Reflect.field(parasite.hxClasses, 'ai.AI');
```

## Rewriting a method

Standard JS prototype rewrite. Capture the original if you want to wrap rather
than replace:

```haxe
public static function init(parasite: ModRuntime)
{
  var AI: Dynamic = Reflect.field(parasite.hxClasses, 'ai.AI');
  var orig = AI.prototype.someMethod;
  AI.prototype.someMethod = function(a, b)
    {
      // pre-hook
      var r = orig.call(js.Lib.nativeThis, a, b);   // call original
      // post-hook
      return r;
    };
}
```

`-dce no` (a required build flag) guarantees every engine symbol survives, so
the method you want to patch is present even if vanilla code never calls it.

## What survives engine re-init

The engine rebuilds derived const tables on each `Game.new()`. Whether your
change persists depends on *where* you make it:

| What you do                                            | Survives re-init? | Use when |
|--------------------------------------------------------|-------------------|----------|
| `parasite.api.registerItem(MyItem)` (and other `register*`) | yes          | adding new content (**preferred**) |
| Push onto an internal source list (e.g. `const.ItemsConst.classes`) | yes  | same, but couples to internal field names → fragile |
| Mutate a derived map entry (e.g. `infos['pistol']`)    | **no**            | never — lost on next re-init |
| Replace a source-list entry (`classes[0] = MyThing`)   | yes               | overriding a built-in id (no registration API for replace yet) |
| Monkey-patch a method (`ItemHandgun.prototype.fire`)   | yes               | changing built-in behavior — not registration's job |

The rule of thumb: **method patches and source-list edits persist; edits to
derived/computed state do not.** When in doubt, prefer the registration API for
content and method patches for behavior.

## Tables without a registration API yet

These const tables are not wrapped in v1 — patch them directly (push to their
source list at `init`, last-wins, your call to keep ids namespaced):

- chat data, jobs, AI faction sounds, world areas/regions.

For name generation and cultist scream-text, there is intentionally no content
API — patch the generator method (it's behavior, not a content table).

## Event hooks

`parasite.events` (type `mods.ModEvents`) lets you subscribe to engine moments
without patching. Each `on<Event>` takes a handler with a typed payload; the
engine fires it at the matching hook site. Handlers run in mod load order, and a
throw in one handler is caught, logged, and does **not** break the engine or
other handlers.

```haxe
public static function init(parasite: ModRuntime)
{
  // payload is typed — completion + checking on e.turn, e.area, e.ai
  parasite.events.onAISpawn(function(e) {
    trace('spawned ' + e.ai.id + ' in ' + e.area.id);
  });
  parasite.events.onTurnPre(function(e) {
    trace('turn ' + e.turn + ' starting');
  });
}
```

Five events ship currently:

| Method         | Event       | Fires                                                         | Payload (`mods.ModEvents`) |
|----------------|-------------|---------------------------------------------------------------|----------------------------|
| `onTurnPre`    | `turn:pre`  | start of each turn, before the player acts / counter bumps    | `ModTurnEvent { turn: Int }` |
| `onTurnPost`   | `turn:post` | end of a fully-processed turn; **skipped** if the turn aborts early (game over, scene transition) | `ModTurnEvent { turn: Int }` |
| `onAreaEnter`  | `area:enter`| after the player enters an area                               | `ModAreaEvent { area: AreaGame }` |
| `onAreaLeave`  | `area:leave`| as the player leaves an area (before the switch)              | `ModAreaEvent { area: AreaGame }` |
| `onAISpawn`    | `ai:spawn`  | when an AI actor is added to an area                          | `ModAIEvent { ai: AI, area: AreaGame }` |

Notes:

- **No unsubscribe.** Mods don't reload mid-session, so subscriptions live for
  the whole run — subscribe once in `init`.
- **Engine-defined names only.** You subscribe to the listed events; mods can't
  declare or fire their own event names yet. For mod-to-mod hooks, expose a
  function on your exported class and let other mods patch/call it.
- **Additive.** Events coexist with monkey-patching — use a hook where one fits,
  patch where it doesn't. A patch and a hook on the same moment both run.

Full field docs live in the extern: `externs/mods/ModEvents.hx`.

## Caution

You are editing live engine internals. Renames between game versions break
patches; that is what `Const.MOD_API_VERSION` and your manifest's
`modApiVersion` guard against (see [02-load-contract.md](02-load-contract.md)).
Wrapping the original (as above) rather than replacing it wholesale reduces how
much you depend on internal details.

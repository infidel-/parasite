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

Six events ship currently:

| Method         | Event        | Fires                                                         | Payload (`mods.ModEvents`) |
|----------------|--------------|---------------------------------------------------------------|----------------------------|
| `onTurnPre`    | `turn:pre`   | start of each turn, before the player acts / counter bumps    | `ModTurnEvent { turn: Int }` |
| `onTurnPost`   | `turn:post`  | end of a fully-processed turn; **skipped** if the turn aborts early (game over, scene transition) | `ModTurnEvent { turn: Int }` |
| `onAreaEnter`  | `area:enter` | after the player enters an area                               | `ModAreaEvent { area: AreaGame }` |
| `onAreaLeave`  | `area:leave` | as the player leaves an area (before the switch)              | `ModAreaEvent { area: AreaGame }` |
| `onAISpawn`    | `ai:spawn`   | when an AI actor is added to an area                          | `ModAIEvent { ai: AI, area: AreaGame }` |
| `onItemLearn`  | `item:learn` | after the player learns about an item (post `info.onLearn()`, id added to known items) | `ModItemLearnEvent { item: _Item }` |

Notes:

- **No unsubscribe.** Mods don't reload mid-session, so subscriptions live for
  the whole run — subscribe once in `init`.
- **Engine-defined names only.** You subscribe to the listed events; mods can't
  declare or fire their own event names yet. For mod-to-mod hooks, expose a
  function on your exported class and let other mods patch/call it.
- **Additive.** Events coexist with monkey-patching — use a hook where one fits,
  patch where it doesn't. A patch and a hook on the same moment both run.

Full field docs live in the extern: `externs/mods/ModEvents.hx`.

## Fx system

`parasite.fx` is a named registry plus low-level primitives. The engine owns
**dispatch + scheduling + the overlay div lifecycle**; the mod owns the actual
visual effect. The same surface lets any mod fire any other mod's registered
fx by id (cross-mod reuse) without poking `Browser.document` directly.

### Surface

| Call                                                              | What it does                                                              |
|-------------------------------------------------------------------|---------------------------------------------------------------------------|
| `parasite.fx.register(id, impl)`                                  | record an fx under `id` (must start with `mod-<modID>-`). `impl` is `{ play: Dynamic -> Void, ?stop: Void -> Void }`. |
| `parasite.fx.play(id, params)`                                    | look up and run the fx. Unknown id warns once and is a no-op. `params` is `Dynamic`; the impl decides its shape. |
| `parasite.fx.stop(id)`                                            | call the registered `stop()` hook, if any. Mods that compose with `tick` can use the optional channel to also cancel in-flight frames. |
| `parasite.fx.tick(durationMS, frameFn, ?onDone, ?channelID)`      | RAF-based scheduler. `frameFn(t)` runs each frame with `t` in `[0..1]`; `onDone()` fires once after `frameFn(1.0)`. If `channelID` is set, a re-play on the same channel cancels the in-flight tick. RAF pauses on tab blur and resumes on return. |
| `parasite.fx.canvas()`                                            | `Element` — the game `#canvas` (may be `null` before the scene exists).   |
| `parasite.fx.overlay()`                                           | `Element` — the engine-owned reusable fullscreen overlay div. Fixed-position, `pointer-events: none`, `z-index: 9999`, initial `opacity: 0`. Mods set their own styles each play; concurrent flashes from different mods stomp each other. |

### Pattern

Register at boot, fire later (from a weapon hook, an event, anywhere). The
`channelID` lets a re-play interrupt an in-flight tick instead of running
parallel frame loops, which is what you want for shake / flash / juice fx:

```haxe
parasite.fx.register('mod-mymod-shake', {
  play: function(p: Dynamic): Void
    {
      var c: Dynamic = parasite.fx.canvas();
      if (c == null) return;
      var ms: Int = p.durationMS;
      var px: Int = p.magnitudePX;
      parasite.fx.tick(ms, function(t: Float): Void
        {
          var decay = 1 - t;
          var dx = (Math.random() * 2 - 1) * px * decay;
          var dy = (Math.random() * 2 - 1) * px * decay;
          c.style.transform = 'translate(' + dx + 'px,' + dy + 'px)';
        }, function(): Void
        {
          c.style.transform = '';
        }, 'mod-mymod-shake');
    },
});

// later, on a hit:
parasite.fx.play('mod-mymod-shake', { durationMS: 500, magnitudePX: 8 });
```

The full chainsaw example (shake + colored fullscreen flash on player hits)
lives at `examples/chainsaw/src/Entry.hx`.

### Notes

- **Registration is global.** All mods share one id-keyed registry. The
  `mod-<modID>-` prefix on every id is what keeps mods from clobbering each
  other. Duplicate registration is last-wins + warns.
- **Replace-on-replay is opt-in.** A registry-level `play(id)` does **not**
  cancel an in-flight `play(id)` on its own; if you want that, pass your
  `id` as the `channelID` to `tick` (as above). Effects that don't use `tick`
  (pure CSS transitions, etc.) must coordinate state themselves.
- **No built-in fx.** The engine ships zero entries in the registry — every
  visible effect is somebody's mod, and the same registration surface lets
  mods discover and fire each other's fx.

Full field docs live in the extern: `externs/mods/ModFx.hx`.

## Caution

You are editing live engine internals. Renames between game versions break
patches; that is what `Const.MOD_API_VERSION` and your manifest's
`modApiVersion` guard against (see [02-load-contract.md](02-load-contract.md)).
Wrapping the original (as above) rather than replacing it wholesale reduces how
much you depend on internal details.

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

## Subclassing an engine class

Most engine externs are emitted as `@:native('window.parasiteHx[...]')` —
typed views onto live engine classes. You can `extends` them from mod code; Haxe
emits real prototype-chain inheritance against the engine's class object. The
engine's loops (item construction, particle draw loop, etc.) virtual-dispatch
through the prototype, so your overrides run without the engine needing to know
about your subclass.

Two patterns ship in `examples/chainsaw/`:

- `Chainsaw extends items.Weapon` — engine constructs it via `Type.createInstance`
  during `ItemsConst.init` (driven by `parasite.api.registerItem`).
- `ParticleBloodSpurt extends particles.Particle` — mod constructs it directly
  with `new`; the engine's `AreaView.drawParticles` loop picks up `draw` /
  `onDeath` overrides by virtual dispatch.

```haxe
class ParticleBloodSpurt extends particles.Particle
{
  public function new(s: GameScene, from: _Point, to: _Point)
    {
      super(s);
      time = 220;
      // ... precompute trajectory ...
      s.area.addParticle(this);
    }

  // engine calls this every ~10ms with dt ∈ [0..1]
  public override function draw(ctx: Dynamic, dt: Float) { /* draw blob */ }

  // engine calls this once when isDead() returns true
  public override function onDeath()
    {
      Particle.createSplat('red', scene, dstTile, srcTile);
    }
}
```

### Override signatures must match the *extern*, not the engine source

The SDK extern generator falls back to `Dynamic` for any type it cannot resolve
to a generated extern or a passthrough basic type. Browser DOM/canvas types
(e.g. `js.html.CanvasRenderingContext2D`) are **not** in the passthrough list,
so they appear as `Dynamic` in the generated extern. Your override must use
`Dynamic` for those parameters or the compiler rejects it as a signature
mismatch:

```
src/MyParticle.hx:43: Field draw overrides parent class with different or incomplete type
... error: js.html.CanvasRenderingContext2D should be Dynamic
```

Rule of thumb: when overriding, copy the parameter types from
`parasite-mod-sdk/externs-generated/<path>.hx`, not from the engine source. The
runtime type is whatever JS hands you — your local variables can still be typed
concretely inside the method body if you cast.

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

These events ship currently:

| Method         | Event        | Fires                                                         | Payload (`mods.ModEvents`) |
|----------------|--------------|---------------------------------------------------------------|----------------------------|
| `onTurnPre`    | `turn:pre`   | start of each turn, before the player acts / counter bumps    | `ModTurnEvent { turn: Int }` |
| `onTurnPost`   | `turn:post`  | end of a fully-processed turn; **skipped** if the turn aborts early (game over, scene transition) | `ModTurnEvent { turn: Int }` |
| `onAreaEnter`  | `area:enter` | after the player enters an area                               | `ModAreaEvent { area: AreaGame }` |
| `onAreaLeave`  | `area:leave` | as the player leaves an area (before the switch)              | `ModAreaEvent { area: AreaGame }` |
| `onAISpawn`    | `ai:spawn`   | when an AI actor is added to an area                          | `ModAIEvent { ai: AI, area: AreaGame }` |
| `onAIDiePre`   | `ai:die-pre` | inside `AI.die()` after dead state is set but **before** `AreaGame.removeAI` nulls `ai.entity`. carries the live entity ref + attacker (null for non-combat deaths) | `ModAIDiePreEvent { ai: AI, area: AreaGame, entity: AIEntity, attacker: Null<Attacker> }` |
| `onAIDie`      | `ai:die`     | when an AI dies in the current area (post `onDeath()` hook); area-mode only. `ai.entity` is already `null` here | `ModAIEvent { ai: AI, area: AreaGame }` |
| `onItemLearn`  | `item:learn` | after the player learns about an item (post `info.onLearn()`, id added to known items) | `ModItemLearnEvent { item: _Item }` |
| `onGameFinishPre` | `game:finish-pre` | inside `Game.finish()` after the engine builds the default finish text, before the UI window is shown. **mutable payload** — handlers may overwrite `e.text` / `e.img` to override the game-over screen | `ModGameFinishPreEvent { result: String, text: String, img: String }` |

Notes:

- **No unsubscribe.** Mods don't reload mid-session, so subscriptions live for
  the whole run — subscribe once in `init`.
- **Engine-defined names only.** You subscribe to the listed events; mods can't
  declare or fire their own event names yet. For mod-to-mod hooks, expose a
  function on your exported class and let other mods patch/call it.
- **Additive.** Events coexist with monkey-patching — use a hook where one fits,
  patch where it doesn't. A patch and a hook on the same moment both run.
- **`game:finish-pre` is the one mutable payload.** All other events are
  fire-and-forget; `game:finish-pre` reads `e.text` / `e.img` back from the
  payload after dispatch and sends them to the UI. Handlers run in mod load
  order, so later subscribers can stomp earlier ones — gate your overwrite on
  `e.result == 'lose'` (or a `e.text` match) if your mod isn't the only finish
  customizer in the load set.
- **`ai:die-pre` vs `ai:die`.** `ai:die-pre` runs first and is the only event
  that exposes the dying actor's entity (icon, sprite atlas, visibility) before
  the engine cleans it up. Use it when you need to read or snapshot visual
  state at the moment of death; use `ai:die` for plain bookkeeping (kill
  counters, journal updates) where you don't need the entity.

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

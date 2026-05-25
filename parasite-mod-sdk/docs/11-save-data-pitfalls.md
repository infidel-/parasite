# Save data pitfalls

`parasite.savedata` writes into a `Dynamic` bucket inside `game.modData` that
is serialized as part of the savegame (`Saver.save` → `Json.stringify`) and
restored on load. The engine enforces a JSON-safety contract on what you can
put in: most unsafe values are rejected at `set()` time with a descriptive
error. Two failure modes remain that the contract can't catch — silent shape
loss on reload, and post-set mutation — and this doc covers both, plus how to
test for them.

## What you can store

Anything `haxe.Json.stringify` round-trips intact:

- `Int`, `Float` (finite), `Bool`, `String`, `null`
- plain `Array<T>` of the above
- plain anonymous objects (`{ kills: 17, faction: 'cult' }`) nested arbitrarily
- combinations of the above

That covers every legitimate use of savedata: counters, flags, IDs, lists of
IDs, small structured records.

## What you cannot store

`set()` walks the value and throws if it finds any of these. The error
names the exact path (e.g. `'lastBoss.region'`) so you can pinpoint the
offending sub-value from the stack trace.

| Value                                  | `set()` behavior                                                                |
|----------------------------------------|---------------------------------------------------------------------------------|
| Cyclic structure (`o.self = o`)        | **throws** `cyclic structure detected`                                          |
| Reference to a live class instance — `parasite.game`, any `_SaveObject` (Cult, AI, Player, AreaGame, Region…), `haxe.ds.IntMap`/`StringMap`, `Date`, DOM node, your own Haxe classes | **throws** `cannot store live class instance (<ClassName>)` with a hint pointing at the lookup-by-id pattern below |
| Function / closure                     | **throws** `function references are not serializable`                           |
| `NaN`, `Infinity`, `-Infinity`         | **throws** `non-finite number`                                                  |
| Any other unrecognized type            | **throws** `unsupported type`                                                   |

Haxe enum values are allowed — the `Saver` wraps them with a `_classID`
marker and the `Loader` reconstructs them. Everything else that survives
`set()` is plain-data JSON.

The validation is the strongest line of defense. Catch a bad write at the
call site rather than learning about it at save time hours later, or
worse, on reload.

## What validation cannot catch

Two ways data can still go wrong:

1. **You mutate the value after `set()`.** `set` validates and stores by
   reference — if you keep the same object and later assign a function or
   a live class instance into one of its fields, the bucket now contains
   that bad value but `set` never saw the mutation.
2. **You bypass the API.** Writing directly into
   `parasite.game.modData[modID]` (or constructing a fresh `ModSaveData`
   facade and reaching into it) skips validation.

For both, the engine has a **save-time safety net**: `Saver.save` probes
each bucket with `Json.stringify` before writing the file. A bucket that
throws is dropped from the save with this log line:

```
Mod [com.you.mymod] save data dropped (unserializable): <error>
```

The rest of the save still writes — the player's slot is not lost — but
**your mod loses that save's worth of state**. On next load, `get` returns
`null` for every key in the dropped bucket.

### Identity loss (the silent one)

A snapshot of an engine object passes `Json.stringify` (no cycle) but on
reload comes back as a plain anonymous object with no class identity, no
methods, and a snapshot of fields frozen at save time. Equality checks
(`==`) against the live instance fail. Calling methods throws. The
save-time safety net does **not** catch this — only `set()`-time
validation does, by rejecting live class instances outright. If you've
been bypassing `set` (mutation after the fact, direct `modData` writes),
this trap is still open. Use the patterns below.

## How bad savedata breaks the mod on load

Even with the save-side safety net, a bad value can leave your mod broken
for the entire next session. Two failure modes:

- **Bucket was dropped at save.** On reload, every `get` returns `null` and
  every typed getter returns its `def`. Counters reset, flags lost, story
  state silently rewinds. Your mod doesn't crash — it just behaves as if
  the player started a fresh playthrough. The single warning at save time
  is the only signal.
- **Bucket survived but contains broken-shape data** (you stored a typed
  engine object, a function, a Map…). The value is back, but with the
  wrong shape — no methods, missing fields, Map shape mangled. When your
  code reads it and calls a method or accesses a typed field, the event
  handler throws. The engine catches it (`ModEventRegistry` wraps every
  handler in try/catch and logs `MOD EVENT THROW [<modID>] <event>: …`),
  so the game keeps running, but **your handler is dead for that session
  every time the event fires**. Console fills with throw lines.

`init` does **not** re-run on save load, so a broken-on-load mod cannot
self-heal until the player restarts the game. Test save/load before
shipping — the section below is the minimum.

## Pattern: store IDs, not objects

Instead of storing an engine object directly, store its `id` (or `uid`,
depending on the type) and re-resolve on read:

```haxe
// BAD — duplicates on reload, identity broken
parasite.savedata.set('favorite_cult', parasite.game.cults[2]);

// GOOD — round-trips as a number, look up fresh each read
parasite.savedata.set('favoriteCultID', parasite.game.cults[2].id);

// later, after load:
var id = parasite.savedata.getInt('favoriteCultID', -1);
var cult = parasite.game.getCultByID(id);
if (cult == null) return; // cult may no longer exist
```

Same rule for AIs (`area.getAI(uid)`), areas (`region.getXY` /
`region.getByID`), regions (`world.get(id)`), etc.

## Pattern: snapshots, not references

If you need to remember the **state** of an engine object at a point in
time, copy the fields you care about into a plain object yourself:

```haxe
var ai = parasite.game.area.getAIByUID(uid);
parasite.savedata.set('lastBoss', {
  name: ai.getName(),
  hp:   ai.health,
  x:    ai.x,
  y:    ai.y,
});
```

This survives reload as plain data. You lose live-link semantics by design
(the real AI may be gone after reload — that's the point).

## Testing checklist

Every mod that writes to `parasite.savedata` should be tested across a save
cycle. The bugs above all manifest on **reload**, not on first run, so a
mod that "works in the dev session" can still corrupt or lose data the
moment the player saves and reloads.

Minimum sanity test:

1. Start a new game with your mod enabled.
2. Drive your mod into a state where it has written savedata (kill an AI,
   trigger your event, etc).
3. Open the in-game console (`;` key) and dump your bucket:
   ```
   mods savedata com.you.mymod
   ```
   The bucket is printed to the **browser devtools console** as an
   interactive tree (open devtools with Ctrl-Shift-I). The in-game console
   prints a short pointer line confirming the bytes written. Use plain
   `mods savedata` (no arg) for a summary of every mod's bucket. Confirm
   the keys you expect are present and look reasonable.
4. **Save the game.** Watch the console for the `save data dropped`
   message — if it appears, you mutated a bucket after `set()` or wrote
   into `game.modData` directly (the save-time net caught what `set`
   couldn't).
5. Quit to menu (or restart the renderer with Ctrl-F5).
6. Load the slot.
7. Run `mods savedata com.you.mymod` again. Every key from step 3 should
   still be there with the same shape.
8. Exercise the mod again — counters increment from the loaded value,
   flags read as set, etc.

If step 4 fires the warning or step 7 shows missing/changed shape, you
have a value that's bypassing `set()` validation. Audit any code path
that touches `game.modData` directly or mutates objects after writing
them.

## See also

- [07-settings.md](07-settings.md#per-mod-savegame-data-parasitesavedata) —
  the `parasite.savedata` API itself.
- [03-runtime-object.md](03-runtime-object.md) — `parasite.savedata` vs
  `parasite.settings` (savegame-scoped vs cross-run).
- [09-console-reference.md](09-console-reference.md) — `mods savedata`
  command, for inspecting your bucket in a running game.

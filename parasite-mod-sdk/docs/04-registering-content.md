# Registering content

Adding new content — items, pedia entries, traits, skills, evolution
improvements, goals — goes through `parasite.api`. This is the **recommended**
way to add content, and the only way that is safe across game restarts.

## Why a registration API (not direct mutation)

Several engine const tables rebuild themselves from a source list on every
`Game.new()` (and on some console operations). If you mutate the *derived* table
directly (e.g. `ItemsConst.infos.set(...)`), your change is wiped the next time
the table re-inits. If you push onto the internal source list directly, you
couple your mod to engine field names that may be renamed.

The registration API sidesteps both: the engine consults built-in **plus**
registered lists every time it rebuilds, so your content survives re-init
without you touching internal fields. Registration is idempotent by
construction.

## The prefix rule (enforced)

**Every id you pass to any `register*` call must start with `mod-<modID>-`.**

For a mod with `id` `mymod`, valid content ids look like `mod-mymod-trinket`,
`mod-mymod-bravery`. Violations are **rejected at registration time** and logged
to the DevTools console and the session log — no silent accept. This namespaces
mod content and makes collisions traceable to a mod.

## Collisions

Within a content type, a duplicate id is **last-wins** and logged at every
re-init, so a conflict shows up at boot rather than mysteriously later. There is
no unregister or reorder API in v1 — to undo a mod's content, disable the mod.

## The API

`parasite.api` is `mods.ModContentApi`:

```haxe
typedef ModContentApi = {
  function registerItem(cls: Class<ItemInfo>): Void;
  function registerPediaEntry(info: _PediaGroupInfo): Void;
  function registerTrait(category: String, info: _TraitInfo): Void;
  function registerSkill(info: _SkillInfo): Void;
  function registerEvolution(info: _ImprovInfo): Void;
  function registerGoal(info: _GoalInfo): Void;
  function registerAI(type: String, cls: Class<AI>): Void;
  function registerAreaAction(id: String, fn: Game -> Void): Void;
}
```

Each info typedef is a curated extern under `externs/` — every field is
commented there. Below is one worked example per call; consult the extern for
the full field list and optional callbacks.

### registerItem

Items are classes, not records: subclass the engine `ItemInfo` extern and set
fields in the constructor.

```haxe
import mods.ModRuntime;

class MyItem extends ItemInfo
{
  public function new(game: Dynamic)
    {
      super(game);
      id = 'mod-mymod-trinket';
      type = 'misc';
      name = 'odd trinket';
      unknown = 'odd trinket';
    }
}

class Entry
{
  public static function init(parasite: ModRuntime)
    {
      parasite.api.registerItem(MyItem);
    }
}
```

Pass the **class**, not an instance — the engine instantiates it (with the game)
each time `ItemsConst` re-inits.

### registerPediaEntry

Registers a pedia group and its articles. Both the group id and every article
id must carry the prefix.

```haxe
parasite.api.registerPediaEntry({
  id: 'mod-mymod-group',
  name: 'My Mod',
  articles: [
    {
      id: 'mod-mymod-hello',
      name: 'Hello',
      text: 'Added at runtime via registerPediaEntry(). HTML is allowed.',
    },
  ],
});
```

Field reference: `externs/const/PediaConst.hx` (`_PediaGroupInfo`,
`_PediaArticleInfo`).

### registerTrait

Traits go into a named category. Built-in categories include `misc`, `skill`,
`mind`, `body`, `cultBasic`; you may also use a custom mod-defined group string.

```haxe
parasite.api.registerTrait('misc', {
  id: 'mod-mymod-bravery',
  name: 'brave',
  note: 'A marker trait with no mechanical effect.',
  isNegative: false,
});
```

`_TraitInfo` also has optional `onInit` and `turn` callbacks (one-shot on grant,
and per-turn) — see `externs/_TraitInfo.hx`.

### registerSkill

```haxe
parasite.api.registerSkill({
  id: 'mod-mymod-lockpicking',
  group: 'Combat',
  name: 'lockpicking',
  defaultLevel: 10,
});
```

Optional `isKnowledge` / `isBool` switch it to the knowledge UI section. See
`externs/_SkillInfo.hx`.

### registerEvolution

```haxe
parasite.api.registerEvolution({
  id: 'mod-mymod-thickskin',
  type: TYPE_BASIC,                 // or TYPE_SPECIAL for a unique organ
  name: 'thick skin',
  note: 'Tougher hide.',
  maxLevel: 2,
  levelNotes: [ 'tougher hide', 'thick hide', 'armored hide' ],
  levelParams: [ {}, {}, {} ],
});
```

`levelNotes` and `levelParams` are indexed by level and must cover `0..maxLevel`
— the evolution UI reads `levelNotes[level]`, so a too-short array crashes on
level-up. Optional `organ`, `action`, `onUpgrade` — see `externs/_ImprovInfo.hx`
and `externs/_OrganInfo.hx`.

### registerGoal

```haxe
parasite.api.registerGoal({
  id: 'mod-mymod-firstcontact',
  isStarting: true,                 // granted automatically at game start
  name: 'first contact',
  note: 'A marker goal with no mechanical effect.',
});
```

`_GoalInfo` carries a rich set of optional lifecycle callbacks (`onTurn`,
`onReceive`, `onComplete`, `onFailure`, `onEnter`, `aiInit`, `leaveAreaPre`) and
message/image overrides — see `externs/_GoalInfo.hx`.

### registerAI

Registers a custom AI subclass under a spawn **type string** (prefix-gated like
every other id). This does two things: injects the class into the engine class
registry so saved instances resolve on load (the loader rebuilds AIs by class
name), and records the type so `area.spawnAI(type, x, y)` /
`game.createAI(type, x, y)` can build it by string.

```haxe
class MyAI extends ai.HumanAI
{
  public function new(g: game.Game, vx: Int, vy: Int)
    { super(g, vx, vy); init(); initPost(false); }

  override public function init(): Void
    { super.init(); type = 'mod-mymod-myai'; isAggressive = false; }

  // public dynamic event hooks on ai.AI are real override points:
  override public function canAttach(): Bool { return false; }
  override public function onStateChange(): Void { /* ... */ }
}

class Entry
{
  public static function init(parasite: ModRuntime)
    {
      parasite.api.registerAI('mod-mymod-myai', MyAI);
      // later, in an area:
      parasite.game.area.spawnAI('mod-mymod-myai', x, y);
    }
}
```

Two reconstruction paths matter:

- **Spawn** (`spawnAI`/`createAI`) runs your real constructor.
- **Save load** runs `Type.createEmptyInstance` (no constructor) then `init()` +
  `initPost(true)`. So put identity in serialized fields (set in `init()`) and
  behavior in real override methods — both survive load; constructor-only state
  does not. See [05-monkey-patching.md](05-monkey-patching.md).

Set the same prefixed type both in `registerAI(...)` and in the instance's
`type` field (in `init()`) so lookups (`getAIWithType`, the `onAISpawn` event)
stay consistent. `examples/pickpocket` (the Burglar King) is a full reference.

### registerAreaAction

Contributes a player **area action** (the numbered actions in the HUD) without
patching the engine. Your callback runs at the tail of
`PlayerArea.updateActionList` on every HUD refresh: gate it yourself, then call
`game.ui.hud.addAction(...)`. The action self-dispatches through its
`_PlayerAction.f` callback, so no dispatch wiring is needed. The `id` is
prefix-gated and dedupes last-wins.

```haxe
class Entry
{
  public static function init(parasite: ModRuntime)
    {
      parasite.api.registerAreaAction('mod-mymod-action', contribute);
    }

  static function contribute(game: game.Game): Void
    {
      if (Std.string(game.player.state) != 'PLR_STATE_HOST')
        return; // your own gating
      game.ui.hud.addAction({
        id: 'mod-mymod-action',
        type: 'ACTION_AREA',
        name: 'Do Thing',
        energy: 0,
        isVirtual: true,        // virtual = does not auto-spend the turn
        f: function() run(game), // the action body
      });
    }
}
```

`examples/pickpocket` (the Pickpocket action) is a full reference.

## Verifying a registration

Read the derived table back through `hxClasses` to confirm your content landed:

```haxe
var ItemsConst: Dynamic = Reflect.field(parasite.hxClasses, 'const.ItemsConst');
trace(ItemsConst.infos.exists('mod-mymod-trinket'));   // true
```

`examples/testmod` exercises all six calls plus a deliberate
bad-prefix rejection for each — a useful reference.

## Not covered by registration (yet)

Replacing a built-in item id, changing built-in behavior, and tables not yet
wrapped (chat, jobs, AI sounds, world areas/regions) are not registration-API
operations. Use monkey-patching for those — see
[05-monkey-patching.md](05-monkey-patching.md). (Custom **AI types** are now
covered — see `registerAI` above.)

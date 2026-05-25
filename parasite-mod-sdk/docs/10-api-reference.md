# API reference (the externs)

There is no separately maintained API reference document — the **externs are the
reference**. They carry per-field doc comments and they are what you compile
against, so they can't drift from the real API. This page explains how the two
extern sets relate and how to read them.

## Two sets

```
parasite-mod-sdk/
  externs/             # hand-curated — the mod-facing API surface
  externs-generated/   # auto-generated from the engine — the full engine surface
```

`build.hxml` puts both on the classpath. **The curated set wins on overlap** —
where a type exists in both, the curated extern is authoritative and the
generated one is skipped.

### externs/ — curated mod API

Small, typed, every field commented. This is the surface designed for mods:

- `mods/ModRuntime.hx` — the `parasite` object ([03](03-runtime-object.md)).
- `mods/ModContentApi.hx` — `parasite.api` registration calls ([04](04-registering-content.md)).
- `mods/ModSettings.hx` — `parasite.settings` ([07](07-settings.md)).
- The content info typedefs you pass to `register*`: `_TraitInfo`, `_SkillInfo`,
  `_ImprovInfo`, `_OrganInfo`, `_GoalInfo`, and `const/PediaConst.hx`
  (`_PediaGroupInfo` / `_PediaArticleInfo`).

When you want to know exactly what fields a registration call accepts, open the
matching curated extern — the comments there describe each field's meaning,
valid range, and whether the engine sets it at runtime or you preset it.

### externs-generated/ — full engine surface

Auto-generated from the engine's `haxe --xml` dump (one extern per engine class,
plus a typedef per anonymous record). This is how you get types for the rest of
the engine — `game.Game`, `ai.AI`, the const tables, views, etc. — when
monkey-patching ([05](05-monkey-patching.md)) or walking `parasite.game`.

Doc comments are scraped from the engine source, so generated externs are as
documented as the engine code they mirror.

Limitations baked into the generator:

- **Module sub-types** (a type whose file name differs from its path) and
  **enum-abstracts** are skipped, so they resolve to `Dynamic`.
- A **blacklist** drops internal machinery mods never reference (pathfinding,
  console internals, lighting, map internals, mod-loader internals, the host
  bridge, version, and a few cult subsystems) — these also resolve to
  `Dynamic`.

A `Dynamic` result simply means no compile-time typing for that symbol; the code
still works (the JS object is real), you just don't get completion or checking.

## How the externs resolve at runtime

The engine's `$hxClasses` registry is local to its own IIFE, so a mod can't see
it by that name. Before importing any mod, the loader publishes
`window.parasiteHx = $hxClasses`. The externs target that global — each extern
is `@:native('window.parasiteHx.<ClassName>')` (or the bracket form for
package-path classes like `window.parasiteHx["game.Game"]`). That's why
`extends ItemInfo` compiles to JS that resolves to the real engine class at
module load.

## Regenerating (engine devs)

The generated set is produced by `parasite-mod-sdk/gen-externs/GenExterns.hx`,
driven by `make mod-sdk`, which wipes the output dir, regenerates, version-stamps
from `src/VERSION`, and zips the SDK for the game download. Mod authors never
regenerate — they consume the shipped zip.

## Symbol stability

`-dce no` keeps every engine symbol alive, and classes register in `$hxClasses`
by their dotted package path. As long as engine package paths are stable, the
externs keep resolving. A rename is a breaking change → the engine bumps
`Const.MOD_API_VERSION` and you bump your manifest to match
([02](02-load-contract.md)).

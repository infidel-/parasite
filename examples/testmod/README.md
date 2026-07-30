# testmod — worked example

A fuller example than the `template/` hello-world. `src/Entry.hx` exercises
every mod content API plus settings, asset overrides, and event hooks, with a deliberate
bad-prefix rejection after each registration to demonstrate the `mod-<modID>-`
prefix enforcement. On boot it logs each check to the DevTools console.

What it covers:

- `registerItem` — a custom `ItemInfo` subclass.
- `registerPediaEntry` — a pedia group + article.
- `registerTrait` / `registerSkill` / `registerEvolution` / `registerGoal`.
- `parasite.settings` — a boot counter persisted across launches.
- `AssetPath.resolve` — asset overrides (`assets/img/parasite-large.png`,
  `assets/sound/action-fail.mp3`).
- `parasite.events` — subscribes to all 5 event hooks (`turn:pre`/`turn:post`/
  `area:enter`/`area:leave`/`ai:spawn`); each logs once on first fire.

The compiled `entry.js` is included so you can see the build output without
compiling.

## Building this example

> **Heads-up: `build.hxml` paths are repo-relative.** As shipped in the SDK zip
> they will not resolve. The `-cp` lines point at
> `../../parasite-mod-sdk/externs` and `../../parasite-mod-sdk/externs-generated`,
> which is correct only when this folder sits inside the game source repo.
> Building from an unzipped SDK requires fixing them to point at wherever you
> unzipped the SDK's `externs/` and `externs-generated/` (e.g. `../../externs`
> and `../../externs-generated` if `examples/testmod/` sits at the SDK root).

Other notes:

- `.workshop-id` is intentionally **not** shipped — the publish tool creates one
  for your own Workshop item on first publish (see
  [../../docs/08-publishing.md](../../docs/08-publishing.md)). The `Makefile`
  `install` target copies `.workshop-id`; either create one or drop that token
  from the copy line for a local dev install.
- `Makefile` `DEST` points at a repo-relative `dev/` dir — set it to your own
  install's `dev/testmod/`.

For the full workflow, start at
[../../docs/01-getting-started.md](../../docs/01-getting-started.md).

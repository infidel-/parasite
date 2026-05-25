# Publishing to Steam Workshop

Mods are published with a standalone Node script, `publish-workshop.js`. It
wraps `steamworks.js` directly — the game process is not involved in publishing.

## Where the tool is

The script ships **inside the game install**, beside the bundled
`steamworks.js`:

```
<game>/resources/app/tools/publish-workshop.js
<game>/resources/app/node_modules/steamworks.js   # resolved automatically
```

Run it from there so `require('steamworks.js')` resolves against the app's
`node_modules`. You don't install any dependencies yourself — the game download
already includes them.

```sh
cd <game>/resources/app
node tools/publish-workshop.js <mod-dir> [itemId]
```

- `<mod-dir>`: absolute or relative path to your mod folder (must contain `manifest.json`).
- `[itemId]`: optional explicit Workshop item id. If omitted, the script reads
  `<mod-dir>/.workshop-id`; if that's absent too, it creates a new item and
  writes the new id into `.workshop-id`.

## Requirements

- The **Steam client running and logged in**.
- The mod dir must contain a valid `manifest.json`.

If Steam isn't running/logged in, `steamworks.init` fails and the script exits
with a clear message.

## What it reads from the manifest

The publish tool uses these manifest fields:

- `name` → Workshop item title (falls back to `id`, then `"Untitled mod"`).
- `description` → Workshop item description (optional).

The whole mod directory is uploaded as the item content. The change note is
generated automatically (a timestamp).

## Item id stamping

The Workshop item id is stored in `<mod-dir>/.workshop-id` (a plain text file),
**not** in `manifest.json`. On first publish the script creates the item and
writes the id there; subsequent runs reuse it. Commit `.workshop-id` with your
mod and don't hand-edit it. Don't share one id across forks — each fork should
get its own item.

## Visibility

New items are created **Unlisted** (`visibility=3`): only you can see them until
you change visibility on the item's Steam Community page. The script does not
change visibility on later updates.

## Restricting the update payload

By default an update sends all available fields. To limit it, pass `--fields=`
with a comma-separated subset (content is always uploaded):

```sh
node tools/publish-workshop.js /path/to/mymod --fields=title,description
```

Valid field names: `title`, `changeNote`, `description`, `visibility`.

## Legal agreement

The first time you publish under an account, Steam may require you to accept the
Workshop legal agreement. If `createItem` reports this, the script prints the
item URL and exits — open the URL, accept the agreement, then **re-run** the
command. The item id is already stamped, so the re-run continues straight to the
upload.

## Transient errors after create

Right after `createItem`, Steam's backend can take ~10–30s to settle, during
which the update call may report "method busy" or "a parameter is invalid". The
script retries those automatically (up to 3 times with backoff) before failing.

## On success

The script prints the subscribe URL and the Community page URL for the item.

# Steam release (SteamPipe, Windows steamcmd)

`make steam-upload` builds and uploads with the steamcmd in `C:\steamcmd` (login cached in its
`config\config.vdf`, account name in the untracked `.steam-user`). The template is
[`tools/steam-app-build.vdf`](../tools/steam-app-build.vdf); the filled copy lands in `C:\steamcmd\scripts\`,
logs and manifests in `C:\steamcmd\output\`.

## Depots
- app `1920320`. `1920321` common: the game. `1920322` windows: Electron runtime. `1920323` linux: Electron runtime.
- Branches: `default` and `staging` (password protected, for testing a build before it goes live).

## Where the files come from
- `resources/app` and `mod-sdk/parasite-mod-sdk-<VERSION>.zip`: straight from the dev dir (the `parasite`
  symlink's target). The release build IS the `make` build; the target rebuilds and refuses on uncommitted `src`/`electron`.
- `changes.md` at the install root: the repo's changelog, copied into the dev dir by every `make`.
- `icons.txt`, `sounds.txt`, `dev/placeholder`, `mods/placeholder` and the Windows runtime: `_Build_/common`
  and `_Build_/windows` under `C:\YandexDisk\PC LIGHTSTAR\Projects\Parasite\`.
- Dev-only files in `app/` are cut by `FileExclusion` (the old steamworks.js, the pickpocket example mod's sounds,
  `md-to-steam.js`). A new one gets a new exclusion.

## Releasing
1. Bump `src/VERSION`, commit, `make mod-sdk`.
2. `make steam-upload preview=1`, then read "Changes to baseline manifest" in `C:\steamcmd\output\depot_build_1920321.log`.
   Every Added/Changed/Removed line must be expected.
3. `make steam-upload branch=staging`.
4. yuggoth: Properties → Betas → `staging`, update, launch ([`test-box.md`](test-box.md)).
5. Steamworks → Builds → set the build live on `default`. steamcmd cannot set the default branch live.
   Then switch yuggoth back to no beta.

## Demo
- app `1982220`, content depot `1982221` (only `resources/app`; the runtime depot is never listed and carries over).
  `make steam-demo-upload [preview=1] [branch=staging]` builds the dev dir with `-D demo`, uploads it with
  [`tools/steam-demo-build.vdf`](../tools/steam-demo-build.vdf), then rebuilds the full game into the dev dir.
- What `-D demo` does: ends at 500 turns or on receiving "Find your ship" (`Game.finishDemo`), no cult can be founded
  (`Chat.canRecruit`), military bases refuse entry with a "full game only" region tag (`PlayerRegion.enterAreaAction`,
  `RegionTooltip`), no Group director goal (it points into a base), no military clue sheet load (`Images.loadDecoPacks`).
- What the depot leaves out, by `FileExclusion`: every `lab/`, `military/` and `img/cult/` dir, `ambient-military`
  (~260 MB of 778). Nothing a demo player can reach loads them: a demo tour of boot, facility, corp, city and
  wilderness made 601 requests, none into those dirs. A new dir with one of those names is cut too. The excluded
  dirs still ship EMPTY: `FileExclusion` drops files, not folders.
- Measured, first steamcmd build (1.0.2 over the 0.23.1 web zip, preview): ~505 MB scanned, 572 files added (215 MB),
  14 changed, 14 removed — the old 64 px atlases, the stale hud pngs, `ambient-military1.mp3` and the zip's folder entries.
- The Electron main inits Steam with the `SteamAppId` Steam launches it with, so the demo registers as 1982220.
- Releasing: `preview=1` and read `depot_build_1982221.log`, then `branch=staging` and test on yuggoth, then set it
  live on `default` on the Steamworks site, the same as the game.
- Up to 0.23.1 the demo was a web-uploaded zip of `_Build_/common-demo`, copied over and never wiped.

## itch.io
`make itch-zips` → `_Build_/parasite-<VERSION>-win32.zip` / `-linux64.zip`, the same files as the Steam depots
(checked by SHA1 against the steamcmd manifests for 1.0.1). `make itch-push [dry=1]` pushes them with butler
(`C:\butler`, logged in) to `starinfidel/parasite:windows` / `:linux`, with `--userversion` from `src/VERSION`. The first
push of a channel is full, later ones only the changes. The pre-butler web uploads are not channels; hide or delete
them after the first push. The zips are made from WSL, so
`Parasite`, `chrome-sandbox` and `chrome_crashpad_handler` carry exec bits; the Windows-made zips up to 0.24 had none.

## Measured (1.0.1, 2026-10-28)
- **Only the delta goes up, even from an empty cache**: steamcmd pulls the live manifest from Steam as the
  baseline. 1.0.1 sent 10.2 MB; the web zip for 1.0 was 732 MB. The baseline is the DEFAULT branch's build,
  not the last staging one: a second staging upload is again diffed against default.
- **Depots left out of the script carry over**: Steam builds the listed depots, then MERGES that build into the
  previous one ("Merged build 26279082 into build 26184037"), so the result keeps all three depots.
  That is why linux is never listed. An unchanged listed depot logs "Previous manifestID reused, no chunks uploaded".
- **Never build the linux depot from Windows**: Windows steamcmd writes flag 0 on every file, with no
  executable flag (0x20), so the Linux binaries would land non-executable. It changes only on an Electron upgrade.
- The web-zip builds carried explicit folder entries; the first steamcmd build logs them as "Removed".
  This is harmless and was verified on yuggoth (files intact, md5 match).

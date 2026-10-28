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

## itch.io
`make itch-zips` → `_Build_/parasite-<VERSION>-win32.zip` / `-linux64.zip`, the same files as the Steam depots
(checked by SHA1 against the steamcmd manifests for 1.0.1). Upload them on itch by hand. They are zipped from WSL, so
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

# Test box: yuggoth (Windows 11 laptop)

The dev box runs Windows 10. Bugs that only show on Windows 11 get tested on yuggoth. The Alt+Tab ghost entries were the first: Chromium's own fullscreen leaks them into the Windows 11 switcher, while Windows 10 shows nothing.

## Access
- `ssh yuggoth` / `scp ... yuggoth:...` — the `~/.ssh/config` entry points at 192.168.8.15, **port 2222**, user `mmm`, key `~/.ssh/id_ed25519_local`. Port 22 times out.
- You land in yuggoth's WSL. **Its login shell is fish**, which chokes on globs and nested quotes in a remote command. Wrap anything non-trivial: `ssh yuggoth "bash -c '...'"`.
- Windows tools work by full path, e.g. `/mnt/c/Windows/System32/tasklist.exe /FI "IMAGENAME eq Parasite.exe"` to see whether the game is running.

## The install
- The Steam build lives at `/mnt/c/Steam/steamapps/common/Parasite/`. The Steam library is at `C:\Steam`, not Program Files; there is a second one at `D:\SteamLibrary`. `appmanifest_1920320.acf` holds the `buildid`.
- The layout matches the dev build: the game files are in `resources/app/`.
- It runs in release mode, with no `.debug` and no `.steam-disabled`, so Steam and the overlay are live.
- There is no `--remote-debugging-port`, so nothing on yuggoth can be driven over CDP. Testing there is by hand.
- `settings.json` only exists once the options have been saved. Until then the game starts with the defaults, fullscreen included.

## Pushing a build
1. Build: `make main` for `main.js`/`preload.js`, `make -C src` for `parasite.js`.
2. Close the game on yuggoth. Main-process files are read only at launch.
3. **Diff before you overwrite.** Copy the installed file to the scratchpad (`scp yuggoth:<install>/resources/app/main.js <scratch>/`) and `diff` it against `app/`. Push only when the diff is your change and nothing else. The installed build has to match the tree the new files came from, assets included.
4. Back up once: `ssh yuggoth "bash -c 'mkdir -p ~/parasite-bak && cp -n <files> ~/parasite-bak/'"`. `-n` keeps the first, pristine copy.
5. Push: `scp app/main.js app/preload.js app/parasite.js yuggoth:/mnt/c/Steam/steamapps/common/Parasite/resources/app/`. Then compare `md5sum` on both ends.
6. Undo: Steam → Parasite → Properties → Installed Files → Verify integrity, or copy the files back from `~/parasite-bak`. A Steam update also overwrites anything you pushed.

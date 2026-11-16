.DEFAULT_GOAL := game-debug

# the out-of-repo folders and the haxe port (see its header: quote every path use, the Yandex ones hold a space)
include env
# stop before any command if env lost a key: an empty path would turn "$(X)/" into "/"
$(foreach k,HAXE_PORT BUILD OBSIDIAN_REPORTS RELEASE_KIT,$(if $($(k)),,$(error env: $(k) is empty)))

.PHONY: game-debug testmod main test fixture report loc loc-probe loc-build mod-sdk steam-docs steam-vdf steam-upload steam-demo-upload itch-zips itch-push soviet soviet-preview sshot reload reload-load git-diff tex adopt model-deps models model-export ai gen sounds entities

game-debug:
	cd src && $(MAKE) electron

# headless area generation: build bin/genrun.js and run the structural checks over N seeds, with no
# Electron, no renderer and no save. The oracle for any generator change -- run it BEFORE reaching
# for the game. See docs/area-gen.md.
# usage: make gen [seeds=3000] [args="--print --stats"]
gen:
	cd src && haxe project_gen.hxml
	node tools/genrun.mjs --count $(or $(seeds),3000) $(args)

# headless game tests: the real game logic under node with no renderer, played by bots. The quick
# cut runs on every `cd src && make`; this is the full soak. See tests/README.md.
# usage: make test [args="--suite smoke --seed 7 --count 1"]
test:
	cd src && haxe project_test.hxml
	timeout 3600 node tools/test.mjs $(args)

# pack a save slot as a test fixture: $(BUILD)/saveNN.json -> tests/saves/<name>-v<VERSION>.json.gz
# (-n: no name or time in the gzip header, so one save packs to the same bytes). Then add its row
# to tests/README.md. usage: make fixture name=<what-it-is> slot=<NN>
fixture:
	@test -n "$(name)" -a -n "$(slot)" || { echo "usage: make fixture name=<what-it-is> slot=<NN>"; exit 1; }
	gzip -n -9 -c "$(BUILD)/save$(slot).json" > tests/saves/$(name)-v$$(cat src/VERSION).json.gz
	@echo "added tests/saves/$(name)-v$$(cat src/VERSION).json.gz: add its row to tests/README.md"

# dev: screenshot the running game over CDP -> sshot.jpg (game must run on debug port 9300)
sshot:
	node sshot.mjs

# dev: reload the running renderer over CDP to pull in fresh build artifacts (debug port 9300)
reload:
	node reload.mjs

# dev: reload AND carry on through the boot — waits out the warm, answers the autosave offer and
# returns once the first frame presented, so the hooks (__facility(), __wild(), __check) and
# `make sshot` see a built area instead of the main menu. usage: make reload-load [slot=1]
reload-load:
	node reload.mjs --load $(slot)

# dev: show working-tree diff (stat + full) without a pager
git-diff:
	@git --no-pager diff --stat HEAD
	@echo ---
	@git --no-pager diff HEAD
	@git --no-pager status --short

# 3D street-view texture pipeline: downscale/bake $(TEXTURES_SRC) 1024px sources
# straight into the app dir (app/textures/, per art/textures.json). the sources live in the
# asset store and are NOT committed, the manifest IS.
tex:
	python3 tools/textures.py

# sound pipeline: $(SOUNDS_SRC)/<area>/*.wav (fal-sfx MCP takes) -> app/sound/<name><N>.mp3, mono,
# one static gain to the manifest's LUFS, loops seamed. never touches a sound it did not make.
# the wavs live in the asset store and are NOT committed, art/sounds.json IS
sounds:
	python3 tools/sounds.py

# the 128 px entities sheet: the original kra/png art under $(ASSETS_SRC) (and the generated sheets
# in textures-src/img/entities128/) -> app/img/entities128.png
entities:
	python3 tools/entities128.py

# adopt freshly generated gpt drops into textures-src/ without baking
adopt:
	python3 tools/textures.py --rename

# AI sprite pipeline: profession SVGs -> partial 128px gender atlases.
ai:
	node tools/ai.mjs

# 3D model pipeline: one-time install of the node bake tooling (gltf-transform + meshopt + sharp)
model-deps:
	npm --prefix tools install

# 3D model pipeline: decimate + shrink embedded textures of $(MODELS_SRC) .glb sources
# straight into app/models/ (per art/models.json). the sources live in the asset store and are NOT
# committed, the manifest IS.
models:
	node tools/models.mjs

# dump a source glb's embedded textures to models-src/ (base -> <label>-base.png etc) for authoring
# an emissive/edited map off them. usage: make model-export label=street-lamp
model-export:
	node tools/models.mjs --export $(label)

testmod:
	cd examples/testmod/ && $(MAKE)

chainsaw:
	cd examples/chainsaw/ && $(MAKE)

# build the soviet UI overhaul mod and stage it into $(BUILD)/dev/soviet/
soviet:
	cd examples/soviet/ && $(MAKE)

# stage the standalone browser preview into $(BUILD)/soviet/
soviet-preview:
	mkdir -p "$(BUILD)/soviet"
	cp examples/soviet/preview/index.html "$(BUILD)/soviet/index.html"
	cp examples/soviet/preview/style.css  "$(BUILD)/soviet/style.css"
	cp examples/soviet/preview/app.js     "$(BUILD)/soviet/app.js"

pickpocket:
	cd examples/pickpocket/ && $(MAKE)

main:
	cd electron && $(MAKE)

steam-docs:
	node electron/tools/md-to-steam.js parasite-mod-sdk/docs "$(BUILD)/docs-steam"

# fill a Steam build script's placeholders (tools/steam-<vdf>-build.vdf) into out=, by default the steamcmd
# scripts dir steam-upload / steam-demo-upload hand to steamcmd. it writes the vdf and nothing else, so it is
# the safe way to check one (never `make -n` the upload targets: their $(MAKE) lines run under -n).
# usage: make steam-vdf vdf=app|demo [out=x.vdf] [preview=1] [branch=staging]
steam-vdf:
	@test "$(vdf)" = app -o "$(vdf)" = demo || { echo "usage: make steam-vdf vdf=app|demo [out=x.vdf]"; exit 1; }
	sed -e "s/@DESC@/$$(cat src/VERSION)/g" \
	  -e "s/@PREVIEW@/$(or $(preview),0)/" \
	  -e "s/@BRANCH@/$(branch)/" \
	  -e "s/@DEVDIR@/$$(basename "$(BUILD)")/g" \
	  tools/steam-$(vdf)-build.vdf > "$(or $(out),/mnt/c/steamcmd/scripts/app_build_$(if $(filter app,$(vdf)),1920320,1982220).vdf)"

# upload the game to Steam with the Windows steamcmd in C:\steamcmd (login cached, name in .steam-user);
# only changed chunks go up. needs `make mod-sdk` for this version first. the default branch is set
# live on the Steamworks site, never from here.
# usage: make steam-upload [preview=1] [branch=staging]
steam-upload:
	git diff --quiet HEAD -- src electron || { echo 'uncommitted src/electron changes'; exit 1; }
	$(if $(allow-stale),,python3 tools/loc/extract.py --strict || { echo 'untranslated strings in a shipped language (listed above); translate them (make loc) or pass allow-stale=1'; exit 1; })
	test -f "$(BUILD)/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip"
	$(MAKE) game-debug main
	mkdir -p /mnt/c/steamcmd/scripts
	$(MAKE) steam-vdf vdf=app
	/mnt/c/steamcmd/steamcmd.exe +login $$(cat .steam-user) \
	  +run_app_build 'C:\steamcmd\scripts\app_build_1920320.vdf' +quit

# upload the demo (app 1982220) the same way: the dev dir rebuilt with -D demo, its resources/app minus
# the lab/military/cult art (tools/steam-demo-build.vdf), then the full build put back whatever steamcmd did.
# that restore is a plain `make`: a recipe line naming $(MAKE) runs even under `make -n`, steamcmd with it.
# usage: make steam-demo-upload [preview=1] [branch=staging]
steam-demo-upload:
	git diff --quiet HEAD -- src electron || { echo 'uncommitted src/electron changes'; exit 1; }
	$(MAKE) -C src electron-demo
	$(MAKE) main
	mkdir -p /mnt/c/steamcmd/scripts
	$(MAKE) steam-vdf vdf=demo
	/mnt/c/steamcmd/steamcmd.exe +login $$(cat .steam-user) \
	  +run_app_build 'C:\steamcmd\scripts\app_build_1982220.vdf' +quit; \
	  r=$$?; make game-debug; exit $$r

# itch.io zips, the same files as the Steam depots: Electron runtime + root bits from $(RELEASE_KIT), the
# game straight from the dev dir ($(BUILD)) -> $(RELEASE_KIT)/parasite-<VERSION>-win32.zip / -linux64.zip.
# zipped from WSL, so the linux binaries keep their exec bits. upload them on itch by hand.
itch-zips:
	git diff --quiet HEAD -- src electron || { echo 'uncommitted src/electron changes'; exit 1; }
	test -f "$(BUILD)/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip"
	$(MAKE) game-debug main
	set -e; \
	v=$$(cat src/VERSION); \
	dev="$(BUILD)"; \
	b="$(RELEASE_KIT)"; \
	for os in win32 linux64; do \
	  out="$$b/parasite-$$v-$$os.zip"; \
	  rm -f "$$out"; \
	  if [ $$os = win32 ]; then \
	    (cd "$$b/windows" && zip -rq "$$out" .); \
	  else \
	    (cd "$$b/linux" && zip -rq "$$out" .); \
	    (cd "$$b" && zip -q "$$out" Parasite.sh); \
	  fi; \
	  (cd "$$b/common" && zip -rq "$$out" icons.txt sounds.txt dev mods); \
	  (cd "$$dev" && zip -rq "$$out" resources/app mod-sdk/parasite-mod-sdk-$$v.zip changes.md \
	    -x '*node_modules-0.3.0*' '*action-pickpocket*' '*md-to-steam.js'); \
	  echo "$$out"; \
	done

# push the itch zips (`make itch-zips` first) with the Windows butler in C:\butler (logged in) to the
# windows/linux channels; the first push of a channel is full, later ones send only the changes.
# usage: make itch-push [dry=1]
itch-push:
	set -e; \
	v=$$(cat src/VERSION); \
	b="$(RELEASE_KIT)"; \
	for c in win32:windows linux64:linux; do \
	  /mnt/c/butler/butler.exe push $(if $(dry),--dry-run) \
	    "$$(wslpath -w "$$b/parasite-$$v-$${c%%:*}.zip")" starinfidel/parasite:$${c##*:} \
	    --userversion $$v; \
	done

# localization (docs/localization.md): translate the string catalog with claude -p, two passes, into
# loc/<lang>.json, then build the runtime table electron/lang/<lang>.json. `lang`, not LANG: that one
# is the locale of every process make starts.
# usage: make loc-probe [lang=fr] [n=3] [files=cult/events,PediaConst] / make loc [lang=fr] [jobs=4] / make loc-build
loc:
	python3 tools/loc/translate.py run --lang $(or $(lang),fr) --jobs $(or $(jobs),1) && \
	python3 tools/loc/translate.py nouns --lang $(or $(lang),fr)

loc-probe:
	python3 tools/loc/translate.py probe --lang $(or $(lang),fr) --batches $(or $(n),3) $(if $(files),--files $(files))

loc-build:
	python3 tools/loc/translate.py build --lang $(or $(lang),fr)

report:
	cp -Rf reports/* "$(OBSIDIAN_REPORTS)/"

# regenerates the full engine externs (curated set wins on overlap), then zips
# the SDK into $(BUILD)/mod-sdk/ for shipping with the game download
mod-sdk:
	cd src && haxe project_electron.hxml -xml ../bin/types.xml --no-output
	haxe -cp parasite-mod-sdk/gen-externs --run GenExterns \
	  bin/types.xml parasite-mod-sdk/externs-generated parasite-mod-sdk/externs \
	  "$$(cat src/VERSION)"
	# compile testmod example, then stage it into the SDK (strip dev-only files)
	$(MAKE) -C examples/testmod entry.js
	rm -rf parasite-mod-sdk/examples
	mkdir -p parasite-mod-sdk/examples
	cp -r examples/testmod parasite-mod-sdk/examples/testmod
	rm -f parasite-mod-sdk/examples/testmod/.workshop-id \
	  parasite-mod-sdk/examples/testmod/entry.js.map
	mkdir -p "$(BUILD)/mod-sdk"
	rm -f "$(BUILD)/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip"
	cd parasite-mod-sdk && zip -rq \
	  "$(BUILD)/mod-sdk/parasite-mod-sdk-$$(cat ../src/VERSION).zip" \
	  externs externs-generated template examples docs README.md

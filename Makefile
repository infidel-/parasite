.DEFAULT_GOAL := game-debug

.PHONY: game-debug testmod main report mod-sdk steam-docs steam-upload soviet soviet-preview sshot reload reload-load git-diff tex adopt model-deps models model-export ai gen sounds entities

game-debug:
	cd src && $(MAKE) electron

# headless area generation: build bin/genrun.js and run the structural checks over N seeds, with no
# Electron, no renderer and no save. The oracle for any generator change -- run it BEFORE reaching
# for the game. See docs/area-gen.md.
# usage: make gen [seeds=3000] [args="--print --stats"]
gen:
	cd src && haxe project_gen.hxml
	node tools/genrun.mjs --count $(or $(seeds),3000) $(args)

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

# 3D street-view texture pipeline: downscale/bake textures-src/ 1024px sources
# straight into the app dir (app/textures/, per art/textures.json). textures-src is a
# symlink to the asset store; the sources are NOT committed, the manifest IS.
tex:
	python3 tools/textures.py

# sound pipeline: sounds-src/<area>/*.wav (fal-sfx MCP takes) -> app/sound/<name><N>.mp3, mono,
# one static gain to the manifest's LUFS, loops seamed. never touches a sound it did not make.
# sounds-src is a symlink; the wavs are NOT committed, art/sounds.json IS
sounds:
	python3 tools/sounds.py

# the 128 px entities sheet: the original kra/png art under the asset store (and the generated sheets
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

# 3D model pipeline: decimate + shrink embedded textures of models-src/ .glb sources
# straight into app/models/ (per art/models.json). models-src is a symlink; the sources are NOT
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

# build the soviet UI overhaul mod and stage it into parasite/dev/soviet/
soviet:
	cd examples/soviet/ && $(MAKE)

# stage the standalone browser preview into parasite/soviet/
soviet-preview:
	mkdir -p parasite/soviet
	cp examples/soviet/preview/index.html parasite/soviet/index.html
	cp examples/soviet/preview/style.css  parasite/soviet/style.css
	cp examples/soviet/preview/app.js     parasite/soviet/app.js

pickpocket:
	cd examples/pickpocket/ && $(MAKE)

main:
	cd electron && $(MAKE)

steam-docs:
	node electron/tools/md-to-steam.js parasite-mod-sdk/docs parasite/docs-steam

# upload the game to Steam with the Windows steamcmd in C:\steamcmd (login cached, name in .steam-user);
# only changed chunks go up. needs `make mod-sdk` for this version first. the default branch is set
# live on the Steamworks site, never from here.
# usage: make steam-upload [preview=1] [branch=staging]
steam-upload:
	git diff --quiet HEAD -- src electron || { echo 'uncommitted src/electron changes'; exit 1; }
	test -f parasite/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip
	$(MAKE) game-debug main
	mkdir -p /mnt/c/steamcmd/scripts
	sed -e "s/@DESC@/$$(cat src/VERSION)/g" \
	  -e "s/@PREVIEW@/$(or $(preview),0)/" \
	  -e "s/@BRANCH@/$(branch)/" \
	  -e "s/@DEVDIR@/$$(basename "$$(readlink -f parasite)")/g" \
	  tools/steam-app-build.vdf > /mnt/c/steamcmd/scripts/app_build_1920320.vdf
	/mnt/c/steamcmd/steamcmd.exe +login $$(cat .steam-user) \
	  +run_app_build 'C:\steamcmd\scripts\app_build_1920320.vdf' +quit

report:
	cp -Rf reports/* ObsidianReports/

# regenerates the full engine externs (curated set wins on overlap), then zips
# the SDK into parasite/mod-sdk/ for shipping with the game download
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
	mkdir -p parasite/mod-sdk
	rm -f parasite/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip
	cd parasite-mod-sdk && zip -rq \
	  ../parasite/mod-sdk/parasite-mod-sdk-$$(cat ../src/VERSION).zip \
	  externs externs-generated template examples docs README.md

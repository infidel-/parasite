.DEFAULT_GOAL := game-debug

.PHONY: game-debug testmod main report mod-sdk steam-docs soviet soviet-preview sshot reload git-diff tex adopt model-deps models model-export ai

game-debug:
	cd src && $(MAKE) electron

# dev: screenshot the running game over CDP -> sshot.jpg (game must run on debug port 9300)
sshot:
	node sshot.mjs

# dev: reload the running renderer over CDP to pull in fresh build artifacts (debug port 9300)
reload:
	node reload.mjs

# dev: show working-tree diff (stat + full) without a pager
git-diff:
	@git --no-pager diff --stat HEAD
	@echo ---
	@git --no-pager diff HEAD
	@git --no-pager status --short

# 3D street-view texture pipeline: downscale/bake textures-src/ 1024px sources
# straight into the app dir (app/textures/, per textures.json). textures-src is a
# symlink to the asset store; sources are NOT committed.
tex:
	python3 tools/textures.py

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
# straight into app/models/ (per models.json). models-src is a symlink; sources are NOT committed.
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

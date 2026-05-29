.DEFAULT_GOAL := game-debug

.PHONY: game-debug testmod main report mod-sdk steam-docs soviet soviet-preview

game-debug:
	cd src && $(MAKE) electron

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

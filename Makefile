.DEFAULT_GOAL := game-debug

.PHONY: game-debug testmod main report mod-sdk

game-debug:
	cd src && $(MAKE) electron-mydebug

testmod:
	cd examples/testmod/ && $(MAKE)

main:
	cd electron && $(MAKE)

report:
	cp -Rf reports/* ObsidianReports/

# regenerates the full engine externs (curated set wins on overlap), then zips
# the SDK into parasite/mod-sdk/ for shipping with the game download
mod-sdk:
	cd src && haxe project_electron.hxml -xml ../bin/types.xml --no-output
	haxe -cp parasite-mod-sdk/gen-externs --run GenExterns \
	  bin/types.xml parasite-mod-sdk/externs-generated parasite-mod-sdk/externs \
	  "$$(cat src/VERSION)"
	mkdir -p parasite/mod-sdk
	rm -f parasite/mod-sdk/parasite-mod-sdk-$$(cat src/VERSION).zip
	cd parasite-mod-sdk && zip -rq \
	  ../parasite/mod-sdk/parasite-mod-sdk-$$(cat ../src/VERSION).zip \
	  externs externs-generated template README.md

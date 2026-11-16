# the dev install's mods dir: BUILD from the repo's env (a path with a space, so every use is quoted); a copy
# outside the repo (this Makefile ships in the mod's source zip) keeps the relative default
-include ../../env
DEST = $(if $(BUILD),$(BUILD)/dev/pickpocket,../../parasite/dev/pickpocket)

all: clean entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p "$(DEST)"
	cp entry.js entry.js.map manifest.json "$(DEST)/"
	rm -f "$(DEST)/pickpocket-src.zip"
	zip -r "$(DEST)/pickpocket-src.zip" src build.hxml manifest.json Makefile

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

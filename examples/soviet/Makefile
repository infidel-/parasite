# the dev install's mods dir: BUILD from the repo's env (a path with a space, so every use is quoted); a copy
# outside the repo keeps the relative default
-include ../../env
DEST = $(if $(BUILD),$(BUILD)/dev/soviet,../../parasite/dev/soviet)

all: entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p "$(DEST)"
	cp entry.js entry.js.map manifest.json mod.css "$(DEST)/"
	mkdir -p "$(DEST)/assets"
	cp -rf assets/. "$(DEST)/assets/"

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

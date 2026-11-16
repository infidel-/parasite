# the dev install's mods dir: BUILD from the repo's env (a path with a space, so every use is quoted); a copy
# outside the repo (this Makefile ships in the mod's source zip) keeps the relative default
-include ../../env
DEST = $(if $(BUILD),$(BUILD)/dev/testmod,../../parasite/dev/testmod)

all: clean entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p "$(DEST)"
	cp entry.js entry.js.map manifest.json mod.css .workshop-id "$(DEST)/"
	rm -rf "$(DEST)/assets"
	cp -r assets "$(DEST)/"
	rm -rf "$(DEST)/lang"
	cp -r lang "$(DEST)/"
	rm -f "$(DEST)/testmod-src.zip"
	zip -r "$(DEST)/testmod-src.zip" src lang build.hxml manifest.json mod.css Makefile README.md

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

DEST = ../../parasite/dev/soviet

all: entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js entry.js.map manifest.json mod.css $(DEST)/
	mkdir -p $(DEST)/assets
	cp -rf assets/. $(DEST)/assets/

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

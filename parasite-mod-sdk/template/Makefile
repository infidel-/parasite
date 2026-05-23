# adjust DEST to point at <game install>/dev/<your-mod-id>/
DEST = ../../parasite/dev/yourmod

all: entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js entry.js.map manifest.json $(DEST)/

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

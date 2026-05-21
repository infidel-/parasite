DEST = ../../parasite/dev/testmod

all: clean entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js manifest.json .workshop-id $(DEST)/
	rm -rf $(DEST)/assets
	cp -r assets $(DEST)/

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

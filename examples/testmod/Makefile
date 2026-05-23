DEST = ../../parasite/dev/testmod

all: clean entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js entry.js.map manifest.json mod.css .workshop-id $(DEST)/
	rm -rf $(DEST)/assets
	cp -r assets $(DEST)/
	rm -f $(DEST)/testmod-src.zip
	zip -r $(DEST)/testmod-src.zip src build.hxml manifest.json mod.css Makefile README.md

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

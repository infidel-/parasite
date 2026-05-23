DEST = ../../parasite/dev/chainsaw

all: clean entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js entry.js.map manifest.json $(DEST)/
	rm -f $(DEST)/chainsaw-src.zip
	zip -r $(DEST)/chainsaw-src.zip src build.hxml manifest.json Makefile

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

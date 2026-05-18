DEST = ../../parasite/dev/testmod

all: entry.js install

entry.js: src/Entry.hx src/ModRuntime.hx build.hxml
	haxe build.hxml
	@echo "" >> entry.js
	@echo "// ESM export wrapper (until SDK template handles this)" >> entry.js
	@echo "export const init = window.testmod_Entry.init;" >> entry.js

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js manifest.json $(DEST)/

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

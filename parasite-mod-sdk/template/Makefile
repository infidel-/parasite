# adjust DEST to point at <game install>/dev/<your-mod-id>/
DEST = ../../parasite/dev/yourmod
EXPOSE_NAME = yourmod_Entry

all: entry.js install

entry.js: src/Entry.hx build.hxml
	haxe build.hxml
	@echo "" >> entry.js
	@echo "// ESM export wrapper — Haxe @:expose puts Entry on window; mod:// import needs ESM" >> entry.js
	@echo "export const init = window.$(EXPOSE_NAME).init;" >> entry.js

install: entry.js manifest.json
	mkdir -p $(DEST)
	cp entry.js manifest.json $(DEST)/

clean:
	rm -f entry.js entry.js.map

.PHONY: all install clean

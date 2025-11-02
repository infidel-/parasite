all: clean main.js-debug
.PHONY: main.js main.js-debug

main.js:
	haxe main.hxml && \
	cp main.js* app.html app.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

main.js-debug:
	haxe -D mydebug main.hxml && \
	cp main.js* app.html app.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

clean:
	rm -f main.js main.js.map

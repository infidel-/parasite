all: clean main.js-debug
.PHONY: main.js main.js-debug

main.js:
	haxe main.hxml && \
    cp main.js* app.html app.css preload.js ../app/ && \
    mkdir -p ../app/scripts && cp scripts/*.js ../app/scripts/

main.js-debug:
	haxe -D mydebug main.hxml && \
    cp main.js* app.html app.css preload.js ../app/ && \
    mkdir -p ../app/scripts && cp scripts/*.js ../app/scripts/

clean:
	rm -f main.js main.js.map

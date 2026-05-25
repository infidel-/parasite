all: clean main.js
.PHONY: main.js

main.js:
	haxe main.hxml && \
    cp main.js* app.html app.css preload.js ../app/ && \
    mkdir -p ../app/tools && cp tools/*.js ../app/tools/

clean:
	rm -f main.js main.js.map

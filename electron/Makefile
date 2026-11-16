# the out-of-repo folders (see its header); BUILD is the electron dist
include ../env
$(if $(BUILD),,$(error env: BUILD is empty))
APP := $(BUILD)/resources/app

all: clean main.js
.PHONY: main.js

main.js:
	haxe main.hxml && \
    cp main.js* app.html app.css preload.js "$(APP)/" && \
    mkdir -p "$(APP)/tools" && cp tools/*.js "$(APP)/tools/"

clean:
	rm -f main.js main.js.map

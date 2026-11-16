#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)
# the out-of-repo folders and the haxe port (see its header: every path use is quoted, the Yandex ones hold a space)
include ../env
# stop before any command if env lost a key: an empty path would turn "$(X)/" into "/"
$(foreach k,HAXE_PORT BUILD ITCH_DEMO,$(if $($(k)),,$(error env: $(k) is empty)))
PORT ?= $(HAXE_PORT)
APP := $(BUILD)/resources/app

all: clean electron

check-port:
	@if [ -z "$(PORT)" ]; then \
		echo "Error: missing Haxe server port. Set HAXE_PORT in ../env or pass PORT=<port>."; \
		exit 1; \
	fi
	@if ! printf '%s' "$(PORT)" | grep -Eq '^[0-9]+$$'; then \
		echo "Error: invalid Haxe server port '$(PORT)'. Expected integer."; \
		exit 1; \
	fi
	@if [ "$(PORT)" -lt 1 ] || [ "$(PORT)" -gt 65535 ]; then \
		echo "Error: invalid Haxe server port '$(PORT)'. Expected range 1-65535."; \
		exit 1; \
	fi

electron: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_electron.hxml -debug \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ../electron/preload.js ../electron/three.global.js "$(APP)/" && \
    mkdir -p "$(APP)/lang" ../electron/lang && cp -r ../electron/lang/. "$(APP)/lang/" && \
    cp ../changes.md "$(BUILD)/"
	$(MAKE) loc-test
	$(MAKE) test-quick
	python3 ../tools/loc/extract.py --check

# loc.Loc self-check (formatter, noun forms, pseudo) under node
loc-test: check-port
	haxe -cp . -main l10n.LocTest -D js-es=6 -dce full -js ../bin/loctest.js --connect $(PORT) && \
    node ../bin/loctest.js

# headless game tests (test.Headless under node, see ../tests/README.md): the quick cut on every
# build; the full soak is `make test` at the root
test-quick: check-port
	haxe project_test.hxml --connect $(PORT) && \
    timeout 300 node ../tools/test.mjs --quick

electron-demo: check-port
	haxe project_electron.hxml -debug \
      -D demo && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ../electron/preload.js ../electron/three.global.js "$(APP)/"

www-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_www.hxml -debug \
      -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* "$(ITCH_DEMO)/"

clean:

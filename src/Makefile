#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)
PORT ?= $(strip $(shell cat ../.haxe-port 2>/dev/null))

all: clean electron

check-port:
	@if [ -z "$(PORT)" ]; then \
		echo "Error: missing Haxe server port. Put a number in ../.haxe-port or pass PORT=<port>."; \
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
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ../electron/preload.js ../electron/three.global.js ../app/ && \
    mkdir -p ../app/lang ../electron/lang && cp -r ../electron/lang/. ../app/lang/ && \
    cp ../changes.md ../parasite/
	$(MAKE) loc-test
	python3 ../tools/loc/extract.py --check

# loc.Loc self-check (formatter, noun forms, pseudo) under node
loc-test: check-port
	haxe -cp . -main l10n.LocTest -D js-es=6 -dce full -js ../bin/loctest.js --connect $(PORT) && \
    node ../bin/loctest.js

electron-demo: check-port
	haxe project_electron.hxml -debug \
      -D demo && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ../electron/preload.js ../electron/three.global.js ../app/

www-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_www.hxml -debug \
      -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ~/ItchDemo/

clean:

#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)
PORT ?= $(strip $(shell cat ../.haxe-port 2>/dev/null))

all: clean electron-mydebug

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

electron-mydebug: check-port
	haxe project_electron.hxml -debug \
      -D mydebug \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_electron.hxml \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-mydebug-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_electron.hxml -debug \
      -D mydebug -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_electron.hxml \
      -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

www-mydebug-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_www.hxml -debug \
      -D mydebug -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ~/ItchDemo/

www-demo: check-port
	echo 'Haxe server port =' $(PORT)
	haxe project_www.hxml -debug \
      -D demo \
      --connect $(PORT) && \
    cp ../bin/parasite.js* ~/ItchDemo/

clean:

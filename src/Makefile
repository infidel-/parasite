#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean electron-mydebug

electron-mydebug:
	echo 'Haxe server port =' $$PORT
	haxe project_electron.hxml -debug \
      -D mydebug \
      --connect $$PORT && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron:
	echo 'Haxe server port =' $$PORT
	haxe project_electron.hxml \
      --connect $$PORT && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-mydebug-demo:
	echo 'Haxe server port =' $$PORT
	haxe project_electron.hxml -debug \
      -D mydebug -D demo \
      --connect $$PORT && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-demo:
	echo 'Haxe server port =' $$PORT
	haxe project_electron.hxml \
      -D demo \
      --connect $$PORT && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

www-mydebug-demo:
	echo 'Haxe server port =' $$PORT
	haxe project_www.hxml -debug \
      -D mydebug -D demo \
      --connect $$PORT && \
    cp ../bin/parasite.js* ~/ItchDemo/

www-demo:
	echo 'Haxe server port =' $$PORT
	haxe project_www.hxml -debug \
      -D demo \
      --connect $$PORT && \
    cp ../bin/parasite.js* ~/ItchDemo/

clean:

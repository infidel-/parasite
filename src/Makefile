#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean electron-mydebug

electron-mydebug:
	haxe project_electron.hxml -debug \
      -D mydebug \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron:
	haxe project_electron.hxml \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-mydebug-demo:
	haxe project_electron.hxml -debug \
      -D mydebug -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-demo:
	haxe project_electron.hxml \
      -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css ../electron/fonts.css ~/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

www-mydebug-demo:
	haxe project_www.hxml -debug \
      -D mydebug -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ~/ItchDemo/

www-demo:
	haxe project_www.hxml -debug \
      -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ~/ItchDemo/

clean:

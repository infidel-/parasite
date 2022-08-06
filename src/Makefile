#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean electron-mydebug

electron-mydebug:
	cp -f /mnt/e/Projects/Parasite/Ingame/*.png ../assets.paid.web/graphics/ && \
	haxe project_electron.hxml -debug \
      -D mydebug \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css /mnt/e/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron:
	cp -f /mnt/e/Projects/Parasite/Ingame/*.png ../assets.paid.web/graphics/ && \
	haxe project_electron.hxml \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css /mnt/e/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-mydebug-demo:
	haxe project_electron.hxml -debug \
      -D mydebug -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css /mnt/e/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

electron-demo:
	haxe project_electron.hxml \
      -D demo \
      --connect 6000 && \
    cp ../bin/parasite.js* ../electron/app.html ../electron/app.css /mnt/e/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

html5-mydebug:
	haxe project_js.hxml -debug \
      -D resourcesPath=../assets.paid.web/ \
      -D mydebug \
      --connect 6000 && \
    cp ../bin/parasite.js* /mnt/e/Projects/electron-v17.0.1-win32-ia32-parasite/resources/app/

html5:
	echo -e "\e[92m\e[40mCompiling HTML5 version...\e[0m"
	haxe project_js.hxml -D resourcesPath=../assets.paid.web/ --connect 6000

clean:

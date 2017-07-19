#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean html5-mydebug

release: release-win release-linux32 release-linux64 release-mac64

release-win:
	echo "Building windows release" $(VERSION)
	mkdir -p _releases _releases/parasite-$(VERSION)-win
#	cp -R assets/font/ _releases/parasite-$(VERSION)-win/
#	cp -R assets/graphics/ _releases/parasite-$(VERSION)-win/gfx/
#	cp _release.windows/* _releases/parasite-$(VERSION)-win/
	cp ../parasite.cfg.default _releases/parasite-$(VERSION)-win/parasite.cfg
	openfl build project.nmml windows -Dmydebug
	cp -R ../.bin/windows/neko/release/bin/* \
	  _releases/parasite-$(VERSION)-win/
	cp ../.bin/windows/neko/release/bin/parasite.exe \
	  _releases/parasite-$(VERSION)-win/parasite-debug.exe
	openfl build project.nmml windows
	cp ../.bin/windows/neko/release/bin/parasite.exe \
	  _releases/parasite-$(VERSION)-win/
	cd _releases && zip -r9 parasite-$(VERSION)-win.zip parasite-$(VERSION)-win/

release-linux32:
	echo "Building linux 32-bit release" $(VERSION)
	mkdir -p _releases _releases/parasite-$(VERSION)-linux32
#	cp -R assets/font/ _releases/parasite-$(VERSION)-linux32/
#	cp -R assets/graphics/ _releases/parasite-$(VERSION)-linux32/gfx/
	cp _release.linux32/* _releases/parasite-$(VERSION)-linux32/
	cp ../parasite.cfg.default _releases/parasite-$(VERSION)-linux32/parasite.cfg
	openfl build project.nmml linux -neko -32 -Dmydebug
	cp -R ../.bin/linux/neko/release/bin/* \
	  _releases/parasite-$(VERSION)-linux32/
	cp ../.bin/linux/neko/release/bin/parasite \
	  _releases/parasite-$(VERSION)-linux32/parasite-debug
	openfl build project.nmml linux -neko -32
	cp ../.bin/linux/neko/release/bin/parasite \
	  _releases/parasite-$(VERSION)-linux32/
	cd _releases && tar -c parasite-$(VERSION)-linux32/ | gzip - > \
	  parasite-$(VERSION)-linux32.tar.gz

release-linux64:
	echo "Building linux 64-bit release" $(VERSION)
	mkdir -p _releases _releases/parasite-$(VERSION)-linux64
#	cp -R assets/font/ _releases/parasite-$(VERSION)-linux64/
#	cp -R assets/graphics/ _releases/parasite-$(VERSION)-linux64/gfx/
	cp _release.linux64/* _releases/parasite-$(VERSION)-linux64/
	cp ../parasite.cfg.default _releases/parasite-$(VERSION)-linux64/parasite.cfg
	openfl build project.nmml linux -neko -Dmydebug
	cp -R ../.bin/linux64/neko/release/bin/* \
	  _releases/parasite-$(VERSION)-linux64/
	cp ../.bin/linux64/neko/release/bin/parasite \
	  _releases/parasite-$(VERSION)-linux64/parasite-debug
	openfl build project.nmml linux -neko
	cp ../.bin/linux64/neko/release/bin/parasite \
	  _releases/parasite-$(VERSION)-linux64/
	cd _releases && tar -c parasite-$(VERSION)-linux64/ | gzip - > \
	  parasite-$(VERSION)-linux64.tar.gz

release-mac64:
	echo "Building MacOSX 64-bit release" $(VERSION)
	mkdir -p _releases _releases/parasite-$(VERSION)-mac64
#	openfl build project.nmml mac -neko -Dmydebug
#	cp ../.bin/mac64/neko/release/bin/parasite \
#	  _releases/parasite-$(VERSION)-mac64/parasite-debug
	openfl build project.nmml mac -neko
	cp ../parasite.cfg.default ../.bin/mac64/neko/release/bin/parasite.app/Contents/MacOS/parasite.cfg
	cp -R ../.bin/mac64/neko/release/bin/parasite.app \
	  _releases/parasite-$(VERSION)-mac64/
	cd _releases && zip -r9 parasite-$(VERSION)-mac64.zip parasite-$(VERSION)-mac64/

release-html5-dev-debug:
	openfl build project.nmml html5 -Dmydebug && \
	cp -R ../.bin/html5/release/bin/* \
	~/projects/starinfidel.github.io/parasite-dev-debug/

release-html5-dev:
	openfl build project.nmml html5 && \
	cp -R ../.bin/html5/release/bin/* \
	~/projects/starinfidel.github.io/parasite-dev/

linux32-mydebug:
	openfl build project.nmml linux -neko -32 -Dmydebug

linux32-clean:
	openfl build project.nmml linux -neko -32

linux64-mydebug:
	openfl build project.nmml linux -neko -Dmydebug

linux64-clean:
	openfl build project.nmml linux -neko

mac64-mydebug:
	openfl build project.nmml mac -neko -Dmydebug

mac64-clean:
	openfl build project.nmml mac -neko

windows-mydebug:
	openfl build project.nmml windows -32 -Dmydebug --connect 6000 && \
	cp -R ../.bin/windows/neko/release/bin/* /mnt/1/Projects/bin/

windows-clean:
	haxe --connect 6000 ../.bin/windows/neko/release/haxe/release.hxml && \
    openfl build project.nmml windows --connect 6000 && \
    cp -R ../.bin/windows/neko/release/bin/* /mnt/1/Projects/bin/

html5-mydebug:
	openfl build project.nmml html5 -Dmydebug --connect 6000

html5:
	openfl build project.nmml html5 --connect 6000

fast:
	time -p haxe ../.bin/html5/release/haxe/release.hxml --connect 6000

test:
	haxe ../.bin/linux64/neko/haxe/release.hxml

count:
	git rev-list HEAD --count > COUNT

clean:

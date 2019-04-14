#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean html5-mydebug

#release: release-win release-linux32 release-linux64

release-win:
	echo "Building windows release" $(VERSION)
	mkdir -p ../_releases ../_releases/parasite-$(VERSION)-win
	cp ../_release.windows/* ../_releases/parasite-$(VERSION)-win/
	cp ../parasite.cfg.default ../_releases/parasite-$(VERSION)-win/parasite.cfg
	echo "Debug build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -debug -D mydebug
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win/parasite-debug.hl
	echo "Normal build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win/parasite.hl
	cd ../_releases && zip -r9 parasite-$(VERSION)-win.zip parasite-$(VERSION)-win/
	cp ../_releases/parasite-$(VERSION)-win.zip /mnt/d/1/

#release-linux32:
#	echo "Building linux 32-bit release" $(VERSION)
#	mkdir -p _releases _releases/parasite-$(VERSION)-linux32
#	cp _release.linux32/* _releases/parasite-$(VERSION)-linux32/
#	cp ../parasite.cfg.default _releases/parasite-$(VERSION)-linux32/parasite.cfg
#	openfl build project.nmml linux -neko -32 -Dmydebug
#	cp -R ../.bin/linux/neko/release/bin/* \
#	  _releases/parasite-$(VERSION)-linux32/
#	rm _releases/parasite-$(VERSION)-linux32/index.html
#	cp ../.bin/linux/neko/release/bin/parasite \
#	  _releases/parasite-$(VERSION)-linux32/parasite-debug
#	openfl build project.nmml linux -neko -32
#	cp ../.bin/linux/neko/release/bin/parasite \
#	  _releases/parasite-$(VERSION)-linux32/
#	cd _releases && tar -c parasite-$(VERSION)-linux32/ | gzip - > \
#	  parasite-$(VERSION)-linux32.tar.gz
#
#release-linux64:
#	echo "Building linux 64-bit release" $(VERSION)
#	mkdir -p _releases _releases/parasite-$(VERSION)-linux64
##	cp -R assets/font/ _releases/parasite-$(VERSION)-linux64/
##	cp -R assets/graphics/ _releases/parasite-$(VERSION)-linux64/gfx/
#	cp _release.linux64/* _releases/parasite-$(VERSION)-linux64/
#	cp ../parasite.cfg.default _releases/parasite-$(VERSION)-linux64/parasite.cfg
#	openfl build project.nmml linux -neko -Dmydebug
#	cp -R ../.bin/linux64/neko/release/bin/* \
#	  _releases/parasite-$(VERSION)-linux64/
#	rm _releases/parasite-$(VERSION)-linux64/index.html
#	cp ../.bin/linux64/neko/release/bin/parasite \
#	  _releases/parasite-$(VERSION)-linux64/parasite-debug
#	openfl build project.nmml linux -neko
#	cp ../.bin/linux64/neko/release/bin/parasite \
#	  _releases/parasite-$(VERSION)-linux64/
#	cd _releases && tar -c parasite-$(VERSION)-linux64/ | gzip - > \
#	  parasite-$(VERSION)-linux64.tar.gz
#
#release-html5-dev-debug:
#	openfl build project.nmml html5 -Dmydebug && \
#	cp -R ../.bin/html5/release/bin/* \
#	~/projects/starinfidel.github.io/parasite-dev-debug/
#
#release-html5-dev:
#	openfl build project.nmml html5 && \
#	cp -R ../.bin/html5/release/bin/* \
#	~/projects/starinfidel.github.io/parasite-dev/
#
#linux32-mydebug:
#	openfl build project.nmml linux -neko -32 -Dmydebug
#
#linux32-clean:
#	openfl build project.nmml linux -neko -32
#
#linux64-mydebug:
#	openfl build project.nmml linux -neko -Dmydebug
#
#linux64-clean:
#	openfl build project.nmml linux -neko
#
#windows-mydebug:
#	openfl build project.nmml windows -32 -Dmydebug
#
#windows-clean:
#	openfl build project.nmml windows -32

html5-mydebug:
	haxe project_js.hxml -debug -D mydebug --connect 6000

html5:
	haxe project_js.hxml --connect 6000

hl-mydebug:
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -debug -D mydebug && \
	cp ../bin.hl/parasite.hl /mnt/d/1/hl-1.9.0-win/

count:
	git rev-list HEAD --count > COUNT

clean:

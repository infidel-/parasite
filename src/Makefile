#VERSION=`cat VERSION`
VERSION := $(shell cat VERSION)

all: clean html5-mydebug

release: release-win release-win-free
#linux32 release-linux64
release-html5: release-html5-dev-debug release-html5-dev

release-win:
	echo "PAID Building windows release" $(VERSION)
	mkdir -p ../_releases ../_releases/parasite-$(VERSION)-win
	cp ../_release.windows/* ../_releases/parasite-$(VERSION)-win/
	cp ../parasite.cfg.default ../_releases/parasite-$(VERSION)-win/parasite.cfg
	echo "PAID Debug build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -D heaps_enable_hl_mp3 -D resourcesPath=../assets.paid.hl/ -debug -D mydebug
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win/parasite-debug.hl
	echo "PAID Normal build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -D heaps_enable_hl_mp3 -D resourcesPath=../assets.paid.hl/
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win/parasite.hl
	cd ../_releases && zip -r9 parasite-$(VERSION)-win.zip parasite-$(VERSION)-win/
	cp ../_releases/parasite-$(VERSION)-win.zip /mnt/d/1/

release-win-free:
	echo "FREE Building windows release" $(VERSION)
	mkdir -p ../_releases ../_releases/parasite-$(VERSION)-win-free
	cp ../_release.windows/* ../_releases/parasite-$(VERSION)-win-free/
	cp ../parasite.cfg.default ../_releases/parasite-$(VERSION)-win-free/parasite.cfg
	echo "FREE Debug build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -D resourcesPath=../assets/ -D free -debug -D mydebug
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win-free/parasite-debug.hl
	echo "FREE Normal build..."
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml
	cp ../bin.hl/parasite.hl ../_releases/parasite-$(VERSION)-win-free/parasite.hl
	cd ../_releases && zip -r9 parasite-$(VERSION)-win-free.zip parasite-$(VERSION)-win-free/
	cp ../_releases/parasite-$(VERSION)-win-free.zip /mnt/d/1/

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

release-html5-dev-debug: html5-free-mydebug
	cp -R ../bin/parasite.js* \
	~/git/starinfidel.github.io/parasite-dev-debug/

release-html5-dev: html5-free
	cp -R ../bin/parasite.js \
	~/git/starinfidel.github.io/parasite-dev/

release-html5-paid: cp-paid
	haxe project_js.hxml -D resourcesPath=../assets.paid.web/ --connect 6000
	cd ../bin/ && zip -r9 parasite-$(VERSION)-js.zip index.html parasite.js favicon.png
	mv ../bin/parasite-$(VERSION)-js.zip ../_releases
	cp ../_releases/parasite-$(VERSION)-js.zip /mnt/d/1/

cp-paid:
	cp /mnt/d/1/___Assets/Results.paid/* ../assets.paid.hl/graphics

html5-mydebug:
	haxe project_js.hxml -debug -D resourcesPath=../assets.paid.web/ -D mydebug --connect 6000

html5:
	haxe project_js.hxml -D resourcesPath=../assets.paid.web/ --connect 6000

html5-free-mydebug:
	haxe project_js.hxml -debug -D mydebug -D free --connect 6000

html5-free:
	haxe project_js.hxml -D free --connect 6000

hl-mydebug-free:
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -D heaps_enable_hl_mp3 -D resourcesPath=../assets/ -debug -D mydebug -D free && \
	cp ../bin.hl/parasite.hl /mnt/d/1/hl-1.10.0-win/

hl-mydebug:
	~/haxe-4.0.0-rc2/run.sh project_hl.hxml -D heaps_enable_hl_mp3 -D resourcesPath=../assets.paid.hl/ -debug -D mydebug && \
	cp ../bin.hl/parasite.hl /mnt/d/1/hl-1.10.0-win/

count:
	git rev-list HEAD --count > COUNT

clean:

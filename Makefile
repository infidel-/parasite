all: clean windows-mydebug

neko:
	openfl build project.nmml neko -Dmydebug

linux:
	openfl build project.nmml linux -Dmydebug

windows-mydebug:
	haxe --connect 6000 -D mydebug .bin/linux64/neko/haxe/release.hxml && \
	openfl build project.nmml windows -Dmydebug && \
	cp -R .bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

windows-clean:
	haxe --connect 6000 .bin/linux64/neko/haxe/release.hxml && \
    openfl build project.nmml windows && \
    cp -R .bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

test:
	haxe .bin/linux64/neko/haxe/release.hxml

clean:

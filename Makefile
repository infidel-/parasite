all: clean windows-mydebug

linux32-mydebug:
	openfl build project.nmml linux -neko -32 -Dmydebug

linux32-clean:
	openfl build project.nmml linux -neko

linux64-mydebug:
	openfl build project.nmml linux -neko -Dmydebug

linux64-clean:
	openfl build project.nmml linux -neko

mac64-mydebug:
	openfl build project.nmml mac -neko -Dmydebug

mac64-clean:
	openfl build project.nmml mac -neko

windows-mydebug:
	haxe --connect 6000 -D mydebug .bin/windows/neko/haxe/release.hxml && \
	openfl build project.nmml windows -Dmydebug && \
	cp -R .bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

windows-clean:
	haxe --connect 6000 .bin/windows/neko/haxe/release.hxml && \
    openfl build project.nmml windows && \
    cp -R .bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

test:
	haxe .bin/linux64/neko/haxe/release.hxml

clean:

all: clean windows-debug

neko:
	openfl build project.nmml neko -debug

linux:
	openfl build project.nmml linux -debug

windows:
	openfl build project.nmml windows && cp -R bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

windows-debug:
	haxe --connect 6000 project.hxml && openfl build project.nmml windows -debug && cp -R bin/windows/neko/bin/* /mnt/1/Projects/Parasite/

test:
	haxe project.hxml

clean:

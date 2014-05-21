all: clean windows-debug

neko:
	openfl build project.nmml neko -debug

linux:
	openfl build project.nmml linux -debug

windows:
	openfl build project.nmml windows && cp -R bin/windows/neko/bin/ /mnt/1/

windows-debug:
	openfl build project.nmml windows -debug && cp -R bin/windows/neko/bin/ /mnt/1/


clean:

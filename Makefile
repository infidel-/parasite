all: clean test.n

test.n:
	openfl build project.nmml neko -debug

linux:
	openfl build project.nmml linux -debug

windows:
	openfl build project.nmml windows && cp -R bin/windows/neko/bin/ /mnt/1/


clean:

.DEFAULT_GOAL := game-debug

.PHONY: game-debug testmod main report

game-debug:
	cd src && $(MAKE) electron-mydebug

testmod:
	cd examples/testmod/ && $(MAKE)

main:
	cd electron && $(MAKE)

report:
	cp -Rf reports/* ObsidianReports/

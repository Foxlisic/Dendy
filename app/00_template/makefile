all:
	cc65 skeleton.c
	ca65 reset.s
	ca65 skeleton.s
	ld65 -t nes -o skeleton.nes reset.o skeleton.o nes.lib
	rm skeleton.o reset.o
sta:
	fceux skeleton.nes

all:
	cc65 main.c
	ca65 reset.s
	ca65 main.s
	ld65 -t nes -o main.nes reset.o main.o nes.lib
	rm main.o reset.o
sta:
	fceux main.nes

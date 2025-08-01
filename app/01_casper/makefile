DIR=../..
all: com syn
com:
	cc65 skeleton.c
	ca65 reset.s
	ca65 skeleton.s
	ld65 -t nes -o skeleton.nes reset.o skeleton.o nes.lib
	rm skeleton.o reset.o
sta:
	fceux skeleton.nes
syn:
	php $(DIR)/utils/create.php nes skeleton.nes $(DIR)/c4/m32.mif $(DIR)/c4/m8.mif

DIR=../..
CYC=c5
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
	php $(DIR)/utils/create.php nes skeleton.nes $(DIR)/$(CYC)/m32.mif $(DIR)/$(CYC)/m8.mif

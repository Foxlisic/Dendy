VLIB=/usr/share/verilator/include
ROMS=../roms
FILE=01_lode.nes

all: syn pgm
	./nes $(ROMS)/$(FILE) -d2 > nes.log
syn:
	verilator -cc ../ppu.v > /dev/null
	verilator -cc ../cpu.v > /dev/null
	cd obj_dir && make -f Vppu.mk > /dev/null
	cd obj_dir && make -f Vcpu.mk > /dev/null
pgm:
	g++ -Ofast -Wno-unused-result -o nes -I$(VLIB) nes.cc \
		$(VLIB)/verilated_threads.cpp \
		$(VLIB)/verilated.cpp \
		obj_dir/Vppu__ALL.a \
		obj_dir/Vcpu__ALL.a \
		-lSDL2

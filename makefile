VLIB=/usr/share/verilator/include

all: ica cre app
ica:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v cpu.v ppu.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
cre:
	php create.php nes roms/01
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
app: syn
	g++ -Ofast -Wno-unused-result -o tb -I$(VLIB) \
		tb.cc \
		$(VLIB)/verilated_threads.cpp \
		$(VLIB)/verilated.cpp \
		obj_dir/Vppu__ALL.a \
		obj_dir/Vcpu__ALL.a \
		-lSDL2
	#./tb roms/01_lode.nes > tb.log
	#./tb roms/01_lode.nes roms/01_video.bin roms/01_oam.bin > tb.log
	#./tb roms/02_battlecity.nes > tb.log
	./tb roms/04_mario.nes > tb.log
syn:
	verilator -cc ppu.v > /dev/null
	verilator -cc cpu.v > /dev/null
	cd obj_dir && make -f Vppu.mk > /dev/null
	cd obj_dir && make -f Vcpu.mk > /dev/null

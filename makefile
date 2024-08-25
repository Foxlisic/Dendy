VLIB=/usr/share/verilator/include

all: ica app
ica:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v cpu.v ppu.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq
vcd:
	gtkwave tb.vcd
wav:
	gtkwave tb.gtkw
app: syn
	g++ -o tb -I$(VLIB) \
		tb.cc \
		$(VLIB)/verilated_threads.cpp \
		$(VLIB)/verilated.cpp \
		obj_dir/Vppu__ALL.a \
		-lSDL2
	./tb roms/01_lode.nes roms/01_video.bin roms/01_oam.bin > tb.log
syn:
	verilator -cc ppu.v > /dev/null
	cd obj_dir && make -f Vppu.mk > /dev/null

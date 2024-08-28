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
	#./tb roms/02_lode.nes > tb.log
	./tb roms/02_battlecity.nes > tb.log
syn:
	verilator -cc ppu.v > /dev/null
	verilator -cc cpu.v > /dev/null
	cd obj_dir && make -f Vppu.mk > /dev/null
	cd obj_dir && make -f Vcpu.mk > /dev/null

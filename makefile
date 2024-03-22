VLIB=/usr/share/verilator/include

all: app
	./tb
ica:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v nes.v
	vvp tb.qqq >> /dev/null
app: ver
	g++ -o tb -I$(VLIB) $(VLIB)/verilated.cpp tb.cc obj_dir/Vnes__ALL.a -lSDL2
	strip tb
ver:
	verilator -cc nes.v
	cd obj_dir && make -f Vnes.mk
vcd:
	gtkwave tb.vcd
wave:
	gtkwave tb.gtkw
mif:
	quartus_cdb max10 -c max10 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off max10 -c max10
	quartus_pgm -m jtag -o "p;max10.sof"
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld *.rpt *.summary *.sof *.done *.pin *.qws *.bak *.smsg *.qws *.vcd *.qqq *.jic *.map .qsys_edit undo_redo.txt PLLJ_PLLSPE_INFO.txt c5_pin_model_dump.txt


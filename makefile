VLIB=/usr/share/verilator/include
#CRT=04_mario
CRT=12_prince

all:
	./vm/nes roms/$(CRT).nes > nes.log


VLIB=/usr/share/verilator/include

all:
	iverilog -g2005-sv -DICARUS=1 -o tb.qqq tb.v
	vvp tb.qqq >> /dev/null
	rm tb.qqq

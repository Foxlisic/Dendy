all: syn
pgm:
	quartus_pgm -m jtag -o "p;output_files/c4.sof"
syn:
	quartus_map --read_settings_files=on  --write_settings_files=off c4 -c c4
	quartus_fit --read_settings_files=off --write_settings_files=off c4 -c c4
	quartus_asm --read_settings_files=on  --write_settings_files=off c4 -c c4
cdb:
	quartus_cdb c4 -c c4 --update_mif
	quartus_asm --read_settings_files=on --write_settings_files=off c4 -c c4
sta:
	quartus_sta c4 -c c4
clean:
	rm -rf db incremental_db simulation timing greybox_tmp *.jdi *.pof *.sld
	rm -rf *.rpt *.summary *.sof *.done *.pin *.bak *.smsg *.qws *.vcd *.gtkw
	rm -rf *.qqq *.jic *.map .qsys_editundo_redo.txt PLLJ_PLLSPE_INFO.txt
	rm -rf c5_pin_model_dump.txt output_files obj_dir *.o *.elf *.lst *.qdf
	rm -rf *.ppf *.qip

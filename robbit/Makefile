init:
	cp ./setting/CFU-Proving-Ground/Makefile ./Makefile
	chmod +x ./setting/merge_file/update_makefile.sh
	chmod +x ./setting/merge_file/setup.sh
	./setting/merge_file/update_makefile.sh
	make merge

reset:
	make clean
	rm ./app/my_printf* 
	rm -f *.txt
	rm -rf app constr dispemu build config.vh main.v top.v cfu.v proc.v ./setting/merge_file/*.bak
	cp ./setting/merge_file/Makefile.txt Makefile

filename = ./app/my_printf.c
fileexists = $(shell ls | grep ${filename})

merge:
	cp -r ./setting/$(CFU)/app ./
	cp -r ./setting/$(CFU)/dispemu ./
	cp ./setting/$(CFU)/config.vh ./
	cp ./setting/$(CFU)/*.v ./
	cp ./setting/$(CFU)/cfu_hls.c ./
	if [ ! -f "$(filename)" ]; then\
		cp ./setting/merge_file/my_printf* ./app; \
	fi
	sed -i.bak "s/IMEM_SIZE (32\*1024)/IMEM_SIZE (64\*1024)/" config.vh
	sed -i "s/LENGTH = 0x00008000/LENGTH = 0x00010000/" ./app/link.ld
	sed -i 's/`define LCD_ROTATE 0/`define LCD_ROTATE 2/' config.vh
	sed -i 's/`define CLK_FREQ_MHZ 160/`define CLK_FREQ_MHZ 150/' config.vh
	chmod +x ./setting/merge_file/*.sh
	./setting/merge_file/update_st7789.sh
	./setting/merge_file/update_top.sh
	./setting/merge_file/update_main.sh

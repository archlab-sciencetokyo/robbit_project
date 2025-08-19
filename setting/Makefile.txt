init:
	cp ../CFU-Proving-Ground/Makefile ./Makefile
	chmod +x ./setting/update_makefile.sh
	chmod +x ./setting/setup.sh
	./setting/update_makefile.sh
	make merge

reset:
	make clean
	rm ./app/my_printf* 
	rm -rf app constr dispemu build config.vh main.v top.v cfu.v proc.v ./setting/*.bak
	cp ./setting/Makefile.txt Makefile

filename = ./app/my_printf.c
fileexists = $(shell ls | grep ${filename})

merge:
	cp -r ../$(CFU)/app ./
	cp -r ../$(CFU)/constr ./
	cp -r ../$(CFU)/dispemu ./
	cp ../$(CFU)/config.vh ./
	cp ../$(CFU)/main.v ./
	cp ../$(CFU)/top.v ./
	cp ../$(CFU)/cfu.v ./
	cp ../$(CFU)/proc.v ./
	if [ ! -f "$(filename)" ]; then\
		cp ./setting/my_printf* ./app; \
	fi
	sed -i.bak "s/IMEM_SIZE (32\*1024)/IMEM_SIZE (64\*1024)/" config.vh
	sed -i "s/LENGTH = 0x00008000/LENGTH = 0x00010000/" ./app/link.ld
	sed -i 's/`define LCD_ROTATE 2/`define LCD_ROTATE 0/' config.vh
	sed -i 's/`define CLK_FREQ_MHZ 160/`define CLK_FREQ_MHZ 120/' config.vh
	chmod +x ./setting/*.sh
	./setting/update_st7789.sh
	./setting/update_top.sh
	./setting/update_main.sh

# stamp file of init
INIT_STAMP := .init-done

init: $(INIT_STAMP)

$(INIT_STAMP):
	chmod +x ./setting/merge_file/update_makefile.sh
	chmod +x ./setting/merge_file/setup.sh
	./setting/merge_file/update_makefile.sh
	make merge
	@touch $(INIT_STAMP)

reset:
	make -C ./CFU-Proving-Ground clean
	git submodule update --init --force
	rm -f ./setting/merge_file/*.bak
	rm -f ./$(INIT_STAMP)
	rm -rf ./CFU-Proving-Ground/build
	rm -f ./CFU-Proving-Ground/main.cpp ./CFU-Proving-Ground/main.xdc ./CFU-Proving-Ground/build.tcl ./CFU-Proving-Ground/*.txt ./CFU-Proving-Ground/mpu.v ./CFU-Proving-Ground/robbit.v
	rm -f ./CFU-Proving-Ground/app/my_printf*
filename = ./app/my_printf.c
fileexists = $(shell ls | grep ${filename})

merge:
	cp ./setting/merge_file/main.cpp ./CFU-Proving-Ground/
	cp ./setting/merge_file/*.v ./CFU-Proving-Ground/
	cp ./setting/merge_file/main.xdc ./CFU-Proving-Ground/
	cp ./setting/merge_file/build.tcl ./CFU-Proving-Ground/
	rm -rf ./CFU-Proving-Ground/main.c
	if [ ! -f "$(filename)" ]; then\
		cp ./setting/merge_file/my_printf* ./CFU-Proving-Ground/app; \
	fi
	sed -i.bak "s/IMEM_SIZE (32\*1024)/IMEM_SIZE (64\*1024)/" ./CFU-Proving-Ground/config.vh
	sed -i "s/LENGTH = 0x00008000/LENGTH = 0x00010000/" ./CFU-Proving-Ground/app/link.ld
	sed -i 's/`define LCD_ROTATE 0/`define LCD_ROTATE 2/' ./CFU-Proving-Ground/config.vh
	sed -i 's/`define CLK_FREQ_MHZ 160/`define CLK_FREQ_MHZ 150/' ./CFU-Proving-Ground/config.vh
	chmod +x ./setting/merge_file/*.sh
	./setting/merge_file/update_st7789.sh
	./setting/merge_file/update_top.sh
	./setting/merge_file/update_main.sh

clean:
	rm -rf obj_dir rvcpu-32im* vivado* .Xil
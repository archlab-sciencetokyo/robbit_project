# stamp file of init
INIT_STAMP := ./setting/init-done

init: $(INIT_STAMP)

$(INIT_STAMP):
	@echo "Initializing CFU-Proving-Ground..."
	@$(MAKE) merge
	@touch $(INIT_STAMP)

reset:
	@echo "Resetting CFU-Proving-Ground to clean state..."
	make -C ./CFU-Proving-Ground clean
	git submodule update --init --force
	rm -f $(INIT_STAMP)
	rm -rf ./CFU-Proving-Ground/build ./CFU-Proving-Ground/Madgwick
	rm -f ./CFU-Proving-Ground/main.cpp ./CFU-Proving-Ground/main.xdc ./CFU-Proving-Ground/build.tcl
	rm -f ./CFU-Proving-Ground/*.txt ./CFU-Proving-Ground/mpu.v ./CFU-Proving-Ground/robbit.v ./CFU-Proving-Ground/i2c_master.v
	rm -f ./CFU-Proving-Ground/app/my_printf.c ./CFU-Proving-Ground/app/my_printf.h
	@echo "Reset complete."

merge:
	@echo "Copying new files..."
	cp ./setting/new_files/main.cpp ./CFU-Proving-Ground/
	cp ./setting/new_files/mpu.v ./CFU-Proving-Ground/
	cp ./setting/new_files/robbit.v ./CFU-Proving-Ground/
	cp ./setting/new_files/i2c_master.v ./CFU-Proving-Ground/
	cp ./setting/new_files/main.xdc ./CFU-Proving-Ground/
	cp ./setting/new_files/build.tcl ./CFU-Proving-Ground/
	cp -r ./setting/new_files/Madgwick ./CFU-Proving-Ground/
	@if [ ! -f "./CFU-Proving-Ground/app/my_printf.c" ]; then \
		cp ./setting/new_files/my_printf.c ./CFU-Proving-Ground/app/; \
		cp ./setting/new_files/my_printf.h ./CFU-Proving-Ground/app/; \
	fi
	@echo "Removing main.c..."
	rm -f ./CFU-Proving-Ground/main.c
	@echo "Applying patches..."
	@cd ./CFU-Proving-Ground && \
	for patch in ../setting/patches/*.patch; do \
		echo "  Applying $$(basename $$patch)..."; \
		patch -p1 < $$patch || exit 1; \
	done
	@echo "Merge complete."

clean:
	rm -rf obj_dir rvcpu-32im* vivado* .Xil

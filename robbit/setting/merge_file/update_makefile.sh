#!/bin/bash

set -e

# edit Makefile
sed -i '/GCC/d' ./CFU-Proving-Ground/Makefile
sed -i '4a  LINK := /tools/cad/riscv/rv32ima/bin/riscv32-unknown-elf-ar' ./CFU-Proving-Ground/Makefile
sed -i 's/^TARGET := arty_a7/TARGET := cmod_a7/' ./CFU-Proving-Ground/Makefile
sed -i '/^#TARGET := .*/d' ./CFU-Proving-Ground/Makefile
sed -i '/^TARGET/a CFU := CFU-Proving-Ground' ./CFU-Proving-Ground/Makefile
sed -i 's/^build:[[:space:]]*$/build: prog/' ./CFU-Proving-Ground/Makefile
sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./a \\tcp vivado\/main.runs\/impl_1\/main.bin build\/.' ./CFU-Proving-Ground/Makefile
sed -i '/^init:/,/^done/d' ./CFU-Proving-Ground/Makefile
sed -i '/^reset-hard:/,/main.xdc/d' ./CFU-Proving-Ground/Makefile
sed -i '/init:/,+2d' ./CFU-Proving-Ground/Makefile
sed -i '/[[:space:]]*mkdir -p build *$/ a\
\t$(GPP) -Os -IMadgwick -Iapp -march=rv32im -mabi=ilp32 -c Madgwick/MadgwickAHRS.cpp -o build/MadgwickAHRS.o\
\t$(LINK) rcs build/libmadgwick.a build/MadgwickAHRS.o\
\t$(GPP) -Os -IMadgwick -Iapp -march=rv32im -mabi=ilp32 -c main.cpp -o build/main.o\
\t$(GPP) -Os -IMadgwick -Iapp -march=rv32im -mabi=ilp32 -nostartfiles -Tapp/link.ld \\\
	-o build/main.elf \\\
	app/crt0.s app/*.c build/main.o \\\
	-Lbuild -lmadgwick -lm\
\trm -rf build/MadgwickAHRS.o build/libmadgwick.a build/main.o' ./CFU-Proving-Ground/Makefile

# input init, merge, reset recipe
echo "" >> ./CFU-Proving-Ground/Makefile
cat ./Makefile >> ./CFU-Proving-Ground/Makefile

sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./{N;/\n\t@if \[ ! -f vivado/!P;D}' ./CFU-Proving-Ground/Makefile
sed -i '/^run:/n; /^\s*$/d' ./CFU-Proving-Ground/Makefile

echo "pass Makefile edition"
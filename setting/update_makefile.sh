#!/bin/bash

set -e
sed -i 's/\xc2\xa0/ /g' ./Makefile

# protect clean
awk '/^clean:/ {p=1} /^\S/ && !/^clean:/ {p=0} p' Makefile > .clean_block.tmp

# edit Makefile

sed -i '/^GCC\s*:=/d' Makefile
sed -i 's/^TARGET := arty_a7/TARGET := cmod_a7/' Makefile
sed -i '/^#TARGET := .*/d' Makefile
sed -i '/^TARGET/a CFU := CFU-Proving-Ground' Makefile
sed -i 's/$(GCC)/$(GPP)/g' Makefile
# sed -i '/^all: prog build/a \
# \
# reset:\
# \tmv ./app/my_printf* ./\
# \trm -rf app constr config.vh main.v top.v cfu.v proc.v ./setting/*.bak\
# \tcp ./setting/Makefile.txt Makefile\
# merge:\
# \tcp -r ..\/$(CFU)\/app .\/\
# \tcp -r ..\/$(CFU)\/constr .\/\
# \tcp ..\/$(CFU)\/config.vh .\/\
# \tcp ..\/$(CFU)\/main.v .\/\
# \tcp ..\/$(CFU)\/top.v .\/\
# \tcp ..\/$(CFU)\/cfu.v .\/\
# \tcp ..\/$(CFU)\/proc.v ./\
# \tmv my_print* ./app\
# \tsed -i.bak "s/IMEM_SIZE (32\\*1024)/IMEM_SIZE (64\\*1024)/" config.vh\
# \tchmod +x ./setting/*.sh\
# \t./setting/update_st7789.sh\
# \t./setting/update_top.sh\
# \t./setting/update_main.sh' Makefile
sed -i 's/^build:/build: prog/' Makefile
sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./a \\tcp vivado\/main.runs\/impl_1\/main.bin build\/.' Makefile
sed -i '/^init:/,/^done/d' Makefile
sed -i '/^reset-hard:/,/main.xdc/d' Makefile

echo "pass"
sed -i '/^clean:/,$d' Makefile

# input clean
echo "" >> Makefile
cat .clean_block.tmp >> Makefile

# input init
echo "" >> Makefile
cat ./setting/Makefile.txt >> Makefile

# cleanup
rm .clean_block.tmp

sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./{N;/\n\t@if \[ ! -f vivado/!P;D}' Makefile
sed -i '/^run:/n; /^\s*$/d' Makefile
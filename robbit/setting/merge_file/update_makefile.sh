#!/bin/bash

set -e
#sed -i 's/\xc2\xa0/ /g' ./Makefile

# protect clean
#awk '/^clean:/ {p=1} /^\S/ && !/^clean:/ {p=0} p' Makefile > .clean_block.tmp

# edit Makefile
sed -i '/^GCC\s*:=/d' ./CFU-Proving-Ground/Makefile
sed -i 's/^TARGET := arty_a7/TARGET := cmod_a7/' ./CFU-Proving-Ground/Makefile
sed -i '/^#TARGET := .*/d' ./CFU-Proving-Ground/Makefile
sed -i '/^TARGET/a CFU := CFU-Proving-Ground' ./CFU-Proving-Ground/Makefile
sed -i 's/$(GCC)/$(GPP)/g' ./CFU-Proving-Ground/Makefile
sed -i 's/^build:$/build: prog/' ./CFU-Proving-Ground/Makefile
sed -i '\#app/\*\.c \*\.cpp#!s#app/\*\.c \*\.c#app/\*\.c \*\.cpp#g' ./CFU-Proving-Ground/Makefile
sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./a \\tcp vivado\/main.runs\/impl_1\/main.bin build\/.' ./CFU-Proving-Ground/Makefile
sed -i '/^init:/,/^done/d' ./CFU-Proving-Ground/Makefile
sed -i '/^reset-hard:/,/main.xdc/d' ./CFU-Proving-Ground/Makefile
sed -i '/init:/,+2d' ./CFU-Proving-Ground/Makefile

#sed -i '/^clean:/,$d' ./CFU-Proving-Ground/Makefile

# input clean
# echo "" >> ./CFU-Proving-Ground/Makefile
# cat .clean_block.tmp >> ./CFU-Proving-Ground/Makefile

# input init
echo "" >> ./CFU-Proving-Ground/Makefile
cat ./Makefile >> ./CFU-Proving-Ground/Makefile

# cleanup
# rm .clean_block.tmp

sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./{N;/\n\t@if \[ ! -f vivado/!P;D}' ./CFU-Proving-Ground/Makefile
sed -i '/^run:/n; /^\s*$/d' ./CFU-Proving-Ground/Makefile

echo "pass Makefile edition"
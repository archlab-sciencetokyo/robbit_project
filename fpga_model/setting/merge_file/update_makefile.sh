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
sed -i 's/^build:/build: prog/' Makefile
sed -i 's#app/\*\.c \*\.c#app/\*\.c \*\.cpp#g' Makefile
sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./a \\tcp vivado\/main.runs\/impl_1\/main.bin build\/.' Makefile
sed -i '/^init:/,/^done/d' Makefile
sed -i '/^reset-hard:/,/main.xdc/d' Makefile

sed -i '/^clean:/,$d' Makefile

# input clean
echo "" >> Makefile
cat .clean_block.tmp >> Makefile

# input init
echo "" >> Makefile
cat ./setting/merge_file/Makefile.txt >> Makefile

# cleanup
rm .clean_block.tmp

sed -i '/cp vivado\/main.runs\/impl_1\/main.bit build\/./{N;/\n\t@if \[ ! -f vivado/!P;D}' Makefile
sed -i '/^run:/n; /^\s*$/d' Makefile

echo "pass Makefile edition"
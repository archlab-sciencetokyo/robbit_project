#!/bin/bash

# finish script if there are errors
set -e

if [ ! -x ./update_makefile.sh ]; then
    chmod +x ./setting/update_makefile.sh
fi
./setting/update_makefile.sh
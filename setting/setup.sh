#!/bin/bash

# コマンドが失敗したら、ただちにスクリプトを終了する
set -e

# 1. 編集元となるMakefileをコピーする
cp ../../CFU-Proving-Ground/Makefile ./Makefile

# 2. 更新スクリプトに実行権限があるか確認し、なければ付与する
if [ ! -x ./update_makefile.sh ]; then
    chmod +x ./setting/update_makefile.sh
fi

# 3. 更新スクリプトを実行して、Makefileを編集する
./setting/update_makefile.sh
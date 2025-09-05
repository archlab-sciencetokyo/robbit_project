#!/bin/bash

set -e

# setting
TARGET_FILE="main.v"                      
TARGET_TEXT_1='wire [`DBUS_DATA_WIDTH-1:0] dbus_rdata;' 
DIFF_FILE="./setting/merge_file/main_diff.txt"                 
TARGET_TEXT_2='assign dbus_rdata ='
OLD_TEXT_1="dmem_rdata"
NEW_TEXT_1="(r_dmem_addr[31:28]==4'h3) ? w_mmio_data: dmem_rdata"
TARGET_TEXT_3='wire dmem_we ='
NEW_TEXT_2=" \\& !(dbus_addr[29]);"
TARGET_TEXT_4='input  wire clk_i,'
DIFF_HEADER_FILE="./setting/merge_file/main_header_diff.txt"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: Not find '$TARGET_FILE'"
    exit 1
fi

if [ ! -f "$DIFF_FILE" ]; then
    echo "Error: Not find '$DIFF_FILE'"
    echo "Please make  ${DIFF_FILE}"
    exit 1
fi

# -n : Display of line numbers, -F : Fixed string instead of regular expression
LINE_NUM=$(grep -F -n "$TARGET_TEXT_1" "$TARGET_FILE" | cut -d':' -f1)
if [ -z "$LINE_NUM" ]; then
    echo "Error: no target word in '$TARGET_FILE'"
    echo "target word is: '$TARGET_TEXT_1'"
    exit 1
fi

# insert new code
sed -i.bak "${LINE_NUM}r ${DIFF_FILE}" "$TARGET_FILE"
sed -i "/${TARGET_TEXT_2}/s/${OLD_TEXT_1}/${NEW_TEXT_1}/" "$TARGET_FILE"
sed -i "/${TARGET_TEXT_3}/s/;/${NEW_TEXT_2}/" "$TARGET_FILE"

LINE_NUM=$(grep -F -n "$TARGET_TEXT_4" "$TARGET_FILE" | cut -d':' -f1)
if [ -z "$LINE_NUM" ]; then
    echo "Error: no target word in '$TARGET_FILE'"
    echo "target word is: '$TARGET_TEXT_4'"
    exit 1
fi

sed -i.bak "${LINE_NUM}r ${DIFF_HEADER_FILE}" "$TARGET_FILE"
mv *.bak ./setting/merge_file

echo "complete insertion"
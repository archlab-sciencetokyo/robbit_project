#!/bin/sh

TARGET_FILE="top.v"

if [ ! -f "$TARGET_FILE" ]; then
  echo "Error: target file '$TARGET_FILE' not found."
  echo "Run this script in the same directory as 'top.v'."
  exit 1
fi

cp "$TARGET_FILE" "./setting./$TARGET_FILE.bak"


sed -i.bak -E '
/^\s*\.st7789_RES\s*\(\s*res\s*\)\s*$/ {
  s/\)\s*$/),/
  a\
        .scl            (           ),\
        .sda            (           ),\
        .motor_stby     (           ),\
        .motor_ain1     (           ),\
        .motor_ain2     (           ),\
        .motor_pwma     (           ),\
        .button         (           )
}
' "$TARGET_FILE"


if  cmp -s "$TARGET_FILE" "$TARGET_FILE.bak"; then
  echo "warming: Could not edit top.v"
fi
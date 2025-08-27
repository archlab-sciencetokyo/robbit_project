#!/bin/bash

set -e

# setting
HEADER_FILE="./app/st7789.h"
SOURCE_FILE="./app/st7789.c"
FUNC_NAME="pg_lcd_prints_color"
TEMP_CODE_FILE="./setting/merge_file/st7789_diff.txt"

if [ ! -f "$HEADER_FILE" ]; then
    echo "Error: Could not find '$HEADER_FILE'"
    exit 1
fi
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Could not '$SOURCE_FILE'"
    exit 1
fi

if grep -q "$FUNC_NAME" "$HEADER_FILE"; then
    echo "'$FUNC_NAME' exist in '$HEADER_FILE'"
else
    
    awk '
        1; 
        /void pg_lcd_prints\(const char \*str\);/ {
            print "void pg_lcd_prints_color(const char *str, char color);"
        }
    ' "$HEADER_FILE" > "$HEADER_FILE.tmp" && mv "$HEADER_FILE.tmp" "$HEADER_FILE"
fi

# check whether exist pg_lcd_prints_color in st7789.c
if grep -q "$FUNC_NAME" "$SOURCE_FILE"; then
    echo "'$FUNC_NAME' already exist in '$SOURCE_FILE'"
else

# insert new function
cat > "$TEMP_CODE_FILE" <<'EOF'

void pg_lcd_prints_color(const char *str, char color) {
    while (*str) {
        if (*str == '\n') {
            st7789_col = 0;
            st7789_row = (st7789_row + 1) % 15;
        }
        else if (*str == '\r') {
            st7789_col = 0;
        }
        else {
            pg_lcd_draw_char(st7789_col << 4, st7789_row << 4, *str, color, 1);
            _pg_lcd_update_pos();
        }
        str++;
    }
}
EOF

    awk -v tempfile="$TEMP_CODE_FILE" '
        /void pg_lcd_set_pos\(int x, int y\)/ {
            system("cat " tempfile)
        }
        { print }
    ' "$SOURCE_FILE" > "$SOURCE_FILE.tmp" && mv "$SOURCE_FILE.tmp" "$SOURCE_FILE"
fi

echo "enter sed"
sed -i 's#pg_lcd_draw_point(x + j, y + i, 0);#pg_lcd_draw_point(x + j, y + i, 1);#' "$SOURCE_FILE"
sed -i 's#pg_lcd_fill(0);#pg_lcd_fill(1);#' "$SOURCE_FILE"
echo "finish"
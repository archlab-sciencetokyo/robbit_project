#!/bin/sh

# -----------------------------------------------------------------------------
# Verilog HDLのモジュールインスタンスにポートを追記するスクリプト (修正版)
#
# 使い方:
# 1. このスクリプトを top.v と同じディレクトリに保存します。
# 2. ターミナルで実行権限を付与します: chmod +x update_verilog.sh
# 3. スクリプトを実行します: ./update_verilog.sh
# -----------------------------------------------------------------------------

# 書き換え対象のファイル
TARGET_FILE="top.v"

# --- 安全性チェック ---
# ファイルが存在しない場合はエラー終了
if [ ! -f "$TARGET_FILE" ]; then
  echo "Error: target file '$TARGET_FILE' not found."
  echo "Run this script in the same directory as 'top.v'."
  exit 1
fi

cp "$TARGET_FILE" "$TARGET_FILE.bak"

# -E: 拡張正規表現を使用可能にするオプション
# /^\s*\.st7789_RES\s*\(s*res\s*\)\s*$/: ".st7789_RES (res)" という行で、かつ行末にカンマがない行にのみマッチ
# {...}: マッチした行に対して複数のコマンドを実行
# s/\)\s*$/),/: 行末の ")" を ")," に置換
# a\: 現在の行の後にテキストを追加 (append)
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
        .button         (           ),\
        .led            (           )
}
' "$TARGET_FILE"

# --- 完了メッセージ ---
# cmpコマンドでバックアップファイルと差があるか確認
if  cmp -s "$TARGET_FILE" "$TARGET_FILE.bak"; then
  echo "warming: Could not edit top.v"
fi

# sed -i.bak でバックアップが作成されるため、元のcpによるバックアップは不要なら削除
# rm "$TARGET_FILE.bak"
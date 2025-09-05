# robbit

**robbit** is an user-friendly, two-wheeled self-balancing robot that using an FPGA.

robbitにはマイコンのESP32-C3を使用するモデルと，FPGAのCmod A7-35Tを使用するモデルが存在する．

## 📁 プロジェクト構造

本リポジトリの構成は以下の通りである．

* `fpga_model/`: FPGAモデル開発環境
    * `setting` : 環境構築用のプログラムを格納
        * `CFU-Proving-Ground/`: CFU Proving Groundのリポジトリ
        * `merge_file`: 環境構築用のファイル
        * `mannual`: robbitの機体制作マニュアル
* `esp32c3_model`: XIAO ESP32-C3モデルに書き込むプログラムを格納


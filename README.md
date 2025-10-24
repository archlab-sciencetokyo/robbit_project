# robbit_project(Two-wheeled self-balancing robot project)

**robbit_project**は、マイコンまたはFPGAを活用する扱いやすいtwo-wheeled self-balancing robot(TW-SBR)を作成するプロジェクトである。
TW-SBRは2輪のタイヤを制御し、車体を傾かせることで自立を可能にするロボットである。
FPGAを活用するTW-SBRは**robbit**、マイコンを活用するTW-SBRは**robbit-esp**と呼ばれる。

## 1. robbit

**robbit**はFPGAを活用する扱いやすいtwo-wheeled self-balancinig robot(TW-SBR)である。
**robbit**はFPGAを用いるロボットの普及とFPGAの教育と研究に貢献することを目指している。
安価な市販部品を用いることでハードウェア費用を削減し，FPGA開発のフレームワークを活用することで技術的にも開発しやすくしている．

### 1.1. robbitの構成

下の写真が**robbit**の写真を示している。
車体上部には、FPGAボード、センサ、ディスプレイ、モータドライバなどが備え付けられている。
車体下部には、動力を提供するバッテリーやギアモータやタイヤなどが接続されている。

<table>
    <tr>
        <td><img src="./robbit/setting/image/bcar-structure-front.JPG" alt="画像1" width="200"></td>
        <td><img src="./robbit/setting/image/bcar-structure-side.JPG" alt="画像2" width="200"></td>
</table>

FPGAに実装するモジュールはすべてVerilog HDLで実装されている。
**robbit**の動作制御はPID制御で行っており、これはソフトウェアで実装されている。
ソフトウェアはRISC-Vプロセッサで動作する。
このため、開発者は**robbit**の開発を通じて、ロボットの組み立てやRTL設計を通したハードウェア開発だけでなく、PID制御による動作改善を通したソフトウェア開発も学ぶことができる

### 1.2. 特徴

**robbit**は[CFU Proving Ground](https://github.com/archlab-sciencetokyo/CFU-Proving-Ground)と呼ばれるオープンソースを利用することで、開発しやすいロボットになっている。
**robbit**の組み立て費用も2万円弱になっているので、既存のFPGAを利用するSelf-balancing robotの開発キットよりも安価になっている。
また、FPGAボードを取り外しできるようになっているので、複数人で作る際は、FPGAボードを共有して開発するとさらに費用を抑えることができる。

### 1.3. robbitの活用方法

**robbit**はPIDソフトウェアやハードウェアを変更することで、その動きが大きく変わる。
複数人で開発するときは、自立時間を競うコンテストなどを開いてみると面白いかもしれない。
自立時間を競う上で、風を追加したり、滑りやすい床で自立させたりするとさらに面白くなる。 

###  1.4. robbit プロジェクト構造

**robbit**の開発を行う場合は[robbitフォルダ](./robbit/)内を参照してほしい。
また、robbitフォルダ内には、[開発マニュアル](./robbit/setting/manual/robbit_manual.pdf)や
[システムマニュアル](./robbit/setting/manual/robbit_system_manual.pdf)があるので、そちらを参考にして開発を進めてほしい。
さらなる詳細は、robbit-espフォルダ内のREADMEを参照してほしい

    .
    └── robbit_project/
        └── robbit/   <----------------- 参照フォルダ
            ├── CFU-Proving-Ground/
            └── setting/
               ├── image
                ├── manual
                └── merge_file


## 2. robbti-esp

**robbit**とは別に、**robbit-esp**と呼ばれる、ESP32-C3で制御するロボットも開発できる。
下の画像は**robbit-esp**の完成写真である。
**robbit-esp**の構成は、できるだけ**robbit**と同じ仕様にしている。
**robbit-esp**はBLE通信によるリアルタイムのパラメータ通信を可能にしているため、ディスプレイを接続していない。
**robbit-esp**を開発することで、マイコン開発を学べるだけでなく、**robbit**との動作比較も行える。

<table>
    <tr>
        <td><img src="./robbit-esp/image/esp32c3_front.jpg" alt="画像1" width="200"></td>
        <td><img src="./robbit-esp/image/esp32c3-structure-side.jpg" alt="画像2" width="200"></td>
</table>

### 2.1. robbit プロジェクト構造
**robbit-esp**の開発を行う場合は[robbit-espフォルダ](./robbit-esp/)内を参照してほしい。
robbit-espフォルダ内には[開発マニュアル](./robbit-esp/manual/robbit-esp_manual.pdf)と
[システムマニュアル](./robbit-esp/manual/robbit-esp_system_manual.pdf)が存在するので、これらを参考に開発を進めてほしい。
さらなる詳細は、robbit-espフォルダ内のREADMEを参照してほしい。

    .
    └── robbit_project/
        └── robbit-esp/  <----------------- 参照フォルダ
            ├── image
            └── manual


## ライセンスに注意が必要なライブラリ

- MadgwickAHRS ライブラリ
    - 提供元：Arduino LLC
    - リンク：https://github.com/arduino-libraries/MadgwickAHRS
    - 再配布箇所：
        - robbit/setting/merge_file/MadgwickAHRS.c
        - robbit/setting/merge_file/MadgwickAHRS.h
    - 使用箇所：
        - robbit、robbit-espともに、ソースコードのコンパイル時に静的リンクを使用し組み込む
        - robbit/setting/merge_file/main.cpp、およびrobbit-esp/robbit-esp.inoにてヘッダファイルをincludeし、ビルド時に静的リンク
    - ライセンス：GNU Lesser General Public License v2.1 or later
    - ライセンス全文は本リポジトリに同梱（[COPYING.LESSER](./robbit/setting/merge_file/Madgwick/COPYING.LESSER)）されています。
    - ※このライブラリを使用しているコードの再利用・再配布時には、LGPLの条件にご注意ください。

## 更新履歴

### 2025/10/24

- robbit_project(Two-wheeled self-balancing robot project)のversion 1.0を公開

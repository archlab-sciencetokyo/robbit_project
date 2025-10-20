# robbit_project

**robbit_project**は、マイコンまたはFPGAを活用する扱いやすいtwo-wheeled self-balancing robot(TW-SBR)を作成するプロジェクトである。

FPGAを活用するTW-SBRは**robbit**、マイコンを活用するTW-SBRは**robbit-esp**と呼ばれる。

組み立てにかかる費用は**robbit**は20,000円程度で、**robbit-esp**は5,000円程度で作成でき、他のTW-SBRと比較しても安価である。

また、開発がしやすくなるように、マニュアルを用意しているので、ぜひ開発してみてほしい。

## 📁 プロジェクト構造

本リポジトリの構成は以下の通りである。

    .
    └── robbit_project/
        ├── robbit-esp/
        │   ├── image
        │   └── manual
        └── robbit/
            ├── CFU-Proving-Ground/
            └── setting/
               ├── image
                ├── manual
                └── merge_file

robbit-espフォルダには、robbit-espを開発するのに必要なプログラムやマニュアルが用意されている。

robbitフォルダには、robbitを開発するのに必要なプログラムやマニュアルが用意されている。

**robbit**を開発する場合はrobbitフォルダで、**robbit-esp**を開発する場合にはrobbit-espフォルダで作業を行う。
開発するロボットのフォルダにあるREADMEやマニュアルを参考にすると、開発しやすくなるだろう。

## ライセンスに注意が必要なライブラリ

- MadgwickAHRS ライブラリ
    - 提供元：Arduino LLC
    - 使用箇所：
        - robbit/setting/merge_file/main.cpp（コードの一部を統合）
        - robbit-esp/robbit-esp.ino（#include <MadgwickAHRS.h>）
    - ライセンス：GNU Lesser General Public License v2.1 or later
    - ライセンス全文は本リポジトリに同梱（COPYING.LESSER）されています。
    - ※このライブラリを使用しているコードの再利用・再配布時には、LGPLの条件にご注意ください。

## 更新履歴

### 2025/10/01

- robbit, robbit-espのversion 1.0を公開

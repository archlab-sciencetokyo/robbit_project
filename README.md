# robbit_project

**robbit_project**は，マイコンまたはFPGAを活用する扱いやすいTwo wheel self-balancing robot(TW-SBR)を作成するプロジェクトである．

FPGAを活用するTW-SBRは**robbit**，マイコンを活用するTW-SBRは**robbit-esp**と呼ばれる．

組み立てにかかる費用は**robbit**は20,000円程度で，**robbit-esp**は5,000円程度で作成でき，他のTW-SBRと比較しても安価である．

また，開発がしやすくなるように，マニュアルを用意しているので，ぜひ開発してみてほしい．

## 📁 プロジェクト構造

本リポジトリの構成は以下の通りである．

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
                └── mrege_file

robbit-espフォルダには，robbit-espを開発するのに必要なプログラムやマニュアルが用意されている

robbitフォルダには，robbitを開発するのに必要なプログラムやマニュアルが用意されている

**robbit**を開発する場合はrobbitフォルダで，**robbit-esp**を開発する場合にはrobbit-espフォルダで作業を行う
開発するロボットのフォルダにあるREADMEやマニュアルを参考にすると，開発しやすくなるだろう．

## 更新履歴

### 2025/10/01

- robbit, robbit-espのversion 1.0を公開
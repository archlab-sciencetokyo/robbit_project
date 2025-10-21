# robbit-ESP
 
robbit-ESPはESP32-C3で制御する扱いやすいtwo-wheeled self-balancing robotである。

robbit-ESPは部品の総額が安く，無線によるリアルタイムのパラメータチューニングが可能であるため開発が容易である。

robbit-espの開発を通して,ユーザはマイコン開発やロボット制御を学ぶことができる。

<table>
    <tr>
        <td><img src="image/esp32c3_front.jpg" alt="画像1" width="200"></td>
        <td><img src="image/esp32c3-structure-side.jpg" alt="画像2" width="200"></td>
</table>

-----
## 構成部品

## 構成部品

robbitの組み立てには以下の部品を使用する。価格は2025年8月時点の価格である。

| 購入先 | 品名 | URL | 合計 | 数量 | 単価 |
|:---|:---|:---|:---|:---|:---|
| Switch science | Seeed Studio XIAO ESP32C3 | https://www.switch-science.com/products/8348 | 1069 | 1 | 1069 |
| Amazon | MPU-6050 3軸加速度計・ジャイロモジュール MPU-6050 | https://www.amazon.co.jp/gp/product/B0DL5D5V4B/ | 1949 | 6 | 325 |
| Amazon | タミヤ 楽しい工作シリーズ No.188 ミニモーター標準ギヤボックス 8速 70188 | https://www.amazon.co.jp/gp/product/B002R0DQCK/　| 632 | 1 | 632 |
| Amazon | タミヤ 楽しい工作シリーズ No.193 スリムタイヤセット (36・55mm径) 70193　| https://www.amazon.co.jp/gp/product/B003YORNNG/ | 528 | 1 | 528 |
| Amazon | タミヤ 楽しい工作シリーズ No.157 ユニバーサルプレート 2枚セット (70157) | https://www.amazon.co.jp/dp/B001VZHRXG/ | 660 | 4 | 165 |
| Amazon | tb6612fngデュアルdcステッピングモータドライバモジュール | https://www.amazon.co.jp/dp/B0F2949HQR/ | 998 | 3 | 333 |
| Amazon | EEMB 3.7V 充電式 リチウムイオン電池 653042 820mAh | https://www.amazon.co.jp/gp/product/B08D6B3PC4/ | 2499 | 4 | 625 |
| Amazon | TP4056 Type-C USB リチウム電池充電器モジュール | https://www.amazon.co.jp/dp/B0C8HNLM29/ | 525 | 3 | 175 |

## 開発方法

robbit-espの開発は以下の手順を想定している

1. robbit-espの組み立て
2. プログラム書き込み(Bitstream, バイナリ生成, コンフィギュレーション)
3. 動作確認
4. パラメータチューニング

上記の手順でrobbit-espの開発を行う際は，manualフォルダ内にある[**robbit-esp_manual.pdf**](./manual/robbit-esp_manual.pdf)
と[**robbit-esp_system.pdf**](./manual/robbit-esp_system_manual.pdf)を参考にする。

まずは，**robbit-esp_manual.pdf**に記載されている手順に沿ってrobbit-espの組み立てと動作確認を行うと良い。

動作確認まで終えることができたら，**robbit-esp_system.pdf**も参考にしながら，性能改善に取り組むことをお勧めする。

- [robbit-esp_manual.pdf](./manual/robbit-esp_manual.pdf) : robbit-espの組み立て手順と開発手順が示されている
- [robbit-esp_system_manual.pdf](./manual/robbit-esp_system_manual.pdf) : robbit-espに実装されている制御手法が示されている

## バージョン履歴

### versin 1.0

- 2025/10/24: version 1.0 公開

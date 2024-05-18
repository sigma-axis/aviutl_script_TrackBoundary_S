# aviutl_script_TrackBoundary_S

塗りつぶし2種 / 連結成分切り抜き / 穴埋めができる AviUtl アニメーション効果スクリプト．

![色領域塗りつぶし](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/258f10f2-518d-4cd7-98a8-c9f5ff13028e)

![透明領域塗りつぶし](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/87443efe-e1f7-41f4-ab4d-44ae1e4b3cb3)

![連結成分切り抜き](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/f691f693-4370-487c-b5e7-5071949f7821)

![穴埋め](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/b010a95f-900a-4d26-8979-4674b9dc8718)

![穴埋め応用例](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/ea8521f0-1060-438e-b883-d36e9466721e)

## 動作要件

- AviUtl 1.10 (1.00 でも動作するが 1.10 推奨)

  http://spring-fragrance.mints.ne.jp/aviutl

- 拡張編集 0.92 (「[拡張編集ドラッグ](#拡張編集ドラッグ)」の機能を利用する場合)

  - 0.93rc1 でも動作するはずだが未確認 / 非推奨．

- [LuaJIT](https://luajit.org/)

  バイナリのダウンロードは[こちら](https://github.com/Per-Terra/LuaJIT-Auto-Builds/releases)からできます．

  - 拡張編集 0.93rc1 同梱の `lua51jit.dll` は***バージョンが古く既知のバグもあるため非推奨***です．
  - AviUtl のフォルダにある `lua51.dll` と置き換えてください．

## 導入方法

以下のフォルダのいずれかに `@TrackBoundary_S.anm` と `TrackBoundary_S.lua` をコピーしてください．

1. `exedit.auf` のあるフォルダにある `script` フォルダ
1. (1) のフォルダにある任意の名前のフォルダ


## 使い方

次の 4 つのアニメーション効果が使えます:

1.  [連結成分切り抜き](#連結成分切り抜き)
1.  [色領域塗りつぶし](#色領域塗りつぶし)
1.  [透明領域塗りつぶし](#透明領域塗りつぶし)
1.  [穴埋め](#穴埋め)

### 連結成分切り抜き

アンカーで指定した点を含む，透明度を境とした連結成分以外を隠します．「反転」のチェックを入れると逆に指定した連結成分のみを隠します．

![連結成分切り抜き](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/f691f693-4370-487c-b5e7-5071949f7821)

- `X`, `Y`（トラックバー）

  アンカーの X, Y 座標です．ここで指定した点を含む連結成分が表示 / 非表示の対象になります．初期値は原点 $(0,0)$.

- `不透明度`（トラックバー）

  隠す連結成分の不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `0`（完全透明）．

- `αしきい値`（トラックバー）

  各ピクセルが「つながっている」と判定する $\alpha$ 値のしきい値を % 単位で指定します．初期値は `0`.

- `反転`（チェック）

  1.  `OFF` のとき，アンカーで指定した連結成分のみが表示されます．
  1.  `ON` のとき，アンカーで指定した連結成分以外が表示されます．

  初期値は `OFF`.

- `角で隣接扱い`（ダイアログのチェック）

  市松模様の格子部分のように，角のみで隣接している 2 ピクセルを「つながっている」と扱うかどうかを指定します．初期値は `ON`.

- `PI`（ダイアログの入力欄）

  パラメタインジェクション用の入力枠です．次の形の `table` 型，または `nil` を受け付けます．初期値は空欄 (`nil` 扱い).

  ```lua
  {
    [0] = check0, -- boolean 型 で "反転" の項目を上書き，または nil. 0 を false, 0 以外を true 扱いとして number 型も可能．
    [1] = track0, -- number 型で "X" の項目を上書き，または nil.
    [2] = track1, -- number 型で "Y" の項目を上書き，または nil.
    [3] = track2, -- number 型で "不透明度" の項目を上書き，または nil.
    [4] = track3, -- number 型で "αしきい値" の項目を上書き，または nil.
  }
  ```


### 色領域塗りつぶし

アンカーで指定した点を含む，近い色の領域を指定色で塗りつぶします．塗りつぶさずに透明 / 半透明に切り抜いたり，逆に指定した色領域以外を透明にしたりもできます．

![色領域塗りつぶし](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/258f10f2-518d-4cd7-98a8-c9f5ff13028e)

- `不透明度`（トラックバー）

  指定した色領域の不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `着色強さ`（トラックバー）

  指定した色領域を指定した別の色で置き換えるときの，指定色の割合を % 単位で指定します．初期値は `100`．

- `色範囲`（トラックバー）

  指定した点の色からどのくらい近い色を塗りつぶすかの許容範囲を指定します．初期値は `8`.

  - 例えば `8` を指定して，`RGB(100,100,100)` (#646464) の灰色の点にアンカーを置いた場合，`RGB(92,92,92)` から `RGB(108,108,108)` までの範囲の色が塗りつぶしの対象になります．

- `αしきい値`（トラックバー）

  各ピクセルが「つながっている」と判定する $\alpha$ 値のしきい値を % 単位で指定します．初期値は `0`.

- `着色で輝度を保持`（チェック）

  指定した色領域を指定した別の色で置き換えるとき，輝度成分だけは色領域にあった元の色の値のままにします．初期値は `OFF`.

- `位置`（ダイアログの入力欄）

  アンカー位置を示す `table` 型を記述します．アンカーはマウス操作で動かすことでも指定できます．初期値は `{0,0}`（オブジェクト中央）．

- `R範囲補正`, `G範囲補正`, `B範囲補正`（ダイアログの入力欄）

  `色範囲` を R, G, B の成分ごとに個別に調節できます．`色範囲` で指定した値に乗じて成分ごとの範囲が決定します．

  - 例えば `色範囲` が `8` で，`R範囲補正` が `2.0` の場合，赤成分に限って許容範囲が `16` 相当になります．

- `着色`（ダイアログの色選択）

  指定した色領域を，指定した別の色で置き換えられます．初期値は `0xffffff` (#ffffff) の白色．

- `前景α値(%)`（ダイアログの入力欄）

  指定した色領域の外側の不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `角で隣接扱い`（ダイアログのチェック）

  市松模様の格子部分のように，角のみで隣接している 2 ピクセルを「つながっている」と扱うかどうかを指定します．初期値は `ON`.

- `PI`（ダイアログの入力欄）

  パラメタインジェクション用の入力枠です．次の形の `table` 型，または `nil` を受け付けます．初期値は空欄 (`nil` 扱い).

  ```lua
  {
    [0] = check0, -- boolean 型 で "着色で輝度を保持" の項目を上書き，または nil. 0 を false, 0 以外を true 扱いとして number 型も可能．
    [1] = track0, -- number 型で "不透明度" の項目を上書き，または nil.
    [2] = track1, -- number 型で "着色強さ" の項目を上書き，または nil.
    [3] = track2, -- number 型で "色範囲" の項目を上書き，または nil.
    [4] = track3, -- number 型で "αしきい値" の項目を上書き，または nil.
    pos = anchor, -- table 型で "位置" の項目を上書き，または nil. {123,nil}, {nil,42} など X, Y 片方のみの指定も可能．
  }
  ```

### 透明領域塗りつぶし

アンカーで指定した点を含む透明領域を指定色で塗りつぶします．

![透明領域塗りつぶし](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/87443efe-e1f7-41f4-ab4d-44ae1e4b3cb3)

- `X`, `Y`（トラックバー）

  アンカーの X, Y 座標です．ここで指定した点を含む透明領域が塗りつぶしの対象になります．初期値は原点 $(0,0)$.

- `不透明度`（トラックバー）

  塗りつぶしの不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `αしきい値`（トラックバー）

  透明領域が「つながっている」と判定する $\alpha$ 値のしきい値を % 単位で指定します．初期値は `100`.

- `色`（ダイアログの色選択）

  透明領域を塗りつぶす色を選択します．初期値は `0xffffff` (#ffffff) の白色．

- `前景α値(%)`（ダイアログの入力欄）

  塗りつぶし範囲外の不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `角で隣接扱い`（ダイアログのチェック）

  市松模様の格子部分のように，角のみで隣接している不透明な 2 ピクセルを「つながっている」と扱うかどうかを指定します．初期値は `ON`.

- `PI`（ダイアログの入力欄）

  パラメタインジェクション用の入力枠です．次の形の `table` 型，または `nil` を受け付けます．初期値は空欄 (`nil` 扱い).

  ```lua
  {
    [1] = track0, -- number 型で "X" の項目を上書き，または nil.
    [2] = track1, -- number 型で "Y" の項目を上書き，または nil.
    [3] = track2, -- number 型で "不透明度" の項目を上書き，または nil.
    [4] = track3, -- number 型で "αしきい値" の項目を上書き，または nil.
  }
  ```

### 穴埋め

画像外枠に接していない透明領域を不透明にしたり指定色で塗りつぶしたりできます．逆に画像外枠に接している透明領域のみを不透明にすることもできます．

![穴埋め](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/b010a95f-900a-4d26-8979-4674b9dc8718)

カラーキーなどのフィルタ効果を適用して外側の縁を消去した際，内側に巻き添えで空いてしまった穴を塞ぐ目的で作成しました．その目的の影響もあって，完全不透明で本来が無意味のはずの色成分が見えるようになるため注意してください．

![穴埋め応用例](https://github.com/sigma-axis/aviutl_script_TrackBoundary_S/assets/132639613/ea8521f0-1060-438e-b883-d36e9466721e)


- `不透明度`（トラックバー）

  塗りつぶす透明領域に設定する不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `着色強さ`（トラックバー）

  塗りつぶす透明領域に指定した別の色で置き換えるときの，指定色の割合を % 単位で指定します．初期値は `100`．

  - `100` 未満にすると，本来完全透明で見えないはずのピクセルの色成分が見えるようになるため，不定動作に注意してください．

- `前景α値`（トラックバー）

  塗りつぶし範囲外の不透明度 ($\alpha$ 値) を % 単位で指定します．初期値は `100`（完全不透明）．

- `αしきい値`（トラックバー）

  透明領域のピクセルが「つながっている」と判定する $\alpha$ 値のしきい値を % 単位で指定します．初期値は `100`.

- `外枠埋め`（チェック）

  塗りつぶす透明領域を，画像外枠に接している部分に切り替えます．初期値は `OFF`.

- `色`（ダイアログの色選択）

  透明領域を塗りつぶす色を選択します．初期値は `0xffffff` (#ffffff) の白色．

- `輝度の保持`（ダイアログのチェック）

  透明領域を塗りつぶすとき，輝度成分だけは元の値のままにします．初期値は `OFF`.

- `角で隣接扱い`（ダイアログのチェック）

  市松模様の格子部分のように，角のみで隣接している不透明な 2 ピクセルを「つながっている」と扱うかどうかを指定します．初期値は `ON`.

- `PI`（ダイアログの入力欄）

  パラメタインジェクション用の入力枠です．次の形の `table` 型，または `nil` を受け付けます．初期値は空欄 (`nil` 扱い).

  ```lua
  {
    [0] = check0, -- boolean 型 で "外枠埋め" の項目を上書き，または nil. 0 を false, 0 以外を true 扱いとして number 型も可能．
    [1] = track0, -- number 型で "不透明度" の項目を上書き，または nil.
    [2] = track1, -- number 型で "着色強さ" の項目を上書き，または nil.
    [3] = track2, -- number 型で "前景α値" の項目を上書き，または nil.
    [4] = track3, -- number 型で "αしきい値" の項目を上書き，または nil.
  }
  ```

## TIPS

1.  アンカーを利用する場合，このスクリプト適用前のフィルタ効果で Z 座標移動や拡大率，回転効果が設定されていると，アンカー位置が正しく認識されないことがあります．Z 軸方向への移動や拡大率，回転効果を付与する場合は，このスクリプト以降にフィルタ効果をかけてください．

    - 標準描画や拡張描画による座標指定や拡大率，回転に関しては問題ありません．

1.  [色領域塗りつぶし](#色領域塗りつぶし)は，機能面では[連結成分切り抜き](#連結成分切り抜き)の上位互換です．

    色領域塗りつぶしの `色範囲` を最大にして `着色強さ` と `前景α値(%)` を `0` にすれば連結成分切り抜きと同じ効果が得られます．`不透明度` と `前景α値(%)` を入れ替えれば `反転` も可能です．

    ただし連結成分切り抜きはアンカー位置がトラックバーで動かせるため，中間点を用いたアニメーションを設定しやすいなどの点が異なります．また連結成分切り抜きのほうが処理速度が高速です．


1.  [色領域塗りつぶし](#色領域塗りつぶし)と類似のスクリプトとして，のなめ様の[塗り潰しで透過スクリプト](https://www.nicovideo.jp/watch/sm42068071)がありますが次のような違いがあります．

    - こちらのスクリプトのほうが高速です．試した限りの全ての場合でこちらのほうが高速に動作しました．

      おおよそ 4 倍程度速いようです．

    - 塗り潰しで透過スクリプトでしかできない機能もあります:

      1.  アンカーを複数個設置できます．
      1.  「範囲外からも塗る」オプションがあります．

          画像の上下左右4辺から塗りつぶし領域がつながっているような形で塗りつぶせます．

    - こちらのスクリプトでしかできない機能もあります:

      - 塗りつぶし領域や塗りつぶし範囲外の透明度を個別に指定できます．
      - 塗りつぶしの色の強さや，輝度を保持するかどうかを選べます．
      - 「角で隣接扱い」のオプションがあります．
      - パラメタインジェクションができます．

1.  [透明領域塗りつぶし](#透明領域塗りつぶし)と類似のスクリプトとして，ティム様の[透明塗り](http://www.nicovideo.jp/watch/sm20426178)がありますが次のような違いがあります．

    - 実行速度に違いがあります．

      - 透明塗りの「改良計算」が `ON`（初期値）の場合での比較だと，こちらのほうが高速でした．

        塗り面積が大きいほど差が顕著で，約 3 倍の差が付く場面もありました．

      - 透明塗りの「改良計算」が `OFF` の場合だと，透明塗りのほうが高速な場面もありました．

        傾向は不明ですが，最大で約 1.5 倍の差が付く場面もありました．ほとんど差がない場面もあります．

        - ただしこの場合，塗りつぶし部分の透明度を指定できません．

    - こちらのスクリプトでしかできない機能があります:

      - 塗りつぶし範囲外の透明度を指定できます．
      - 「角で隣接扱い」のオプションがあります．
      - パラメタインジェクションができます．

## 改版履歴

- **v1.00** (2024-05-??)

  初版．

## ライセンス

このプログラムの利用・改変・再頒布等に関しては MIT ライセンスに従うものとします．

---

The MIT License (MIT)

Copyright (C) 2024 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

https://mit-license.org/

# Credits

## Lua 5.1/5.2

https://www.lua.org

---

The MIT License (MIT)

Copyright © 1994–2023 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

## LuaJIT

https://luajit.org

---

The MIT License (MIT)

Copyright (C) 2005-2023 Mike Pall. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.


#  連絡・バグ報告

- GitHub: https://github.com/sigma-axis
- Twitter: https://twitter.com/sigma_axis
- nicovideo: https://www.nicovideo.jp/user/51492481
- Misskey.io: https://misskey.io/@sigma_axis
- Bluesky: https://bsky.app/profile/sigma-axis.bsky.social

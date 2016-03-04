# [英辞郎](http://eijiro.jp/index.shtml)の非暗号化テキストからDictionary.app用ファイルを作成

> 英辞郎（えいじろう）は、「何でも載っている辞書を作りたい」と願う人たちで構成されるEDP(Electronic Dictionary Project)がアップデートし続けている英和・和英データベースである。

([Wikipedia](https://ja.wikipedia.org/wiki/%E8%8B%B1%E8%BE%9E%E9%83%8E)より)

販売されている英辞郎の非暗号化テキストを変換し、Dictionary.app用ファイルを作成するスクリプトです。なお、[英辞郎 for OS X Dictionary.app](https://tecorin-site.appspot.com/osx/index.html)として変換済みかつ、最新版データも販売されています。本プロジェクトでは、Rubyで書かれたスクリプトをベースに、内容や表示をカスタマイズしたい方向けに公開しています。

[Tats_y](http://www.binword.com/blog/)氏の変換スクリプトを参考にさせていただいています。

## 準備

* [Apple Developerサイト](https://developer.apple.com/downloads/)よりAuxiliary Tools for Xcode 7をダウンロードし、ダウンロードしたdmgファイルをマウントします
* [英辞郎](http://eijiro.jp/index.shtml)の非暗号化テキストファイルを購入、ダウンロードします
* Ruby 2.0以降、sqlite3 gemをインストールしておいてください
* 空きディスク容量を10GB程度以上あるか確認してください
* 実行にはおおよそ2〜3日程度かかります

# 利用方法

## 読み込み

英辞郎の非暗号化テキストを読み込みます。略辞郎については `-r` オプションをつけると略語の展開された語に対するリンクが生成されるように変換できます。
なお、このスクリプトはいまのところ例辞郎テキストについては対応していません。

```
% cat EIJI-1441.TXT  | ruby eijiro.rb -d Eijiro.db -l
% cat WAEI-1441.TXT  | ruby eijiro.rb -d Eijiro.db -l
% cat RYAKU-1441.TXT | ruby eijiro.rb -d Eijiro.db -l -r
```

処理用に利用するデータベースファイルを作りますがおおよそ2.1GB程度のファイルサイズになります。

## 書き出し

Dictionary Development Kit向けのXMLファイルを生成します。

```
% ruby eijiro.db -d Eijiro.db -e Eijiro.xml
```

読み込みと書き出しでおおよそ2〜3時間程度かかります。
書き出されるXMLファイルは1.7GB程度のファイルサイズになります。

## make

```
% make && make install
```

Dictionary Development Kitのmakeを実行します。おおよそ2日程度かかります。

# 備考

非暗号化テキストは144.1以降販売されないという事情もあり、拡張性には気を配らず作ってあります。
テキスト全体をSQLiteデータベースに導入せずに、ハッシュに格納してオンメモリーで処理すれば読み込み・書き出しはおおよそ1時間程度に短縮できます。ただ、CSS適用テストなどいくつか試行錯誤をするのにランダムで小規模なビルドをしたかったので一度データベースに格納しています。

書き出し処理の際、`-s`オプションをつければデータベースから1/256程度のみ選んでビルドできます。

```
% ruby eijiro.db -d Eijiro.db -e Eijiro.xml -s && make && make install
```

マシン性能によりますが数分以内に終わります。

# ライセンス

The MIT License (MIT) Copyright (c) 2016 Takayuki Okazaki

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

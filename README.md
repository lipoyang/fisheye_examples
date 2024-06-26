# fisheye_examples
いろいろな言語で魚眼画像への変換

<img src="./fig1.png" width="352">

## 概要
いろいろなプログラミング言語で魚眼画像への変換を実装しました。
補間処理は簡単な線形補間です。
画像処理系のライブラリは使わずにアルゴリズムを実装しました。
マウスで画面をさわると、レンズの中心位置を動かすことができます。

![図](./fig2.jpg)

## 対応した言語
- [Processing](./fisheye_processing)
- [JavaScript](./fisheye_js)
- [C#](./fisheye_cs)
- [Python](./fisheye_python/)
- [Ruby](./fisheye_ruby/)
- [Java (Android)](./fisheye_android/)
- [Kotlin (Android)](./fisheye_kotlin/)
- [C++ (Qt)](./fisheye_qt/)
- [Rust (WebAssembly)](./fisheye_rust/)
- [Haskell](./fisheye-haskell/)

## Processing
- Processing 4.3 で動作確認
- この手のことをやるのはProcessingがいちばん簡単。なんの工夫もなく動いた。

## JavaScript
- Webアプリ (Chromeで動作確認)
- [こちら](https://licheng.sakura.ne.jp/hatena15/fisheye_js/) でホスト中 (スマホでも動作)
- ファイルへのアクセスを行っているのでWebサーバでのホストが必要。ローカルのHTMLファイルを開いてもエラーで何も表示されない。VSCodeでLive Serverプラグインを利用するのが簡単。
- 高速化のため、画像全体に対して getImageData / putImageData を使用し、RGBA値が並んだUint8型一次元配列で処理している。

## C#
- Windowsフォームアプリ (Visual Studio 2019で作成/動作確認)
- GetPixel / SetPixel は遅いので、高速化のため LockBits を使用し、画像全体のRGB値が並んだbyte型一次元配列を unsafe でポインタを使って処理している。

## Python
- Windows版 Python 3.10.0 で動作確認
- GUIツールキットは Tkinter を使用、 画像の扱いには Pillow を使用
- 配列の処理には NumPy を使用し、Numba によるJITコンパイルで高速化
- NumPy と Numba を用いない方法では十分な処理速度が得られなかった。→ [fisheye_TOO_SLOW.py](./fisheye_python/fisheye_TOO_SLOW.py)

## Ruby
- Windows版 Ruby 3.2.3 で動作確認 (YJIT はWindows版が未対応のため未検証)
- 2Dゲームライブラリ Gosu を使用、 画像の読み込みには chunky_png を使用
- Rubyのみによる実装では十分な処理速度が得られなかった。→ [fisheye_ALL_Ruby.rb](./fisheye_ruby/fisheye_ALL_Ruby.rb)
- 魚眼変換の演算をC言語で実装し、Fiddle でC言語の関数を呼び出している。
- C言語のコードは Windows の mingw-w64-x86_64-clang で共有ライブラリ(.so)にコンパイル

## Java (Android)
- Android Studio Electric Eel で作成/動作確認 (APIレベル 33 / 最小APIレベル 24)
- getPixel / setPixel は遅いので、getPixels / setPixels で一次元配列にまとめて取得/設定している。
- Math.sqrt, Math.round, Color.argb, Color.red などは遅いので、自前で演算している。
- 画面のスケーリングに注意

## Kotlin (Android)
- Android Studio Electric Eel で作成/動作確認 (APIレベル 34 / 最小APIレベル 24)
- 上記のJava版の同等のコード

## C++ (Qt)
- Qt Creator 12.0.2 / Qt 6.6.0 (MSVC 2019, x86_64) で作成/動作確認
- Windows版 Qtウィジェットアプリ
- QImage の pixelColor / setPixelColor は遅いので、bits を使用し、RGBA値が並んだuchar型一次元配列を取得して処理している。

## Rust (WebAssembly)
- Webアプリ (上記の JavaScript版のWebアプリと同等の動作)
- Rust → WebAssembly のビルドには wasm-pack を使用
- Chromeで動作確認 (VSCode の Live Server でホスト可能。そのためデバッガの設定でポート番号5500にしている。)
- 画像データのRGBA値が並んだ一次元配列 Vec<u8> は static mut で定義し、unsafe で処理している。

## Haskell
- Stack 2.13.1 / GHC 9.6.4 (x86_64) で作成/動作確認 (Windows版アプリ)
- グラフィックライブラリは gloss を使用
- glossは、GLUT(OpenGL Utility Toolkit) に依存しているので、Windows用に freeglut.dll を使用
- 写像元の画像データは、RGBA値が並んだ一次元配列 Vector Word8 で取得
- 写像先の画像データは、写像関数を map で処理してRGBA値のリスト \[Word32\] を得て、それをバイト列 ByteString に変換

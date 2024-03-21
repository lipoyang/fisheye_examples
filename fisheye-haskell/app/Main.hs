module Main(main) where

import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Interact -- Event
import Codec.Picture
import Data.Word (Word8, Word32)
-- import qualified Data.ByteString as BS
import qualified Data.ByteString.Builder as BB
import qualified Data.ByteString.Lazy as BL
-- import qualified Data.Vector as V
import qualified Data.Vector.Storable as VS
-- import Text.Printf (printf) -- デバッグ用
-- import Debug.Trace (trace)  -- デバッグ用

-------------------
-- 定数
-------------------
_black :: Word32 -- 32ビットRGBA値 黒色
_black = 0xff

-------------------
-- 画面の設定
-------------------
-- 画面種別(ウィンドウ), タイトル, サイズ, 表示位置
window :: Display
window = InWindow "魚眼変換" (532, 532) (100, 100)

--------------------------
-- アプリケーションの状態
--------------------------
data AppState = AppState
  { _W :: Int         -- 元画像の幅
  , _H :: Int         -- 元画像の高さ
  , _R :: Float       -- レンズの半径
  , _D :: Float       -- レンズの中心から投影面までの距離 
  , _x0 :: Float      -- レンズの中心の x 座標
  , _y0 :: Float      -- レンズの中心の y 座標
  , _x0_prev :: Float -- レンズの中心の x 座標の前回値
  , _y0_prev :: Float -- レンズの中心の y 座標の前回値
  , _srcData :: VS.Vector Word8 -- 元画像データ
  , _dstImg  :: Picture  -- 表示画像
  , _isMouseDown :: Bool -- マウスを押下しているか
  }

--------------------------
-- 描画
--------------------------
onDraw :: AppState -> Picture
onDraw = _dstImg   -- ※ onDraw app = _dstImg app と同義

--------------------------
-- イベント処理
--------------------------
onEvents :: Event -> AppState -> AppState
onEvents (EventKey key ks _ (x, y)) app = onMouseButton key ks x y app
onEvents (EventMotion (x, y))       app = onMouseMove x y app
onEvents (EventResize _)            app = app

-- マウスの左ボタンUP/DOWN
onMouseButton :: Key -> KeyState -> Float -> Float -> AppState -> AppState
onMouseButton (MouseButton LeftButton) ks x y = if ks == Down then onMouseDown x y  else onMouseUp x y
onMouseButton _ _ _ _ = id -- マウスの左ボタン以外のボタン、キーは無視
-- UP
onMouseUp:: Float -> Float -> AppState -> AppState
onMouseUp x y app = app{_isMouseDown = False, _x0 = x0, _y0 = y0}
  where (x0, y0) = mouseCoordinate x y app
-- DOWN
onMouseDown:: Float -> Float -> AppState -> AppState
onMouseDown x y app = app{_isMouseDown = True, _x0 = x0, _y0 = y0}
  where (x0, y0) = mouseCoordinate x y app
-- マウスの移動
onMouseMove:: Float -> Float -> AppState -> AppState
onMouseMove x y app = if _isMouseDown app then app{_x0 = x0, _y0 = y0} else app
  where (x0, y0) = mouseCoordinate x y app

-- マウス座標の変換
-- Gloss では画面中央が原点で、Y軸は上向きが正であることに注意
mouseCoordinate :: Float -> Float -> AppState -> (Float, Float)
mouseCoordinate x y app = (x'', y'')
  where
    w = fromIntegral (_W app)
    h = fromIntegral (_H app)
    x' = w / 2 + x
    y' = h / 2 - y
    x''
      | x' <  0   = 0
      | x' >= w   = w - 1
      | otherwise = x'
    y''
      | y' <  0   = 0
      | y' >= h   = h - 1
      | otherwise = y'

----------------------------------
-- 状態の時間変化 (ステップ周期処理)
----------------------------------
onTimer :: Float -> AppState -> AppState
onTimer _ app = app_next -- 引数 Δt は使用しない
  where
    x0 = _x0 app
    y0 = _y0 app
    x0_prev = _x0_prev app
    y0_prev = _y0_prev app
    
    app_next = if (x0 == x0_prev) && (y0 == y0_prev)
      then app -- レンズの中心座標が変化していなければ魚眼画像を更新しない
      else updateFisheye app' -- 魚眼画像を更新
        where app' = app { _x0_prev = x0, _y0_prev = y0 }

--------------------------
-- Bitmap画像の読み込み
--------------------------

-- Bitmapファイルの読み込み
loadDynamicImage :: FilePath -> IO DynamicImage
loadDynamicImage filePath = do
  eitherImage <- readBitmap filePath
  case eitherImage of
    Left  err -> error $ "Error reading bitmap: " ++ err
    Right img -> return img

-- Bitmap画像からRGBAのバイト列を取得
getRGBAfromDynamicImage :: DynamicImage -> VS.Vector Word8
getRGBAfromDynamicImage img = imgVecW8
  where
    imgRGBA8 = convertRGBA8 img    -- DynamicImage -> Image PixelRGBA8
    imgVecW8 = imageData imgRGBA8  -- Image PixelRGBA8 -> Vector Word8

--------------------------
-- 魚眼変換
--------------------------

--魚眼画像の更新
updateFisheye :: AppState -> AppState
updateFisheye app = app'
  where
    w = _W app
    h = _H app
    -- 魚眼変換の関数に状態を部分適用
    fisheye' = fisheye app
    -- 全画素の、魚眼変換の、32ビットRGBA値を、リスト → ByteString に変換
    dstData = listToByteString (map fisheye' [0..h*w-1])
    dstData' = BL.toStrict dstData -- BL.ByteString → ふつうのByteString
    -- ByteStringから画像を生成
    img = bitmapOfByteString w h (BitmapFormat TopToBottom PxRGBA) dstData' True
    app' = app{_dstImg = img}

-- [Word32] を BL.ByteStringに変換 (ビッグエンディアン)
listToByteString :: [Word32] -> BL.ByteString
listToByteString list = BB.toLazyByteString $ mconcat $ map BB.word32BE list

-- 魚眼変換の計算： n番目の画素 -> 32ビットRGBA値
fisheye :: AppState -> Int -> Word32
fisheye app n = c
  where
    w   = fromIntegral (_W app)
    h   = fromIntegral (_H app)
    rad = _R app
    d   = _D app
    x0  = _x0 app
    y0  = _y0 app
    --  写像後の座標 (x', y')
    x'  = fromIntegral (n `mod` _W app)
    y'  = fromIntegral (n `div` _W app)
    -- レンズの中心からの相対座標
    dx = x' - x0
    dy = y' - y0
    d' = sqrt (dx*dx + dy*dy)

    c =
      if d' < rad then
        -- 写像:元画像→魚眼画像
        -- x' = R*x/√(D^2+x^2+y^2)
        -- y' = R*y/√(D^2+x^2+y^2)
        -- 逆写像:魚眼画像→元画像
        -- x = D*X/√(R^2-x'^2-y'^2)
        -- y = D*Y/√(R^2-x'^2-y'^2)
        let z = sqrt (rad*rad - dx*dx - dy*dy);
            x = x0 + (d * dx) / z;
            y = y0 + (d * dy) / z;
        in
        if x >= 0 && x < w && y >= 0 && y < h then
          -- 元画像から線形補間で色を取得
          interpolation app (x, y) -- 写像前の座標 (x, y)
        else
          _black  -- 元画像の外側なら黒塗り
      else
        _black  -- レンズの外側なら黒塗り

--------------------------
-- 線形補間
--------------------------
-- 写像前の座標 (x, y) -> 32ビットRGBA値
interpolation :: AppState -> (Float, Float) -> Word32 
interpolation app (x, y) = c
  where
    -- 座標の整数部
    ix = truncate x
    iy = truncate y
    -- 近傍の4点
    n4 = [getPixel app (ix + i, iy + j) | j <- [0..1], i <- [0..1]]
    (r00, g00, b00) = head n4 -- n4 !! 0
    (r10, g10, b10) = n4 !! 1
    (r01, g01, b01) = n4 !! 2
    (r11, g11, b11) = n4 !! 3
    -- 座標の小数部とその補数
    dX = x - fromIntegral ix;
    dY = y - fromIntegral iy;
    mdX = 1 - dX;
    mdY = 1 - dY;
    -- 線形補間
    r,g,b::Int
    r = round(mdX * (mdY * r00 + dY * r01) + dX * (mdY * r10 + dY * r11))
    g = round(mdX * (mdY * g00 + dY * g01) + dX * (mdY * g10 + dY * g11))
    b = round(mdX * (mdY * b00 + dY * b01) + dX * (mdY * b10 + dY * b11))
    -- 32ビットRGBA値 (A=255)
    c = fromIntegral ( r * 0x1000000 + g * 0x10000 + b * 0x100 + 0xff )

-- 写像前の座標 (x, y) -> RGBA値 (r, g, b)
getPixel :: AppState -> (Int, Int) -> (Float, Float, Float)
getPixel app (x, y) = (r, g, b)
  where
    w = _W app
    h = _H app
    x' = if x >= w then w-1 else x
    y' = if y >= h then h-1 else y
    index = (y' * w + x') * 4;
    srcData = _srcData app
    r = fromIntegral $ VS.unsafeIndex srcData  index
    g = fromIntegral $ VS.unsafeIndex srcData (index + 1)
    b = fromIntegral $ VS.unsafeIndex srcData (index + 2)

-------------
-- main 関数
-------------
main :: IO ()
main = do
  -- 元画像のファイルを読み込み、RGBAのバイト列 [Word8] に変換
  srcImg <- loadDynamicImage "lena_std.bmp"
  let srcData = getRGBAfromDynamicImage srcImg

  -- 画像のサイズ
  let w = dynamicMap imageWidth  srcImg
      h = dynamicMap imageHeight srcImg
      r = fromIntegral w * 0.6
      d = r * 0.3 -- 小さいほど大きく歪む

  -- レンズの中心座標の初期値は中央
  let x0 = fromIntegral w / 2
      y0 = fromIntegral h / 2

  -- アプリケーションの初期状態  (※ dstImgの初期値はダミー)
  let initialState = AppState w h r d x0 y0 0 0 srcData (rectangleSolid 1 1) False
  
  -- 初期状態の魚眼画像を計算
  let initialState' = updateFisheye initialState

  -- printf "W:%d, H:%d, R:%.1f D:%.1f x0:%.1f y0:%.1f\n" w h r d x0 y0

  -- playモードを実行 (イベントと時間による状態遷移あり)
  -- 引数: ウィンドウ, 1秒あたりのステップ数, 初期状態, 
  --       状態の描画関数, イベントによる状態遷移関数, 時間による状態遷移関数
  play window white 20 initialState' onDraw onEvents onTimer

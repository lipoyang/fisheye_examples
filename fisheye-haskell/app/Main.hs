module Main(main) where

import Graphics.Gloss
import Graphics.Gloss.Interface.IO.Interact -- Event
-- import Graphics.Gloss.Internals TODO
-- import Graphics.Gloss.Interface.IO.Game
-- import qualified Data.ByteString.Internal() -- as BS -- (fromForeignPtr)
-- import Foreign.ForeignPtr() -- (ForeignPtr, withForeignPtr)
-- import Foreign.Ptr() -- (plusPtr)
import Codec.Picture
import Data.Word (Word8)
import qualified Data.ByteString as BS
import qualified Data.Vector.Storable as VS
-- import Text.Printf (printf) -- デバッグ用
-- import Debug.Trace (trace)  -- デバッグ用

-------------------
-- 画面の設定
-------------------

windowW, windowH :: Num a => a
windowW = 532
windowH = 532

-- ウィンドウ種別, タイトル, サイズ, 表示位置
window :: Display
window = InWindow "魚眼変換" (windowW, windowH) (100, 100)

--------------------------
-- アプリケーションの状態
--------------------------
data AppState = AppState
  { _W :: Int         -- 元画像の幅
  , _H :: Int         -- 元画像の高さ
  , _R :: Float       -- レンズの半径
  , _D :: Float       -- レンズの中心から投影面までの距離 
  , _x0 :: Float      -- レンズの中心の x 座標 TODO Intに
  , _y0 :: Float      -- レンズの中心の y 座標 TODO Intに
  , _x0_prev :: Float -- レンズの中心の x 座標の前回値 TODO Intに
  , _y0_prev :: Float -- レンズの中心の y 座標の前回値 TODO Intに
  , _x_up :: Float   -- 左ボタン非押下時のマウス x 座標 TODO Intに
  , _y_up :: Float   -- 左ボタン非押下時のマウス y 座標 TODO Intに
  , _x_offset :: Float -- 画像のウインドウ上での x オフセット
  , _y_offset :: Float -- 画像のウインドウ上での y オフセット
  , _srcData :: VS.Vector Word8 --[Word8] -- 元画像データ
  , _dstData :: VS.Vector Word8 --[Word8] -- 表示画像データ
  , _isMouseDown :: Bool -- マウスを押下しているか
  }

-- 初期値
initialState :: AppState
initialState = AppState 0 0 0 0 0 0 0 0 0 0 0 0 VS.empty VS.empty False

--------------------------
-- 描画
--------------------------
onDraw :: AppState -> Picture
onDraw app = img
    where
        w = _W app
        h = _H app
        bstr = BS.pack $ VS.toList $ _dstData app -- [VS.Vector Word8] -> ByteString
        img = bitmapOfByteString w h (BitmapFormat TopToBottom PxRGBA) bstr True

--------------------------
-- イベント処理
--------------------------
onEvents :: Event -> AppState -> AppState
onEvents (EventKey key ks _ _) app = onMouseButton key ks app
onEvents (EventMotion (x, y))  app = onMouseMove x y app
onEvents (EventResize _)       app = app

-- マウスの左ボタンUP/DOWN
onMouseButton :: Key -> KeyState -> AppState -> AppState
onMouseButton (MouseButton LeftButton) ks = if ks == Down then onMouseDown else onMouseUp 
onMouseButton _ _ = id
-- UP
onMouseUp:: AppState -> AppState
onMouseUp app = app{_isMouseDown = False}
-- DOWN
onMouseDown:: AppState -> AppState
onMouseDown app = app{_isMouseDown = True, _x0 = _x_up app, _y0 = _y_up app}
-- マウスの移動
onMouseMove:: Float -> Float -> AppState -> AppState
onMouseMove x y app = if _isMouseDown app then app{_x0 = x'', _y0 = y''} else app{_x_up = x'', _y_up = y''}
  where
    w = fromIntegral (_W app)
    h = fromIntegral (_H app)
    x' = windowW / 2 + x - _x_offset app
    y' = windowH / 2 - y - _y_offset app
    x''
      | x' <  0   = 0
      | x' >= w   = w - 1
      | otherwise = x'
    y''
      | y' <  0   = 0
      | y' >= h   = h - 1
      | otherwise = y'

--------------------------
-- 状態の時間変化
--------------------------
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
        Left err -> error $ "Error reading bitmap: " ++ err
        Right img -> return img

-- Bitmap画像からRGBAのバイト列を取得
getRGBAfromDynamicImage :: DynamicImage -> VS.Vector Word8 --[Word8]
getRGBAfromDynamicImage img = imgW8Vec --imgW8List
    where
        imgRGBA   = convertRGBA8 img    -- DynamicImage -> Image PixelRGBA8
        imgW8Vec  = imageData imgRGBA   -- Image PixelRGBA8 -> Vector Word8

--------------------------
-- 魚眼変換
--------------------------
-- 画像の魚眼変換
updateFisheye :: AppState -> AppState
updateFisheye app = app'
  where
    w = _W app
    h = _H app
    rgba = [fisheye app (x, y) | y <- [0..h-1], x <- [0..w-1]]
    dstData = VS.fromList $ flattenTupleList rgba
    app' = app{_dstData = dstData}

-- (R,G,B,A) のリストをフラットなリストに変換
flattenTupleList :: [(Word8, Word8, Word8, Word8)] -> [Word8]
flattenTupleList tupleList = [item | (a, b, c, d) <- tupleList, item <- [a, b, c, d]]

-- 魚眼変換の計算： 写像後の座標 (x, y) -> RGBA値 (r, g, b, a)
fisheye :: AppState -> (Int, Int) -> (Word8, Word8, Word8, Word8)
fisheye app (ix, iy) = (r, g, b, a)
  where
    rad = _R app
    d   = _D app
    w   = fromIntegral (_W app)
    h   = fromIntegral (_H app)
    x   = fromIntegral ix
    y   = fromIntegral iy
    x0  = _x0 app
    y0  = _y0 app
    -- レンズの中心からの相対座標
    dx = x - x0
    dy = y - y0
    d' = sqrt (dx*dx + dy*dy)

    (r, g, b, a) =
      if d' < rad then
        -- 写像:元画像→魚眼画像
        -- X = R*x/√(D^2+x^2+y^2)
        -- Y = R*y/√(D^2+x^2+y^2)
        -- 逆写像:魚眼画像→元画像
        -- x = D*X/√(R^2-X^2-Y^2)
        -- y = D*Y/√(R^2-X^2-Y^2)
        let z = sqrt (rad*rad - dx*dx - dy*dy);
            x' = x0 + (d * dx) / z;
            y' = y0 + (d * dy) / z;
        in
        if x' >= 0 && x' < w && y' >= 0 && y' < h then
          -- 元画像から線形補間で色を取得
          interpolation app (x', y')
        else
          -- 元画像の外側なら黒塗り
          (0, 0, 0, 255) -- TODO BLACK
      else 
        -- レンズの外側なら黒塗り
        (0, 0, 0, 255) -- TODO BLACK

--------------------------
-- 線形補間
--------------------------
-- 写像前の座標 (x, y) -> RGBA値 (r, g, b, a)
interpolation :: AppState -> (Float, Float) -> (Word8, Word8, Word8, Word8)
interpolation app (x, y) = (r, g, b, 255)
  where
    -- 座標の整数部
    x' = truncate x
    y' = truncate y
    -- 近傍の4点
    n4 = [getPixel app (x' + i, y' + j) | j <- [0..1], i <- [0..1]]
    (r00, g00, b00) = head n4 -- n4 !! 0
    (r10, g10, b10) = n4 !! 1
    (r01, g01, b01) = n4 !! 2
    (r11, g11, b11) = n4 !! 3
    -- 座標の小数部とその補数
    dX = x - fromIntegral x';
    dY = y - fromIntegral y';
    mdX = 1 - dX;
    mdY = 1 - dY;
    -- 線形補間
    r = round(mdX * (mdY * r00 + dY * r01) + dX * (mdY * r10 + dY * r11))
    g = round(mdX * (mdY * g00 + dY * g01) + dX * (mdY * g10 + dY * g11))
    b = round(mdX * (mdY * b00 + dY * b01) + dX * (mdY * b10 + dY * b11))

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
    r = fromIntegral $ VS.unsafeIndex srcData index
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
  let w = dynamicMap imageWidth srcImg
      h = dynamicMap imageHeight srcImg
      r = fromIntegral w * 0.6
      d = r * 0.3 -- 小さいほど大きく歪む
      x_offset = (windowW - fromIntegral w) / 2
      y_offset = (windowH - fromIntegral h) / 2

  -- レンズの中心座標の初期値は中央
  let x0 = fromIntegral w / 2
      y0 = fromIntegral h / 2

  -- アプリケーションの初期状態を設定
  let initialState2 = initialState{
      _srcData = srcData,
      _W = w, _H = h, _R = r, _D = d, _x0 = x0, _y0 = y0,
      _x_offset = x_offset, _y_offset = y_offset
    }
  -- let format = "W:%d, H:%d, R:%.1f D:%.1f x0:%.1f y0:%.1f x_offset:%.1f y_offset:%.1f\n"
  -- printf format w h r d x0 y0 x_offset y_offset
  
  -- 助期状態の魚眼画像を計算
  let initialState3 = updateFisheye initialState2

  -- playモードを実行 (イベントと時間による状態遷移あり)
  -- 引数: ウィンドウ, 1秒あたりのステップ数, 初期状態, 
  --       状態の描画関数, イベントによる状態遷移関数, 時間による状態遷移関数
  play window white 10 initialState3 onDraw onEvents onTimer

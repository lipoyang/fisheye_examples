package com.example.fisheye

import android.content.Context
import android.graphics.*
import android.util.AttributeSet
import android.util.Log
import android.view.MotionEvent
import android.view.View

// 魚眼画像表示ビュー
class FisheyeView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyle: Int = 0
) : View(context, attrs, defStyle) {
    private lateinit var srcImg: Bitmap // 元画像
    private lateinit var srcData: IntArray
    private lateinit var dstImg: Bitmap // 処理後の画像
    private lateinit var dstData: IntArray
    private var W: Int = 0 // 画像のサイズ
    private var H: Int = 0
    private var RAD: Float = 0f // レンズの半径
    private var D: Float = 0f // レンズの中心から投影面までの距離
    private var x0: Int = 0 // レンズの中心座標
    private var y0: Int = 0
    private val BLACK: Int = Color.argb(255, 0, 0, 0) // 黒色
    private var x0_prev: Int = 0 // レンズの中心座標の前回値
    private var y0_prev: Int = 0
    private var W2: Int = 0 // 表示サイズ (画像サイズより画面が小さい場合があるため)
    private var H2: Int = 0
    private var mag: Float = 0f // 倍率 (画像横幅 / 表示横幅)
    private var mag2: Float = 0f // 倍率 (画面横幅 / 表示横幅)

    // 線形補間用のバッファ (高速化のためグローバル変数に)
    private val _R = Array(2) { FloatArray(2) }
    private val _G = Array(2) { FloatArray(2) }
    private val _B = Array(2) { FloatArray(2) }

    init {
        init()
    }

    // 初期化
    private fun init() {
        // 画像読み込み
        val options = BitmapFactory.Options()
        options.inScaled = false // スケーリングせずドットバイドットで
        srcImg = BitmapFactory.decodeResource(resources, R.drawable.lena_std, options)
        // 画像サイズ
        W = srcImg.width
        H = srcImg.height
        RAD = W.toFloat() * 0.6f
        D = RAD * 0.3f // 小さいほど大きく歪む

        srcData = IntArray(W * H)
        srcImg.getPixels(srcData, 0, W, 0, 0, W, H)
    }

    // ビューのサイズが変更されたとき
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        // 表示サイズ (画像サイズより画面が小さい場合があるため)
        W2 = W
        H2 = H
        mag = 1f
        val cW = width
        val cH = height
        val cL = if (cW < cH) cW else cH
        if (cL < W) {
            W2 = cL
            H2 = cL
            mag = W.toFloat() / W2.toFloat()
        }
        dstImg = Bitmap.createBitmap(W2, H2, Bitmap.Config.ARGB_8888)
        dstData = IntArray(W2 * H2)
        // 表示倍率
        mag2 = cL.toFloat() / W2.toFloat()

        // レンズの中心座標の初期値は中央
        x0 = W2 / 2
        y0 = H2 / 2
        x0_prev = 0
        y0_prev = 0

        // 描画
        draw()
    }

    // ビューの描画
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (::dstImg.isInitialized) {
            canvas.save()
            canvas.scale(mag2, mag2)
            canvas.drawBitmap(dstImg, 0f, 0f, Paint())
            canvas.restore()
        }
    }

    // タッチイベント
    override fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.action) {
            MotionEvent.ACTION_DOWN, MotionEvent.ACTION_MOVE, MotionEvent.ACTION_UP -> {
                x0 = (event.x / mag2).toInt()
                y0 = (event.y / mag2).toInt()
                if (x0 < 0) x0 = 0
                if (x0 >= W2) x0 = W2 - 1
                if (y0 < 0) y0 = 0
                if (y0 >= H2) y0 = H2 - 1
                // レンズの中心座標が変化していなければ描画しない
                if ((x0 == x0_prev) && (y0 == y0_prev)) {
                    return true
                }
                x0_prev = x0
                y0_prev = y0
                draw()
                invalidate() // ビューを再描画
                return true
            }
        }
        return super.onTouchEvent(event)
    }
    // 描画
    private fun draw() {
        // val startTime = System.currentTimeMillis()

        // 写像後の座標
        for (Y in 0 until H2) {
            val Y_offset = Y * W2
            for (X in 0 until W2) {
                var c: Int
                // レンズの中心からの相対座標
                val dX = (X - x0) * mag
                val dY = (Y - y0) * mag
                val d = fastSqrt(dX * dX + dY * dY)
                if (d < RAD) {
                    // 写像:元画像→魚眼画像
                    // X = R*x/√(D^2+x^2+y^2)
                    // Y = R*y/√(D^2+x^2+y^2)
                    // 逆写像:魚眼画像→元画像
                    // x = D*X/√(R^2-X^2-Y^2)
                    // y = D*Y/√(R^2-X^2-Y^2)
                    val Z = fastSqrt(RAD * RAD - dX * dX - dY * dY)
                    val x = x0 * mag + (D * dX) / Z
                    val y = y0 * mag + (D * dY) / Z

                    c = if (x >= 0 && x < W && y >= 0 && y < H) {
                        interpolation(x, y) // 元画像から線形補間で色を取得
                    } else {
                        BLACK // 元画像の外側なら黒塗り
                    }
                } else {
                    c = BLACK // レンズの外側なら黒塗り
                }
                dstData[Y_offset + X] = c
            }
        }
        dstImg.setPixels(dstData, 0, W2, 0, 0, W2, H2)

        // val elapsedTime = System.currentTimeMillis() - startTime
        // Log.d("draw", "time: $elapsedTime msec")
    }
    // 線形補間
    private fun interpolation(x: Float, y: Float): Int {
        val X = x.toInt()
        val Y = y.toInt()
        for (i in 0..1) {
            for (j in 0..1) {
                var _x = X + i
                if (_x >= W) _x = X
                var _y = Y + j
                if (_y >= H) _y = Y
                val c = srcData[_y * W + _x]
                _R[i][j] = ((c shr 16) and 0xFF).toFloat()
                _G[i][j] = ((c shr 8) and 0xFF).toFloat()
                _B[i][j] = (c and 0xFF).toFloat()
            }
        }
        val dX = x - X.toFloat()
        val dY = y - Y.toFloat()
        val MdX = 1 - dX
        val MdY = 1 - dY
        val r = fastRound(MdX * (MdY * _R[0][0] + dY * _R[0][1]) + dX * (MdY * _R[1][0] + dY * _R[1][1]))
        val g = fastRound(MdX * (MdY * _G[0][0] + dY * _G[0][1]) + dX * (MdY * _G[1][0] + dY * _G[1][1]))
        val b = fastRound(MdX * (MdY * _B[0][0] + dY * _B[0][1]) + dX * (MdY * _B[1][0] + dY * _B[1][1]))
        return 0xFF000000.toInt() or (r shl 16) or (g shl 8) or b
    }

    // Math.sqrt(平方根計算)の高速化
    private fun fastSqrt(x: Float): Float {
        var x = x
        val xhalf = 0.5f * x
        var i = java.lang.Float.floatToIntBits(x)
        i = 0x5f3759df - (i shr 1)
        x = java.lang.Float.intBitsToFloat(i)
        x = x * (1.5f - xhalf * x * x)
        return 1.0f / x
    }

    // Math.round(四捨五入)の高速化
    private fun fastRound(v: Float): Int {
        val l = (v * 2).toInt()
        return (l shr 1) + (l and 0x1)
    }
}
package com.example.fisheye;

import android.content.Context;
import android.graphics.*;
import android.util.AttributeSet;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;

// 魚眼画像表示ビュー
public class FisheyeView  extends View {

    Bitmap srcImg; // 元画像
    int[] srcData;
    Bitmap dstImg; // 処理後の画像
    int[] dstData;
    int W, H; // 画像のサイズ
    float RAD; // レンズの半径
    float D; // レンズの中心から投影面までの距離
    int x0,y0; // レンズの中心座標

    final int BLACK = Color.argb(255, 0, 0, 0); // 黒色
    int x0_prev, y0_prev; // レンズの中心座標の前回値
    int W2, H2; // 表示サイズ (画像サイズより画面が小さい場合があるため)
    float mag;  // 倍率 (画像横幅 / 表示横幅)
    float mag2; // 倍率 (画面横幅 / 表示横幅)

    // 線形補間用のバッファ (高速化のためグローバル変数に)
    float[][] _R = new float[2][2];
    float[][] _G = new float[2][2];
    float[][] _B = new float[2][2];

    // コンストラクタ
    public FisheyeView(Context context) {
        super(context);
        init();
    }
    public FisheyeView(Context context, AttributeSet attrs) {
        super(context, attrs);
        init();
    }
    public FisheyeView(Context context, AttributeSet attrs, int defStyle) {
        super(context, attrs, defStyle);
        init();
    }

    // 初期化
    private void init() {
        // 画像読み込み
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inScaled = false; // スケーリングせずドットバイドットで
        srcImg = BitmapFactory.decodeResource(getResources(), R.drawable.lena_std, options);
        // 画像サイズ
        W = srcImg.getWidth();
        H = srcImg.getHeight();
        RAD = (float)W * 0.6f;
        D = RAD * 0.3f; // 小さいほど大きく歪む

        srcData = new int[W * H];
        srcImg.getPixels(srcData, 0, W, 0, 0, W, H);
    }

    // ビューのサイズが変更されたとき
    @Override
    protected void onSizeChanged (int w, int h, int oldw, int oldh){
        // 表示サイズ (画像サイズより画面が小さい場合があるため)
        W2 = W;
        H2 = H;
        mag = 1;
        int cW = getWidth();
        int cH = getHeight();
        int cL = (cW < cH) ? cW : cH;
        if(cL < W){
            W2 = H2 = cL;
            mag = (float)W / (float)W2;
        }
        dstImg = Bitmap.createBitmap(W2, H2, Bitmap.Config.ARGB_8888);
        dstData = new int[W2 * H2];
        // 表示倍率
        mag2 = (float)cL / (float)W2;

        // レンズの中心座標の初期値は中央
        x0 = W2 / 2;
        y0 = H2 / 2;
        x0_prev = 0;
        y0_prev = 0;

        // 描画
        draw();
    }

    // ビューの描画
    @Override
    protected void onDraw(Canvas canvas) {
        super.onDraw(canvas);
        if (dstImg != null) {
            canvas.save();
            canvas.scale(mag2, mag2);
            canvas.drawBitmap(dstImg, 0, 0, new Paint());
            canvas.restore();
        }
    }

    // タッチイベント
    @Override
    public boolean onTouchEvent(MotionEvent event) {
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
            case MotionEvent.ACTION_MOVE:
            case MotionEvent.ACTION_UP:
                x0 = (int)(event.getX() / mag2);
                y0 = (int)(event.getY() / mag2);
                if (x0 <  0 ) x0 = 0;
                if (x0 >= W2) x0 = W2 - 1;
                if (y0 <  0 ) y0 = 0;
                if (y0 >= H2) y0 = H2 - 1;
                // レンズの中心座標が変化していなければ描画しない
                if((x0 == x0_prev) && (y0 == y0_prev)){
                    return true;
                }
                x0_prev = x0;
                y0_prev = y0;
                draw();
                invalidate(); // ビューを再描画
                return true;
        }
        return super.onTouchEvent(event);
    }

    // 描画
    void draw() {
        long startTime = System.currentTimeMillis();

        // 写像後の座標
        for(int Y = 0; Y < H2; Y++){
            int Y_offset = Y * W2;
            for(int X = 0; X < W2; X++){
                int c;
                // レンズの中心からの相対座標
                float dX = (float)(X - x0) * mag;
                float dY = (float)(Y - y0) * mag;
                float d = fastSqrt(dX*dX + dY*dY);
                if(d < RAD){
                    // 写像:元画像→魚眼画像
                    // X = R*x/√(D^2+x^2+y^2)
                    // Y = R*y/√(D^2+x^2+y^2)
                    // 逆写像:魚眼画像→元画像
                    // x = D*X/√(R^2-X^2-Y^2)
                    // y = D*Y/√(R^2-X^2-Y^2)
                    float Z = fastSqrt(RAD*RAD - dX*dX - dY*dY);
                    float x = x0*mag + (D * dX) / Z;
                    float y = y0*mag + (D * dY) / Z;

                    if(x >= 0 && x < W && y >= 0 && y < H){
                        c = interpolation(x, y); // 元画像から線形補間で色を取得
                    }else{
                        c = BLACK; // 元画像の外側なら黒塗り
                    }
                }else{
                    c = BLACK; // レンズの外側なら黒塗り
                }
                // dstImg.setPixel(X, Y, c);
                dstData[Y_offset + X] = c;
            }
        }
        dstImg.setPixels(dstData, 0, W2, 0, 0, W2, H2);

        long elapsedTime = System.currentTimeMillis() - startTime;
        Log.d("draw", "time: " + elapsedTime + " msec");
    }

    // 線形補間
    int interpolation(float x, float y)
    {
        int X = (int)x;
        int Y = (int)y;
        for(int i = 0; i <= 1; i++){
            for(int j = 0; j <= 1; j++){
                int _x = X + i; if (_x >= W) _x = X;
                int _y = Y + j; if (_y >= H) _y = Y;
                // int c = srcImg.getPixel(_x, _y);
                // _R[i][j] = Color.red(c);
                // _G[i][j] = Color.green(c);
                // _B[i][j] = Color.blue(c);
                int c = srcData[_y * W + _x];
                _R[i][j] = (float)((c >> 16) & 0xFF);
                _G[i][j] = (float)((c >>  8) & 0xFF);
                _B[i][j] = (float)((c      ) & 0xFF);
            }
        }
        float dX = x - (float)X;
        float dY = y - (float)Y;
        float MdX = 1 - dX;
        float MdY = 1 - dY;
        int r = (int)fastRound(MdX * (MdY * _R[0][0] + dY * _R[0][1]) + dX * (MdY * _R[1][0] + dY * _R[1][1]));
        int g = (int)fastRound(MdX * (MdY * _G[0][0] + dY * _G[0][1]) + dX * (MdY * _G[1][0] + dY * _G[1][1]));
        int b = (int)fastRound(MdX * (MdY * _B[0][0] + dY * _B[0][1]) + dX * (MdY * _B[1][0] + dY * _B[1][1]));
        // int ret = Color.argb(255, r, g, b);
        int ret = 0xFF000000 | (r << 16) | (g << 8) | b;
        return ret;
    }

    // Math.sqrt(平方根計算)の高速化
    static float fastSqrt(float x) {
        float xhalf = 0.5f * x;
        int i = Float.floatToIntBits(x);
        i = 0x5f3759df - (i >> 1);
        x = Float.intBitsToFloat(i);
        x = x * (1.5f - xhalf * x * x);
        return 1.0f / x;
    }

    // Math.round(四捨五入)の高速化
    static int fastRound(float v){
        int l = (int) (v * 2);
        return (l >> 1) + (l & 0x1);
    }
}

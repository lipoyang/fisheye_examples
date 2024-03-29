#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

static int W = 0;  // 画像の幅
static int H = 0;  // 画像の高さ
static double RAD; // レンズの半径
static double D;   // レンズの中心から投影面までの距離
static uint8_t  *srcData = NULL; // 元画像のバッファ
static uint32_t *dstData = NULL; // 表示画像のバッファ

const uint32_t BLACK = 0xFF000000; // 黒色

uint32_t interpolation(double x, double y); // 線形補間

// 初期化
// src: 元画像のRGBバイト列
// w, h: 元画像の幅と高さ
void begin(uint8_t* src, int w, int h)
{
    // 全画素数
    int pixels = w * h;
    // 元画像のデータをバッファにコピー (RGBのバイト列)
    int size = sizeof(uint8_t)  * pixels * 3;
    srcData = (uint8_t*)malloc(size);
    memcpy(srcData, src, size);
    // 表示画像のデータバッファを確保 (32ビットカラー値(ABGR)の列)
    dstData = (uint32_t*) malloc(sizeof(uint32_t) * pixels);
    
    W = w;
    H = h;
    RAD = W * 0.6;
    D = RAD * 0.3; // 小さいほど大きく歪む
}

// 魚眼変換の計算
// x0, y0: レンズの中心座標
// return: 表示画像のバッファ
uint32_t* calc(int x0, int y0)
{
    // 写像後の座標
    for (int Y = 0; Y < H; Y++) {
        int Yoffset = Y * W;
        for (int X = 0; X < W; X++) {
            uint32_t c;
            
            // レンズの中心からの相対座標
            int dX = X - x0;
            int dY = Y - y0;
            double d = sqrt(dX*dX + dY*dY);
            if (d < RAD) {
                // 写像:元画像→魚眼画像
                // X = R*x/√(D^2+x^2+y^2)
                // Y = R*y/√(D^2+x^2+y^2)
                // 逆写像:魚眼画像→元画像
                // x = D*X/√(R^2-X^2-Y^2)
                // y = D*Y/√(R^2-X^2-Y^2)
                double Z = sqrt(RAD*RAD - dX*dX - dY*dY);
                double x = x0 + (D * dX) / Z;
                double y = y0 + (D * dY) / Z;

                if (x >= 0 && x < W && y >= 0 && y < H) {
                    // 元画像から線形補間で色を取得
                    c = interpolation(x, y);
                } else {
                    c = BLACK; // 元画像の外側なら黒塗り
                }
            } else {
                c = BLACK; // レンズの外側なら黒塗り
            }
            dstData[Yoffset + X] = c;
        }
    }
    return dstData;
}

// 線形補間
uint32_t interpolation(double x, double y)
{
    static double R[2][2];
    static double G[2][2];
    static double B[2][2];

    int X = (int)x;
    int Y = (int)y;

    for (int i = 0; i <= 1; i++) {
        for (int j = 0; j <= 1; j++) {
            int _x = X + i; if (_x >= W) _x = X;
            int _y = Y + j; if (_y >= H) _y = Y;

            int index = (_y * W + _x) * 3;
            R[i][j] = srcData[index + 0];
            G[i][j] = srcData[index + 1];
            B[i][j] = srcData[index + 2];
        }
    }
    double dX = x - (double)X;
    double dY = y - (double)Y;
    double MdX = 1 - dX;
    double MdY = 1 - dY;
    
    uint32_t r,g,b;
    r = (uint8_t)round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]));
    g = (uint8_t)round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]));
    b = (uint8_t)round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]));
    uint32_t c = 0xFF000000 | ((b << 16) & 0xFF0000) | ((g << 8) & 0xFF00) | (r & 0xFF);
    return c;
}

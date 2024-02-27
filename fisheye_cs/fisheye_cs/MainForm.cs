using System;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;
using System.Drawing.Imaging;

namespace fisheye_cs
{
    public partial class MainForm : Form
    {
        Bitmap srcImg; // 元画像
        Bitmap dstImg; // 処理後の画像
        int W, H; // 画像のサイズ
        int RAD; // レンズの半径
        int D; // レンズの中心から投影面までの距離
        int x0, y0; // レンズの中心座標

        byte[] BLACK = { 0, 0, 0 }; // 黒色
        int x0_prev, y0_prev; // レンズの中心座標の前回値
        Stopwatch stopwatch = new Stopwatch(); // デバッグ用

        // 線形補間用のバッファ (高速化のためグローバル変数に)
        double[,] R = new double[2, 2];
        double[,] G = new double[2, 2];
        double[,] B = new double[2, 2];

        // 高速化のためLockBitsを使用
        BitmapData srcImgData;
        int srcPixelBytes; // 1ピクセルあたりのバイト数
        int srcStride;     // 1ラインあたりのバイト数
        IntPtr srcPtr;

        // 初期化
        public MainForm()
        {
            InitializeComponent();
            
            // 画像読み込み
            Image img = Image.FromFile("lena_std.bmp");
            srcImg = (Bitmap)img.Clone();

            W = srcImg.Width;
            H = srcImg.Height;
            RAD = (int)(W * 0.6);
            D = (int)(RAD * 0.3); // 小さいほど大きく歪む
            
            dstImg = new Bitmap(W, H, PixelFormat.Format24bppRgb);

            // レンズの中心座標の初期値は中央
            x0 = W / 2;
            y0 = H / 2;
            x0_prev = 0;
            y0_prev = 0;

            // 高速化のためLockBitsを使用
            srcImgData = srcImg.LockBits(
                new Rectangle(0, 0, srcImg.Width, srcImg.Height),
                ImageLockMode.ReadWrite, srcImg.PixelFormat);
            srcPixelBytes = Image.GetPixelFormatSize(srcImg.PixelFormat) / 8;
            srcStride = srcImgData.Stride;
            srcPtr = srcImgData.Scan0;
        }

        // マウスイベント
        private void pictureBox_MouseDown(object sender, MouseEventArgs e)
        {
            x0 = e.X;
            y0 = e.Y;
            pictureBox.Invalidate();
        }
        private void pictureBox_MouseMove(object sender, MouseEventArgs e)
        {
            if ((MouseButtons & MouseButtons.Left) == MouseButtons.Left){
                x0 = e.X;
                y0 = e.Y;
                pictureBox.Invalidate();
            }
        }
        private void pictureBox_MouseUp(object sender, MouseEventArgs e)
        {
            x0 = e.X;
            y0 = e.Y;
            pictureBox.Invalidate();
        }

        // 描画イベント
        private void pictureBox_Paint(object sender, PaintEventArgs e)
        {
            if (x0 <  0) x0 = 0;
            if (x0 >= W) x0 = W - 1;
            if (y0 <  0) y0 = 0;
            if (y0 >= H) y0 = H - 1;
            
            // レンズの中心座標が変化していなければ描画しない
            if ((x0 == x0_prev) && (y0 == y0_prev)){
                return;
            }
            x0_prev = x0;
            y0_prev = y0;

            draw();
        }
        
        // 描画
        void draw()
        {
            //Console.WriteLine("draw");
            //stopwatch.Restart();

            // 高速化のためLockBitsを使用
            BitmapData dstImgData = dstImg.LockBits(
                new Rectangle(0, 0, dstImg.Width, dstImg.Height),
                ImageLockMode.ReadWrite, dstImg.PixelFormat);
            int dstPixelBytes = Image.GetPixelFormatSize(dstImg.PixelFormat) / 8;
            int dstStride = dstImgData.Stride;
            IntPtr dstPtr = dstImgData.Scan0;

            // 写像後の座標
            for (int Y = 0; Y < H; Y++) {
                for (int X = 0; X < W; X++) {
                    //Color c;
                    byte[] c;

                    // レンズの中心からの相対座標
                    int dX = X - x0;
                    int dY = Y - y0;
                    double d = Math.Sqrt(dX*dX + dY*dY);
                    if (d < RAD) {
                        // 写像:元画像→魚眼画像
                        // X = R*x/√(D^2+x^2+y^2)
                        // Y = R*y/√(D^2+x^2+y^2)
                        // 逆写像:魚眼画像→元画像
                        // x = D*X/√(R^2-X^2-Y^2)
                        // y = D*Y/√(R^2-X^2-Y^2)
                        double Z = Math.Sqrt(RAD*RAD - dX*dX - dY*dY);
                        double x = x0 + (D * dX) / Z;
                        double y = y0 + (D * dY) / Z;

                        if (x >= 0 && x < W && y >= 0 && y < H) {
                            c = interpolation(x, y); // 元画像から線形補間で色を取得
                        } else {
                            //c = Color.Black; // 元画像の外側なら黒塗り
                            c = BLACK;
                        }
                    } else {
                        //c = Color.Black; // レンズの外側なら黒塗り
                        c = BLACK;
                    }
                    // SetPixelでは遅いので高速化
                    // dstImg.SetPixel(X, Y, c);
                    unsafe
                    {
                        byte* ptr = (byte*)dstPtr.ToPointer();
                        int index = Y * dstStride + X * dstPixelBytes;
                        ptr[index + 2] = c[0];
                        ptr[index + 1] = c[1];
                        ptr[index + 0] = c[2];
                    }
                }
            }
            pictureBox.Image = dstImg;

            dstImg.UnlockBits(dstImgData); // アンロックを忘れずに！

            // stopwatch.Stop();
            // Console.WriteLine($"処理時間: {stopwatch.ElapsedMilliseconds} ミリ秒");
        }

        // 線形補間
//      Color interpolation(double x, double y)
        byte[] interpolation(double x, double y)
        {
            int X = (int)x;
            int Y = (int)y;

            for (int i = 0; i <= 1; i++) {
                for (int j = 0; j <= 1; j++) {
                    int _x = X + i; if (_x >= W) _x = X;
                    int _y = Y + j; if (_y >= H) _y = Y;

                    // GetPixelでは遅いので高速化
                    // Color c = srcImg.GetPixel(_x, _y);
                    // R[i, j] = c.R;
                    // G[i, j] = c.G;
                    // B[i, j] = c.B;
                    unsafe
                    {
                        byte* ptr = (byte*)srcPtr.ToPointer();
                        int index = _y * srcStride + _x * srcPixelBytes;
                        R[i, j] = ptr[index + 2];
                        G[i, j] = ptr[index + 1];
                        B[i, j] = ptr[index + 0];
                    }
                }
            }
            double dX = x - (int)x;
            double dY = y - (int)y;
            double MdX = 1 - dX;
            double MdY = 1 - dY;
            byte r = (byte)Math.Round(MdX * (MdY * R[0, 0] + dY * R[0, 1]) + dX * (MdY * R[1, 0] + dY * R[1, 1]));
            byte g = (byte)Math.Round(MdX * (MdY * G[0, 0] + dY * G[0, 1]) + dX * (MdY * G[1, 0] + dY * G[1, 1]));
            byte b = (byte)Math.Round(MdX * (MdY * B[0, 0] + dY * B[0, 1]) + dX * (MdY * B[1, 0] + dY * B[1, 1]));
            //Color ret = Color.FromArgb(r, g, b);
            byte[] ret = { r, g, b };
            return ret;
        }
    }
}

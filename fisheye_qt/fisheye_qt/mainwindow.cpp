#include "mainwindow.h"
#include "./ui_mainwindow.h"
#include <QMouseEvent>
#include <QtCore/QDebug> // デバッグ用

// コンストラクタ
MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    //BLACK = QColor(0,0,0);
    BLACK[0] = BLACK[1] = BLACK[2] = 0;

    // 画像読み込み
    srcImg = new QImage("./resource/lena_std.bmp");
    srcData = srcImg->bits();

    W = srcImg->width();
    H = srcImg->height();
    RAD = (int)(W * 0.6);
    D = (int)(RAD * 0.3); // 小さいほど大きく歪む

    dstImg = new QImage(W, H, QImage::Format_RGB32);
    dstData = dstImg->bits();

    // レンズの中心座標の初期値は中央
    x0 = W / 2;
    y0 = H / 2;
    x0_prev = 0;
    y0_prev = 0;
}
// デストラクタ
MainWindow::~MainWindow()
{
    delete ui;
}

// マウスイベント
void MainWindow::mousePressEvent(QMouseEvent *event)
{
    QPoint p = event->pos();
    x0 = p.x() - 10; // (10, 10)はラベルのオフセット位置
    y0 = p.y() - 10;
    update();
}
void MainWindow::mouseMoveEvent(QMouseEvent *event)
{
    if (event->buttons() & Qt::LeftButton){
        QPoint p = event->pos();
        x0 = p.x() - 10; // (10, 10)はラベルのオフセット位置
        y0 = p.y() - 10;
        update();
    }
}
void MainWindow::mouseReleaseEvent(QMouseEvent *event)
{
    QPoint p = event->pos();
    x0 = p.x() - 10; // (10, 10)はラベルのオフセット位置
    y0 = p.y() - 10;
    update();
}

// 描画イベント
void MainWindow::paintEvent(QPaintEvent *event)
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
void MainWindow::draw()
{
    // timer.start();

    // 写像後の座標
    for (int Y = 0; Y < H; Y++) {
        int Yoffset = Y * W;
        for (int X = 0; X < W; X++) {
            // QColor c;
            uchar* c;

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
                    //c = interpolation(x, y); // 元画像から線形補間で色を取得
                    c = interpolation(x, y);
                } else {
                    //c = Color.Black; // 元画像の外側なら黒塗り
                    c = BLACK;
                }
            } else {
                //c = Color.Black; // レンズの外側なら黒塗り
                c = BLACK;
            }
            // dstImg->setPixelColor(X, Y, c);
            int index = (Yoffset + X) * 4;
            dstData[index + 2] = c[2];
            dstData[index + 1] = c[1];
            dstData[index + 0] = c[0];
        }
    }
    QPixmap pixmap = QPixmap::fromImage(*dstImg);
    ui->label->setPixmap(pixmap);

    // qint64 elapsedTime = timer.elapsed();
    // qDebug() << "time: " << elapsedTime << "msec";
}

// 線形補間
// QColor MainWindow::interpolation(double x, double y)
uchar* MainWindow::interpolation(double x, double y)
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

            //QColor c = srcImg->pixelColor(_x, _y);
            //R[i][j] = c.red();
            //G[i][j] = c.green();
            //B[i][j] = c.blue();
            int index = (_y * W + _x) * 4;
            R[i][j] = srcData[index + 2];
            G[i][j] = srcData[index + 1];
            B[i][j] = srcData[index + 0];
        }
    }
    double dX = x - (double)X;
    double dY = y - (double)Y;
    double MdX = 1 - dX;
    double MdY = 1 - dY;
//  int r = (int)round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]));
//  int g = (int)round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]));
//  int b = (int)round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]));
//  QColor ret(r,g,b);
//  return ret;
    static uchar ret[3];
    ret[2] = (uchar)round(MdX * (MdY * R[0][0] + dY * R[0][1]) + dX * (MdY * R[1][0] + dY * R[1][1]));
    ret[1] = (uchar)round(MdX * (MdY * G[0][0] + dY * G[0][1]) + dX * (MdY * G[1][0] + dY * G[1][1]));
    ret[0] = (uchar)round(MdX * (MdY * B[0][0] + dY * B[0][1]) + dX * (MdY * B[1][0] + dY * B[1][1]));
    return ret;
}

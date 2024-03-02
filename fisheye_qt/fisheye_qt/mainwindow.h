#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QMouseEvent>
#include <QElapsedTimer> // デバッグ用

QT_BEGIN_NAMESPACE
namespace Ui {
class MainWindow;
}
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

protected:
    void mousePressEvent(QMouseEvent *event) override;
    void mouseMoveEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;
    void paintEvent(QPaintEvent *event) override;

private:
    Ui::MainWindow *ui;

    QImage *srcImg; // 元画像
    uchar  *srcData;
    QImage *dstImg; // 処理後の画像
    uchar  *dstData;
    int W, H; // 画像のサイズ
    int RAD; // レンズの半径
    int D; // レンズの中心から投影面までの距離
    int x0, y0; // レンズの中心座標

//  QColor BLACK; // 黒色
    uchar  BLACK[3];
    int x0_prev, y0_prev; // レンズの中心座標の前回値
    QElapsedTimer timer; // デバッグ用

    void draw();
//  QColor interpolation(double x, double y);
    uchar* interpolation(double x, double y);
};
#endif // MAINWINDOW_H

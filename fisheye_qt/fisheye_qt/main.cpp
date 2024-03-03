#include "mainwindow.h"

#include <QApplication>

int main(int argc, char *argv[])
{
    // 高DPIモニタだとなぜか表示が更新されない。Qt6のバグか？
    // 暫定措置として、スケーリングを無効化する。
#ifdef Q_OS_WINDOWS
    qputenv("QT_ENABLE_HIGHDPI_SCALING", "0");
#endif

    // このAPIはQt6では廃止
    // QApplication::setAttribute(Qt::AA_DisableHighDpiScaling);

    QApplication a(argc, argv);
    MainWindow w;
    w.show();
    return a.exec();
}

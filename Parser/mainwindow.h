#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QVector>
#include <QString>

struct FieldInfo {
    QString name;
    QString type;
    int offset;
    int size;
};

QT_BEGIN_NAMESPACE
class QLineEdit;
class QSpinBox;
class QPushButton;
class QTextEdit;
class QUdpSocket;
class QTabWidget;
QT_END_NAMESPACE

class MainWindow : public QMainWindow
{
    Q_OBJECT
public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void browseFile();
    void start();
    void stop();
    void readPendingDatagrams();

private:
    struct ParseResult {
        QVector<FieldInfo> fields;
        QString structNameUsed;
        QString diagnostic;
    };

    // UI элементы
    QLineEdit *filePathEdit;
    QLineEdit *structNameEdit;
    QSpinBox *portSpin;
    QPushButton *startBtn;
    QTextEdit *outputEdit;
    QTextEdit *xmlEdit;
    QUdpSocket *socket;
    QVector<FieldInfo> currentFields;

    // Парсер
    ParseResult parseXML_Stream(const QString& xmlContent, const QString& structName);
};

#endif // MAINWINDOW_H

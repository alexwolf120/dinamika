#include "mainwindow.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QPushButton>
#include <QLineEdit>
#include <QSpinBox>
#include <QTextEdit>
#include <QFileDialog>
#include <QProcess>
#include <QFile>
#include <QDir>
#include <QCoreApplication>
#include <QStatusBar>
#include <QTabWidget>
#include <QXmlStreamReader>
#include <QUdpSocket>
#include <QByteArray>
#include <cstring>
#include <QDebug>
#include <QMap>
#include <functional>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent), socket(nullptr)
{
    setWindowTitle("Parser - CastXML");
    QWidget *central = new QWidget(this);
    setCentralWidget(central);
    QVBoxLayout *mainLayout = new QVBoxLayout(central);

    // Строка выбора файла
    QHBoxLayout *fileLayout = new QHBoxLayout();
    fileLayout->addWidget(new QLabel("Header file:"));
    filePathEdit = new QLineEdit();
    filePathEdit->setPlaceholderText("C:/dinamika/project/structData.h");
    fileLayout->addWidget(filePathEdit);
    QPushButton *browseBtn = new QPushButton("Browse...");
    connect(browseBtn, &QPushButton::clicked, this, &MainWindow::browseFile);
    fileLayout->addWidget(browseBtn);
    mainLayout->addLayout(fileLayout);

    // Имя структуры
    QHBoxLayout *structLayout = new QHBoxLayout();
    structLayout->addWidget(new QLabel("Struct name (optional):"));
    structNameEdit = new QLineEdit();
    structNameEdit->setPlaceholderText("Leave empty to use first non-system struct");
    structLayout->addWidget(structNameEdit);
    mainLayout->addLayout(structLayout);

    // Порт
    QHBoxLayout *portLayout = new QHBoxLayout();
    portLayout->addWidget(new QLabel("UDP port:"));
    portSpin = new QSpinBox();
    portSpin->setRange(1024, 65535);
    portSpin->setValue(12345);
    portLayout->addWidget(portSpin);
    mainLayout->addLayout(portLayout);

    // Кнопка
    startBtn = new QPushButton("Start Listening");
    connect(startBtn, &QPushButton::clicked, this, &MainWindow::start);
    mainLayout->addWidget(startBtn);

    // Вкладки
    QTabWidget *tabWidget = new QTabWidget(this);
    outputEdit = new QTextEdit();
    outputEdit->setReadOnly(true);
    tabWidget->addTab(outputEdit, "Log");

    xmlEdit = new QTextEdit();
    xmlEdit->setReadOnly(true);
    xmlEdit->setFontFamily("Courier New");
    tabWidget->addTab(xmlEdit, "XML");

    mainLayout->addWidget(tabWidget);

    statusBar()->showMessage("Ready");
}

MainWindow::~MainWindow() {}

void MainWindow::browseFile()
{
    QString fileName = QFileDialog::getOpenFileName(this, "Select header file", QString(), "Header files (*.h *.hpp);;All files (*)");
    if (!fileName.isEmpty())
        filePathEdit->setText(fileName);
}

void MainWindow::start()
{
    startBtn->setEnabled(false);
    outputEdit->clear();
    xmlEdit->clear();
    statusBar()->showMessage("Generating XML...");

    QString headerFile = filePathEdit->text();
    QString structName = structNameEdit->text().trimmed();
    int port = portSpin->value();
    QString xmlFile = "structData.xml";

    // --- Абсолютные и относительные пути ---
    QString appDir = QCoreApplication::applicationDirPath();
    QString baseDir = QDir::cleanPath(appDir + "/..");          // E:/qtdin
    QString castxmlPath = baseDir + "/CastXML-Builder/bin/bin/castxml.exe";
    QString includeRoot = baseDir + "/mingw_include";           // E:/qtdin/mingw_include (не в сборке!)
    QString resourceDir = baseDir + "/CastXML-Builder/share/castxml"; // без "bin"

    // --- Проверка файлов ---
    if (!QFile::exists(castxmlPath)) {
        outputEdit->append("ERROR: castxml.exe not found at " + castxmlPath);
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    if (!QDir(includeRoot).exists()) {
        outputEdit->append("ERROR: mingw_include folder not found at " + includeRoot);
        outputEdit->append("Please copy the MinGW include folder to " + includeRoot);
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    // Проверяем наличие cstdint (ищем в подпапках c++/версия/)
    bool foundCstdint = false;
    QDir cppDir(includeRoot + "/c++");
    if (cppDir.exists()) {
        QStringList subdirs = cppDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString& sub : subdirs) {
            if (QFile::exists(includeRoot + "/c++/" + sub + "/cstdint")) {
                foundCstdint = true;
                break;
            }
        }
    }
    if (!foundCstdint) {
        outputEdit->append("ERROR: cstdint not found in mingw_include.");
        outputEdit->append("Expected path like: " + includeRoot + "/c++/16.1.0/cstdint");
        outputEdit->append("Make sure you copied the ENTIRE 'include' folder from MinGW.");
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    } else {
        outputEdit->append("Found cstdint in mingw_include.");
    }

    // --- Аргументы CastXML ---
    QStringList args;
    args << "--castxml-gccxml"
         << "-x" << "c++"
         << "-std=c++11"
         << "-I" << includeRoot
         << "-isystem" << includeRoot
         << headerFile
         << "-o" << xmlFile;

    //outputEdit->append("Launching CastXML: " + castxmlPath + " " + args.join(" "));

//    // --- Запуск процесса с очищенным окружением ---
    QProcess proc;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();

//    // ПЕРЕОПРЕДЕЛЯЕМ переменные MSVC в пустую строку (важнее, чем удаление)
//    env.insert("INCLUDE", "");
//    env.insert("LIB", "");
//    env.insert("LIBPATH", "");

//    // Удаляем остальные переменные, связанные с Visual Studio
//    env.remove("VCINSTALLDIR");
//    env.remove("VCToolsInstallDir");
//    env.remove("VSINSTALLDIR");
//    env.remove("WindowsSdkDir");
//    env.remove("UCRTVersion");

//    if (QDir(resourceDir).exists()) {
//        env.insert("CLANG_RESOURCE_DIR", resourceDir);
//    }

    proc.setProcessEnvironment(env);
    proc.start(castxmlPath, args);

    if (!proc.waitForFinished(30000)) {
        outputEdit->append("Error: CastXML timeout or process failed to start");
        if (proc.error() != QProcess::UnknownError) {
            outputEdit->append("Process error: " + proc.errorString());
        }
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    if (proc.exitCode() != 0) {
        outputEdit->append("CastXML error code: " + QString::number(proc.exitCode()));
        QByteArray err = proc.readAllStandardError();
        if (!err.isEmpty()) {
            outputEdit->append("stderr: " + QString::fromLocal8Bit(err));
        }
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    if (!QFile::exists(xmlFile)) {
        outputEdit->append("XML file not generated");
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    outputEdit->append("XML generated successfully");

    // --- Чтение XML (без изменений) ---
    QFile xmlFileObj(xmlFile);
    if (!xmlFileObj.open(QIODevice::ReadOnly | QIODevice::Text)) {
        outputEdit->append("Cannot open XML file for reading");
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }
    QString xmlContent = QString::fromUtf8(xmlFileObj.readAll());
    xmlFileObj.close();
    xmlEdit->setPlainText(xmlContent);

    auto result = parseXML_Stream(xmlContent, structName);
    if (!result.diagnostic.isEmpty())
        outputEdit->append(result.diagnostic);

    if (result.fields.isEmpty()) {
        outputEdit->append("No fields found. Check that the structure exists and contains fields.");
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }

    // Пересчёт для packed layout
    int currentOffset = 0;
    for (auto &f : result.fields) {
        f.offset = currentOffset;
        currentOffset += f.size;
    }
    outputEdit->append("Using packed layout (no padding)");
    outputEdit->append(QString("Parsed %1 fields from structure '%2':")
                       .arg(result.fields.size())
                       .arg(result.structNameUsed));
    for (const auto &f : result.fields) {
        outputEdit->append(QString("  %1 (%2) offset=%3 size=%4 bytes")
                           .arg(f.name).arg(f.type).arg(f.offset).arg(f.size));
    }

    // --- UDP сокет (без изменений) ---
    if (socket) {
        socket->close();
        delete socket;
        socket = nullptr;
    }
    socket = new QUdpSocket(this);
    if (!socket->bind(QHostAddress::Any, port)) {
        outputEdit->append("Failed to bind port " + QString::number(port));
        statusBar()->showMessage("Failed");
        startBtn->setEnabled(true);
        return;
    }
    connect(socket, &QUdpSocket::readyRead, this, &MainWindow::readPendingDatagrams);
    currentFields = result.fields;
    statusBar()->showMessage(QString("Listening on port %1").arg(port));
    outputEdit->append("Listening on port " + QString::number(port) + "...");
    startBtn->setText("Stop Listening");
    disconnect(startBtn, &QPushButton::clicked, this, &MainWindow::start);
    connect(startBtn, &QPushButton::clicked, this, &MainWindow::stop);
    startBtn->setEnabled(true);
}

void MainWindow::stop()
{
    if (socket) {
        socket->close();
        delete socket;
        socket = nullptr;
    }
    startBtn->setText("Start Listening");
    disconnect(startBtn, &QPushButton::clicked, this, &MainWindow::stop);
    connect(startBtn, &QPushButton::clicked, this, &MainWindow::start);
    statusBar()->showMessage("Stopped");
    outputEdit->append("Stopped listening.");
    startBtn->setEnabled(true);
}

void MainWindow::readPendingDatagrams()
{
    if (!socket)
        return;
    while (socket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(socket->pendingDatagramSize());
        QHostAddress sender;
        quint16 senderPort;
        socket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);
        outputEdit->append(QString("Received packet from %1:%2 size=%3")
                           .arg(sender.toString())
                           .arg(senderPort)
                           .arg(datagram.size()));
        outputEdit->append("Raw hex: " + datagram.toHex());

        for (const auto &f : currentFields) {
            if (f.offset + f.size > datagram.size()) {
                outputEdit->append(QString("  Warning: field %1 out of range (offset=%2 size=%3)")
                                   .arg(f.name).arg(f.offset).arg(f.size));
                continue;
            }
            QByteArray raw = datagram.mid(f.offset, f.size);
            QString valueStr;
            if (f.type == "int" || f.type == "unsigned int" || f.type == "long" || f.type == "short") {
                int val;
                memcpy(&val, raw.data(), qMin(f.size, 4));
                valueStr = QString::number(val);
            } else if (f.type == "float") {
                float val;
                memcpy(&val, raw.data(), f.size);
                valueStr = QString::number(val);
            } else if (f.type == "double") {
                double val;
                memcpy(&val, raw.data(), f.size);
                valueStr = QString::number(val);
            } else if (f.type == "bool") {
                bool val = raw.at(0) != 0;
                valueStr = val ? "true" : "false";
            } else if (f.type.startsWith("char") || f.type.endsWith("[]")) {
                QString str = QString::fromLocal8Bit(raw).trimmed();
                if (str.endsWith('\0'))
                    str.chop(1);
                valueStr = str;
            } else {
                valueStr = raw.toHex();
            }
            outputEdit->append(QString("  %1 = %2").arg(f.name).arg(valueStr));
        }
    }
}

MainWindow::ParseResult MainWindow::parseXML_Stream(const QString& xmlContent, const QString& structName)
{
    ParseResult result;
    QXmlStreamReader xml(xmlContent);

    QMap<QString, QMap<QString, QString>> typeMap;
    QMap<QString, QString> fileMap;

    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.tokenType() == QXmlStreamReader::StartElement) {
            QString tag = xml.name().toString();
            if (tag == "FundamentalType" || tag == "ArrayType" || tag == "PointerType" || tag == "ReferenceType" || tag == "CvQualifiedType") {
                QString id = xml.attributes().value("id").toString();
                QMap<QString, QString> attrs;
                attrs["kind"] = tag;
                if (tag == "FundamentalType") {
                    attrs["name"] = xml.attributes().value("name").toString();
                    attrs["size"] = xml.attributes().value("size").toString();
                } else if (tag == "ArrayType") {
                    attrs["type"] = xml.attributes().value("type").toString();
                    attrs["min"] = xml.attributes().value("min").toString();
                    attrs["max"] = xml.attributes().value("max").toString();
                } else if (tag == "PointerType" || tag == "ReferenceType") {
                    attrs["type"] = xml.attributes().value("type").toString();
                    attrs["size"] = xml.attributes().value("size").toString();
                } else if (tag == "CvQualifiedType") {
                    attrs["type"] = xml.attributes().value("type").toString();
                }
                if (!id.isEmpty())
                    typeMap[id] = attrs;
            } else if (tag == "File") {
                QString id = xml.attributes().value("id").toString();
                QString name = xml.attributes().value("name").toString();
                if (!id.isEmpty())
                    fileMap[id] = name;
            }
        }
    }

    std::function<int(const QString&)> getTypeSize = [&](const QString& typeId) -> int {
        if (!typeMap.contains(typeId)) return 0;
        QMap<QString, QString> attrs = typeMap[typeId];
        QString kind = attrs["kind"];
        if (kind == "FundamentalType") {
            return attrs["size"].toInt() / 8;
        } else if (kind == "ArrayType") {
            QString elemTypeId = attrs["type"];
            int elemSize = getTypeSize(elemTypeId);
            int min = attrs["min"].toInt();
            int max = attrs["max"].toInt();
            int count = max - min + 1;
            return elemSize * count;
        } else if (kind == "PointerType" || kind == "ReferenceType") {
            return 8;
        } else if (kind == "CvQualifiedType") {
            return getTypeSize(attrs["type"]);
        }
        return 0;
    };

    QString headerFileName = QFileInfo(filePathEdit->text()).fileName();

    QString targetStructId;
    bool foundStruct = false;
    xml.clear();
    xml.addData(xmlContent);
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.tokenType() == QXmlStreamReader::StartElement && xml.name() == "Struct") {
            QString name = xml.attributes().value("name").toString();
            QString fileId = xml.attributes().value("file").toString();
            QString fileName = fileMap.value(fileId, "");
            if (name.startsWith("__") || name.contains("_tag"))
                continue;
            if (!structName.isEmpty()) {
                if (name != structName)
                    continue;
                targetStructId = xml.attributes().value("id").toString();
                foundStruct = true;
                result.structNameUsed = name;
                result.diagnostic = QString("Found structure '%1' (id=%2) from file '%3'\n")
                                    .arg(name).arg(targetStructId).arg(fileName);
                break;
            }
            if (fileName.isEmpty() || fileName.contains("builtin") || fileName.contains("msys64") || fileName.contains("mingw")) {
                continue;
            }
            if (!fileName.endsWith(headerFileName)) {
                continue;
            }
            targetStructId = xml.attributes().value("id").toString();
            foundStruct = true;
            result.structNameUsed = name;
            result.diagnostic = QString("Found structure '%1' (id=%2) from file '%3'\n")
                                .arg(name).arg(targetStructId).arg(fileName);
            break;
        }
    }

    if (!foundStruct) {
        result.diagnostic = "Structure not found in user-provided header file.";
        return result;
    }

    xml.clear();
    xml.addData(xmlContent);
    while (!xml.atEnd() && !xml.hasError()) {
        xml.readNext();
        if (xml.tokenType() == QXmlStreamReader::StartElement && xml.name() == "Field") {
            QString context = xml.attributes().value("context").toString();
            if (context == targetStructId) {
                FieldInfo f;
                f.name = xml.attributes().value("name").toString();
                QString typeId = xml.attributes().value("type").toString();
                int sizeInBytes = getTypeSize(typeId);
                f.size = sizeInBytes;
                if (typeMap.contains(typeId) && typeMap[typeId]["kind"] == "FundamentalType") {
                    f.type = typeMap[typeId]["name"];
                } else if (typeMap.contains(typeId) && typeMap[typeId]["kind"] == "ArrayType") {
                    QString elemTypeId = typeMap[typeId]["type"];
                    if (typeMap.contains(elemTypeId) && typeMap[elemTypeId]["kind"] == "FundamentalType") {
                        f.type = typeMap[elemTypeId]["name"] + "[]";
                    } else {
                        f.type = "array";
                    }
                } else {
                    f.type = typeId;
                }
                result.fields.append(f);
            }
        }
    }

    if (xml.hasError()) {
        result.diagnostic += "XML stream error: " + xml.errorString() + "\n";
    }

    result.diagnostic += QString("Total fields found: %1\n").arg(result.fields.size());
    return result;
}

cmake_minimum_required(VERSION 3.5)

project(Parser LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt5 COMPONENTS Widgets Network REQUIRED)

add_executable(Parser
    main.cpp
    mainwindow.cpp
    mainwindow.h
    resources.qrc
)

target_link_libraries(Parser Qt5::Widgets Qt5::Network)

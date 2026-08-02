@echo off
setlocal enabledelayedexpansion

echo ============================================================
echo CastXML Builder - Portable Build Script
echo ============================================================
echo.

:: Определяем корневую папку
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

:: Пути к инструментам и зависимостям
set "CMAKE_DIR=%ROOT%\tools\cmake-3.20\bin"
set "NINJA_DIR=%ROOT%\tools\ninja"
set "LLVM_DIR=%ROOT%\lib\llvm-12.0.1"
set "CASTXML_SRC=%ROOT%\CastXML"
set "BUILD_DIR=%ROOT%\CastXML-build"
set "INSTALL_DIR=%ROOT%\bin"

echo [INFO] Root:     %ROOT%
echo [INFO] CMake:    %CMAKE_DIR%\cmake.exe
echo [INFO] Ninja:    %NINJA_DIR%\ninja.exe
echo [INFO] LLVM:     %LLVM_DIR%
echo [INFO] Build:    %BUILD_DIR%
echo [INFO] Install:  %INSTALL_DIR%
echo.

:: Загружаем окружение VS 2017, если cl.exe не найден
:: В случае если не находится cl.exe то укажите свой путь
where cl >nul 2>nul
if errorlevel 1 (
    echo [WARN] cl.exe not found. Loading VS 2017 environment...
    call "C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\Tools\VsDevCmd.bat" -arch=x64
    if errorlevel 1 (
        echo [ERROR] Failed to load VS 2017.
        pause
        exit /b 1
    )
    echo [OK] VS 2017 loaded.
)

:: Проверка наличия CMake
if not exist "%CMAKE_DIR%\cmake.exe" (
    echo [ERROR] CMake not found.
    pause
    exit /b 1
)

:: Проверка наличия Ninja
if not exist "%NINJA_DIR%\ninja.exe" (
    echo [ERROR] Ninja not found.
    pause
    exit /b 1
)

:: Проверка наличия LLVM
if not exist "%LLVM_DIR%\lib\cmake\llvm\LLVMConfig.cmake" (
    echo [ERROR] LLVM not found.
    pause
    exit /b 1
)

:: Проверка наличия исходников CastXML, если нет - клонируем
if not exist "%CASTXML_SRC%\CMakeLists.txt" (
    echo [INFO] CastXML source not found. Cloning repository...
    where git >nul 2>nul
    if errorlevel 1 (
        echo [ERROR] Git not found in PATH. Please install Git or clone manually.
        pause
        exit /b 1
    )
    git clone https://github.com/CastXML/CastXML.git "%CASTXML_SRC%"
    if errorlevel 1 (
        echo [ERROR] Failed to clone CastXML repository.
        pause
        exit /b 1
    )
    echo [OK] CastXML source cloned successfully.
) else (
    echo [INFO] CastXML source already exists.
)

:: Удаляем старую папку сборки, чтобы гарантировать чистую сборку
if exist "%BUILD_DIR%" (
    echo [INFO] Removing old build directory...
    rmdir /s /q "%BUILD_DIR%"
)
mkdir "%BUILD_DIR%"
cd /d "%BUILD_DIR%"

:: Конфигурация CMake
echo [INFO] Configuring CMake...
"%CMAKE_DIR%\cmake.exe" -G "Ninja" -DCMAKE_BUILD_TYPE=Release -DClang_DIR="%LLVM_DIR%/lib/cmake/clang" -DLLVM_DIR="%LLVM_DIR%/lib/cmake/llvm" -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%" "%CASTXML_SRC%"

if errorlevel 1 (
    echo [ERROR] CMake configuration failed.
    pause
    exit /b 1
)

:: Сборка
echo [INFO] Building...
"%NINJA_DIR%\ninja.exe"
if errorlevel 1 (
    echo [ERROR] Build failed.
    pause
    exit /b 1
)

:: Установка (в папку bin попадает только castxml.exe)
echo [INFO] Installing...
"%NINJA_DIR%\ninja.exe" install
if errorlevel 1 (
    echo [ERROR] Install failed.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo [SUCCESS] Build completed! castxml.exe is in %INSTALL_DIR%
echo ============================================================
pause
endlocal
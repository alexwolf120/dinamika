#!/bin/bash
set -e

echo "============================================================"
echo "CastXML Builder - Linux (uses separate LLVM for Linux)"
echo "============================================================"
echo

# Проверка базовых утилит
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget not found. Install: sudo apt install wget"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar not found. Install: sudo apt install tar"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip not found. Install: sudo apt install unzip"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
TOOLS_DIR="$ROOT/tools"
CMAKE_DIR="$TOOLS_DIR/cmake-3.20"
NINJA_DIR="$TOOLS_DIR/ninja"
# Используем отдельную папку для Linux, чтобы не трогать Windows-версию
LLVM_DIR="$ROOT/lib/llvm-12.0.1-linux"
CASTXML_SRC="$ROOT/CastXML"
BUILD_DIR="$ROOT/CastXML-Linux-build"
INSTALL_DIR="$ROOT/bin-linux"

# Скачивание CMake
if [ ! -f "$CMAKE_DIR/bin/cmake" ]; then
    echo "[INFO] Downloading CMake 3.20..."
    mkdir -p "$TOOLS_DIR"
    cd "$TOOLS_DIR"
    wget -c https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz
    tar -xzf cmake-3.20.0-linux-x86_64.tar.gz
    mv cmake-3.20.0-linux-x86_64 cmake-3.20
    cd "$ROOT"
fi

# Скачивание Ninja
if [ ! -f "$NINJA_DIR/ninja" ]; then
    echo "[INFO] Downloading Ninja..."
    mkdir -p "$NINJA_DIR"
    cd "$NINJA_DIR"
    wget -c https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
    unzip -o ninja-linux.zip
    chmod +x ninja
    cd "$ROOT"
fi

# Скачивание LLVM 12.0.1 для Linux (в отдельную папку)
if [ ! -d "$LLVM_DIR" ] || [ ! -f "$LLVM_DIR/lib/cmake/llvm/LLVMConfig.cmake" ]; then
    echo "[INFO] Downloading LLVM 12.0.1 for Linux (into separate folder)..."
    mkdir -p "$ROOT/lib"
    cd "$ROOT/lib"
    # Скачиваем архив
    wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    tar -xf clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    # Находим извлечённую папку (начинается с clang+llvm-)
    EXTRACTED_DIR=$(ls -d clang+llvm-* 2>/dev/null | head -n1)
    if [ -n "$EXTRACTED_DIR" ]; then
        echo "[INFO] Found extracted folder: $EXTRACTED_DIR, renaming to llvm-12.0.1-linux"
        mv "$EXTRACTED_DIR" llvm-12.0.1-linux
    else
        echo "ERROR: Could not find extracted LLVM folder"
        exit 1
    fi
    cd "$ROOT"
fi

# Проверка наличия clang в Linux-папке
if [ ! -f "$LLVM_DIR/bin/clang++" ]; then
    echo "ERROR: clang++ not found in $LLVM_DIR/bin"
    echo "Please check the folder structure."
    exit 1
fi

# Скачивание CastXML как архива (без git)
if [ ! -d "$CASTXML_SRC" ] || [ ! -f "$CASTXML_SRC/CMakeLists.txt" ]; then
    echo "[INFO] Downloading CastXML source..."
    cd "$ROOT"
    wget -c https://github.com/CastXML/CastXML/archive/refs/heads/master.tar.gz -O CastXML-master.tar.gz
    tar -xzf CastXML-master.tar.gz
    mv CastXML-master CastXML
fi

# Очистка старой сборки
if [ -d "$BUILD_DIR" ]; then
    echo "[INFO] Removing old build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Конфигурация CMake с использованием Clang из Linux-LLVM
echo "[INFO] Configuring CMake with Clang..."
"$CMAKE_DIR/bin/cmake" -G "Ninja" \
    -DCMAKE_C_COMPILER="$LLVM_DIR/bin/clang" \
    -DCMAKE_CXX_COMPILER="$LLVM_DIR/bin/clang++" \
    -DCMAKE_BUILD_TYPE=Release \
    -DClang_DIR="$LLVM_DIR/lib/cmake/clang" \
    -DLLVM_DIR="$LLVM_DIR/lib/cmake/llvm" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -O2 -s" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
    "$CASTXML_SRC"

# Сборка и установка
echo "[INFO] Building..."
"$NINJA_DIR/ninja"
echo "[INFO] Installing..."
"$NINJA_DIR/ninja" install

echo
echo "============================================================"
echo "[SUCCESS] Build completed! castxml is in $INSTALL_DIR/bin"
echo "============================================================"

#!/bin/bash
set -e

echo "============================================================"
echo "CastXML Builder - Linux (fully portable, no system deps)"
echo "============================================================"
echo

# 1. Проверка базовых утилит
command -v git >/dev/null 2>&1 || { echo "ERROR: git not found. Install it: sudo apt install git"; exit 1; }
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget not found. Install it: sudo apt install wget"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar not found. Install it: sudo apt install tar"; exit 1; }
command -v g++ >/dev/null 2>&1 || { echo "ERROR: g++ not found. Install it: sudo apt install g++"; exit 1; }

# 2. Определение папок
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
TOOLS_DIR="$ROOT/tools"
CMAKE_DIR="$TOOLS_DIR/cmake-3.20"
NINJA_DIR="$TOOLS_DIR/ninja"
LLVM_DIR="$ROOT/lib/llvm-12.0.1"
BUILD_DIR="$ROOT/CastXML-Linux-build"
INSTALL_DIR="$ROOT/bin-linux"

# 3. Скачивание и распаковка CMake (если нет)
if [ ! -f "$CMAKE_DIR/bin/cmake" ]; then
    echo "[INFO] Downloading CMake 3.20..."
    mkdir -p "$TOOLS_DIR"
    cd "$TOOLS_DIR"
    wget -c https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz
    tar -xzf cmake-3.20.0-linux-x86_64.tar.gz
    mv cmake-3.20.0-linux-x86_64 cmake-3.20
    cd "$ROOT"
fi

# 4. Скачивание Ninja (если нет)
if [ ! -f "$NINJA_DIR/ninja" ]; then
    echo "[INFO] Downloading Ninja..."
    mkdir -p "$NINJA_DIR"
    cd "$NINJA_DIR"
    wget -c https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
    unzip -o ninja-linux.zip
    chmod +x ninja
    cd "$ROOT"
fi

# 5. Скачивание LLVM 12.0.1 для Linux (если нет)
if [ ! -d "$LLVM_DIR" ] || [ ! -f "$LLVM_DIR/lib/cmake/llvm/LLVMConfig.cmake" ]; then
    echo "[INFO] Downloading LLVM 12.0.1 for Linux..."
    mkdir -p "$ROOT/lib"
    cd "$ROOT/lib"
    wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    tar -xf clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    mv clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04 llvm-12.0.1
    cd "$ROOT"
fi

# 6. Проверка наличия исходников CastXML (подмодуль или клонирование)
if [ ! -d "$ROOT/CastXML" ] || [ ! -f "$ROOT/CastXML/CMakeLists.txt" ]; then
    echo "[INFO] Cloning CastXML source..."
    git clone https://github.com/CastXML/CastXML.git "$ROOT/CastXML"
fi

# 7. Очистка старой сборки
if [ -d "$BUILD_DIR" ]; then
    echo "[INFO] Removing old build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 8. Конфигурация CMake с использованием скачанных инструментов и внешнего LLVM
echo "[INFO] Configuring CMake..."
"$CMAKE_DIR/bin/cmake" -G "Ninja" \
    -DCMAKE_CXX_COMPILER=g++ \
    -DCMAKE_C_COMPILER=gcc \
    -DCMAKE_BUILD_TYPE=Release \
    -DClang_DIR="$LLVM_DIR/lib/cmake/clang" \
    -DLLVM_DIR="$LLVM_DIR/lib/cmake/llvm" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -O2 -s" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
    "$ROOT/CastXML"

# 9. Сборка и установка
echo "[INFO] Building..."
"$NINJA_DIR/ninja"
echo "[INFO] Installing..."
"$NINJA_DIR/ninja" install

echo
echo "============================================================"
echo "[SUCCESS] Build completed! castxml is in $INSTALL_DIR/bin"
echo "============================================================"

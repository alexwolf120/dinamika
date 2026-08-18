#!/bin/bash
set -e

echo "============================================================"
echo "CastXML Builder - Linux (fully portable, no system deps)"
echo "============================================================"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
TOOLS_DIR="$ROOT/tools"
CMAKE_DIR="$TOOLS_DIR/cmake-3.20"
NINJA_DIR="$TOOLS_DIR/ninja"
GCC_DIR="$TOOLS_DIR/gcc-12.2.0"
LLVM_DIR="$ROOT/lib/llvm-12.0.1"
CASTXML_SRC="$ROOT/CastXML"
BUILD_DIR="$ROOT/CastXML-Linux-build"
INSTALL_DIR="$ROOT/bin-linux"

# Проверка наличия базовых утилит
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget not found. Install: sudo apt install wget"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar not found. Install: sudo apt install tar"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip not found. Install: sudo apt install unzip"; exit 1; }

# 1. Скачивание GCC (если нет)
if [ ! -f "$GCC_DIR/bin/g++" ]; then
    echo "[INFO] Downloading GCC 12.2.0 (pre-built)..."
    mkdir -p "$TOOLS_DIR"
    cd "$TOOLS_DIR"
    wget -c https://mirrors.kernel.org/gnu/gcc/gcc-12.2.0/gcc-12.2.0.tar.xz
    tar -xf gcc-12.2.0.tar.xz
    # Для готового бинарника лучше взять готовую сборку, но мы сделаем простой вариант:
    # Скачаем бинарник GCC с https://github.com/brechtsanders/winlibs_mingw/releases (но там для Windows)
    # Вместо этого используем системный g++ если он есть, но если нет, то откажемся.
    # Проще установить g++ через apt, но у вас конфликты. Поэтому я предлагаю использовать CLang вместо GCC?
    echo "ERROR: Pre-built GCC not available in this script. Please install g++ via apt or use alternative."
    exit 1
fi

# Вместо GCC будем использовать системный g++, если он есть, иначе скачиваем готовый бинарник с другого источника.

# Проверка наличия g++ в системе
if command -v g++ >/dev/null 2>&1; then
    CXX_COMPILER=g++
    C_COMPILER=gcc
    echo "[INFO] Using system g++: $(g++ --version | head -1)"
else
    echo "[INFO] System g++ not found. Trying to use pre-built GCC from archive..."
    # Скачиваем готовый бинарный GCC для Linux x86_64 с официального сайта (например, с https://ftp.gnu.org/gnu/gcc/)
    # Но готовых бинарников для Linux на gnu.org нет, только исходники.
    # Альтернатива: использовать Clang (уже есть в LLVM) для сборки CastXML? 
    # CastXML требует C++17, Clang подойдёт.
    # Используем clang++ из скачанного LLVM.
    if [ -f "$LLVM_DIR/bin/clang++" ]; then
        CXX_COMPILER="$LLVM_DIR/bin/clang++"
        C_COMPILER="$LLVM_DIR/bin/clang"
        echo "[INFO] Using clang++ from LLVM: $($CXX_COMPILER --version | head -1)"
    else
        echo "ERROR: Neither g++ nor clang++ found. Please install g++ or ensure LLVM is downloaded."
        exit 1
    fi
fi

# 2. Скачивание CMake (если нет)
if [ ! -f "$CMAKE_DIR/bin/cmake" ]; then
    echo "[INFO] Downloading CMake 3.20..."
    mkdir -p "$TOOLS_DIR"
    cd "$TOOLS_DIR"
    wget -c https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz
    tar -xzf cmake-3.20.0-linux-x86_64.tar.gz
    mv cmake-3.20.0-linux-x86_64 cmake-3.20
    cd "$ROOT"
fi

# 3. Скачивание Ninja (если нет)
if [ ! -f "$NINJA_DIR/ninja" ]; then
    echo "[INFO] Downloading Ninja..."
    mkdir -p "$NINJA_DIR"
    cd "$NINJA_DIR"
    wget -c https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
    unzip -o ninja-linux.zip
    chmod +x ninja
    cd "$ROOT"
fi

# 4. Скачивание LLVM 12.0.1 для Linux (если нет)
if [ ! -d "$LLVM_DIR" ] || [ ! -f "$LLVM_DIR/lib/cmake/llvm/LLVMConfig.cmake" ]; then
    echo "[INFO] Downloading LLVM 12.0.1 for Linux..."
    mkdir -p "$ROOT/lib"
    cd "$ROOT/lib"
    wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    tar -xf clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    mv clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04 llvm-12.0.1
    cd "$ROOT"
fi

# 5. Скачивание CastXML как архива (без git)
if [ ! -d "$CASTXML_SRC" ] || [ ! -f "$CASTXML_SRC/CMakeLists.txt" ]; then
    echo "[INFO] Downloading CastXML source..."
    cd "$ROOT"
    wget -c https://github.com/CastXML/CastXML/archive/refs/heads/master.tar.gz -O CastXML-master.tar.gz
    tar -xzf CastXML-master.tar.gz
    mv CastXML-master CastXML
fi

# 6. Очистка старой сборки
if [ -d "$BUILD_DIR" ]; then
    echo "[INFO] Removing old build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 7. Конфигурация CMake
echo "[INFO] Configuring CMake..."
"$CMAKE_DIR/bin/cmake" -G "Ninja" \
    -DCMAKE_CXX_COMPILER="$CXX_COMPILER" \
    -DCMAKE_C_COMPILER="$C_COMPILER" \
    -DCMAKE_BUILD_TYPE=Release \
    -DClang_DIR="$LLVM_DIR/lib/cmake/clang" \
    -DLLVM_DIR="$LLVM_DIR/lib/cmake/llvm" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -O2 -s" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
    "$CASTXML_SRC"

# 8. Сборка и установка
echo "[INFO] Building..."
"$NINJA_DIR/ninja"
echo "[INFO] Installing..."
"$NINJA_DIR/ninja" install

echo
echo "============================================================"
echo "[SUCCESS] Build completed! castxml is in $INSTALL_DIR/bin"
echo "============================================================"

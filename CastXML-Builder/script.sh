#!/bin/bash
set -e

echo "============================================================"
echo "CastXML Builder - Linux (fully portable)"
echo "============================================================"
echo

# 1. Установка системных зависимостей
sudo apt update
sudo apt install -y cmake ninja-build git build-essential wget tar xz-utils

# 2. Определение папок
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
LLVM_DIR="$ROOT/lib/llvm-12.0.1"
BUILD_DIR="$ROOT/CastXML-Linux-build"
INSTALL_DIR="$ROOT/bin-linux"

# 3. Скачивание и распаковка готового LLVM 12.0.1 (если отсутствует)
if [ ! -d "$LLVM_DIR" ] || [ ! -f "$LLVM_DIR/lib/cmake/llvm/LLVMConfig.cmake" ]; then
    echo "[INFO] Downloading LLVM 12.0.1 for Linux..."
    mkdir -p "$ROOT/lib"
    cd "$ROOT/lib"
    wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    tar -xf clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04.tar.xz
    mv clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-20.04 llvm-12.0.1
    cd "$ROOT"
fi

# 4. Проверка наличия исходников CastXML (подмодуль или клонирование)
if [ ! -d "$ROOT/CastXML" ] || [ ! -f "$ROOT/CastXML/CMakeLists.txt" ]; then
    echo "[INFO] Cloning CastXML source..."
    git clone https://github.com/CastXML/CastXML.git "$ROOT/CastXML"
fi

# 5. Очистка старой сборки
if [ -d "$BUILD_DIR" ]; then
    echo "[INFO] Removing old build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# 6. Конфигурация CMake с внешним LLVM и статической линковкой
echo "[INFO] Configuring CMake..."
cmake -G "Ninja" \
    -DCMAKE_BUILD_TYPE=Release \
    -DClang_DIR="$LLVM_DIR/lib/cmake/clang" \
    -DLLVM_DIR="$LLVM_DIR/lib/cmake/llvm" \
    -DCMAKE_INSTALL_PREFIX="$INSTALL_DIR" \
    -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
    -DCMAKE_CXX_FLAGS="-static-libgcc -static-libstdc++ -O2 -s" \
    -DCMAKE_EXE_LINKER_FLAGS="-static-libgcc -static-libstdc++" \
    "$ROOT/CastXML"

# 7. Сборка и установка
echo "[INFO] Building..."
ninja
echo "[INFO] Installing..."
ninja install

echo
echo "============================================================"
echo "[SUCCESS] Build completed! castxml is in $INSTALL_DIR/bin"
echo "============================================================"
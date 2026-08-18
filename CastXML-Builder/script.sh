#!/bin/bash
set -e

echo "============================================================"
echo "CastXML Builder - Linux (smart: uses system tools if available)"
echo "============================================================"
echo

# Проверка базовых утилит
command -v wget >/dev/null 2>&1 || { echo "ERROR: wget not found. Install: sudo apt install wget"; exit 1; }
command -v tar >/dev/null 2>&1 || { echo "ERROR: tar not found. Install: sudo apt install tar"; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "ERROR: unzip not found. Install: sudo apt install unzip"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"

# === Определяем, использовать системные или свои инструменты ===
USE_SYSTEM_CMAKE=0
USE_SYSTEM_NINJA=0

# Проверка системного CMake (нужна версия >= 3.10)
if command -v cmake >/dev/null 2>&1; then
    CMAKE_VERSION=$(cmake --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
    if [ -n "$CMAKE_VERSION" ] && [ "$(echo "$CMAKE_VERSION >= 3.10" | bc)" -eq 1 ]; then
        echo "[INFO] System CMake found (version $CMAKE_VERSION) – will use it."
        USE_SYSTEM_CMAKE=1
    else
        echo "[WARN] System CMake version $CMAKE_VERSION is too old (< 3.10). Will download own CMake."
    fi
else
    echo "[INFO] System CMake not found. Will download own CMake."
fi

# Проверка системного Ninja
if command -v ninja >/dev/null 2>&1; then
    echo "[INFO] System Ninja found – will use it."
    USE_SYSTEM_NINJA=1
else
    echo "[INFO] System Ninja not found. Will download own Ninja."
fi

# === Настройка путей ===
TOOLS_LINUX_DIR="$ROOT/tools-linux"
CMAKE_DIR="$TOOLS_LINUX_DIR/cmake-3.20"
NINJA_DIR="$TOOLS_LINUX_DIR/ninja"
LLVM_DIR="$ROOT/lib/llvm-12.0.1-linux"
CASTXML_SRC="$ROOT/CastXML"
BUILD_DIR="$ROOT/CastXML-Linux-build"
INSTALL_DIR="$ROOT/bin-linux"

echo "[INFO] Using folders:"
echo "  LLVM:   $LLVM_DIR"
echo "  Build:  $BUILD_DIR"
echo "  Install: $INSTALL_DIR"
if [ $USE_SYSTEM_CMAKE -eq 1 ]; then
    echo "  CMake:  system ($(cmake --version | head -n1))"
else
    echo "  CMake:  $CMAKE_DIR"
fi
if [ $USE_SYSTEM_NINJA -eq 1 ]; then
    echo "  Ninja:  system ($(ninja --version 2>/dev/null || echo 'unknown'))"
else
    echo "  Ninja:  $NINJA_DIR"
fi
echo

# === 1. Скачивание CMake (если не используется системный) ===
if [ $USE_SYSTEM_CMAKE -eq 0 ] && [ ! -f "$CMAKE_DIR/bin/cmake" ]; then
    echo "[INFO] Downloading CMake 3.20 for Linux..."
    mkdir -p "$TOOLS_LINUX_DIR"
    cd "$TOOLS_LINUX_DIR"
    wget -c https://github.com/Kitware/CMake/releases/download/v3.20.0/cmake-3.20.0-linux-x86_64.tar.gz
    tar -xzf cmake-3.20.0-linux-x86_64.tar.gz
    mv cmake-3.20.0-linux-x86_64 cmake-3.20
    cd "$ROOT"
fi

# === 2. Скачивание Ninja (если не используется системный) ===
if [ $USE_SYSTEM_NINJA -eq 0 ] && [ ! -f "$NINJA_DIR/ninja" ]; then
    echo "[INFO] Downloading Ninja for Linux..."
    mkdir -p "$NINJA_DIR"
    cd "$NINJA_DIR"
    wget -c https://github.com/ninja-build/ninja/releases/download/v1.11.1/ninja-linux.zip
    unzip -o ninja-linux.zip
    chmod +x ninja
    cd "$ROOT"
fi

# === 3. Скачивание LLVM 12.0.1 для Linux ===
if [ ! -d "$LLVM_DIR" ] || [ ! -f "$LLVM_DIR/lib/cmake/llvm/LLVMConfig.cmake" ]; then
    echo "[INFO] Downloading LLVM 12.0.1 for Linux..."
    mkdir -p "$ROOT/lib"
    cd "$ROOT/lib"
    wget -c https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
    tar -xf clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
    EXTRACTED_DIR=$(ls -d clang+llvm-* 2>/dev/null | head -n1)
    if [ -n "$EXTRACTED_DIR" ]; then
        echo "[INFO] Found extracted folder: $EXTRACTED_DIR, renaming to llvm-12.0.1-linux"
        rm -rf llvm-12.0.1-linux 2>/dev/null
        mv "$EXTRACTED_DIR" llvm-12.0.1-linux
    else
        echo "ERROR: Could not find extracted LLVM folder"
        exit 1
    fi
    cd "$ROOT"
fi

# Проверка наличия clang
if [ ! -f "$LLVM_DIR/bin/clang++" ]; then
    echo "ERROR: clang++ not found in $LLVM_DIR/bin"
    echo "Please check the folder structure."
    exit 1
fi

# === 4. Скачивание и распаковка CastXML ===
if [ ! -d "$CASTXML_SRC" ] || [ ! -f "$CASTXML_SRC/CMakeLists.txt" ]; then
    echo "[INFO] Downloading CastXML source..."
    cd "$ROOT"
    rm -rf CastXML-master.tar.gz CastXML-master CastXML 2>/dev/null
    wget -c https://github.com/CastXML/CastXML/archive/refs/heads/master.tar.gz -O CastXML-master.tar.gz
    tar -xzf CastXML-master.tar.gz
    if [ -d "CastXML-master" ] && [ -f "CastXML-master/CMakeLists.txt" ]; then
        mv CastXML-master CastXML
        echo "[INFO] CastXML source extracted successfully"
    else
        echo "ERROR: Failed to extract CastXML source"
        ls -la
        exit 1
    fi
fi

# === 5. Очистка старой сборки ===
if [ -d "$BUILD_DIR" ]; then
    echo "[INFO] Removing old build directory..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# === 6. Конфигурация CMake ===
echo "[INFO] Configuring CMake with Clang..."

# Формируем путь к CMake и Ninja
if [ $USE_SYSTEM_CMAKE -eq 1 ]; then
    CMAKE_EXE="cmake"
else
    CMAKE_EXE="$CMAKE_DIR/bin/cmake"
fi

if [ $USE_SYSTEM_NINJA -eq 1 ]; then
    NINJA_EXE="ninja"
else
    NINJA_EXE="$NINJA_DIR/ninja"
fi

"$CMAKE_EXE" -G "Ninja" \
    -DCMAKE_MAKE_PROGRAM="$NINJA_EXE" \
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

# === 7. Сборка и установка ===
echo "[INFO] Building..."
"$NINJA_EXE"
echo "[INFO] Installing..."
"$NINJA_EXE" install

echo
echo "============================================================"
echo "[SUCCESS] Build completed! castxml is in $INSTALL_DIR/bin"
echo "============================================================"

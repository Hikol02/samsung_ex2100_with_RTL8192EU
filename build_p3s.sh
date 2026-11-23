#!/bin/bash
set -e

cd "$(dirname "$0")"

MODEL="p3s"
CORES=$(nproc)
CLANG_DIR="$PWD/toolchain/clang-r596125"
export PATH="$CLANG_DIR/bin:$PATH"

# 1. Проверка прошивки для TP-Link AC600 (MT7610U)
if [ ! -f "firmware/mediatek/mt7610u.bin" ]; then
    echo "[!] Файл firmware/mediatek/mt7610u.bin не найден!"
    echo "    Скопируйте его из /lib/firmware/mediatek/mt7610u.bin"
    exit 1
fi

# 2. Загрузка AOSP Clang, если отсутствует
if [ ! -f "$CLANG_DIR/bin/clang" ]; then
    echo "[*] Скачиваем AOSP Clang..."
    rm -rf "$CLANG_DIR"
    mkdir -p "$CLANG_DIR"
    pushd "$CLANG_DIR" > /dev/null
    curl -LJOk https://googlesource.com
    tar xf mirror-goog-main-llvm-toolchain-source/clang-r596125.tar.gz
    rm -f mirror-goog-main-llvm-toolchain-source-clang-r596125.tar.gz
    popd > /dev/null
fi

MAKE_ARGS="LLVM=1 LLVM_IAS=1 ARCH=arm64 O=out"

echo "[*] Генерируем конфиг для $MODEL (KSU + SuSFS + Wi-Fi)..."
make ${MAKE_ARGS} -j$CORES exynos2100_defconfig ${MODEL}.config ksu.config susfs.config

# Обновляем LOCALVERSION
BASE_LV=$(grep -E '^CONFIG_LOCALVERSION=' out/.config | cut -d'"' -f2)
./scripts/config --file out/.config --set-str LOCALVERSION "${BASE_LV}-v6.6-KSUN-SUSFS"

echo "[*] Запускаем компиляцию ядра ($CORES потоков)..."
make ${MAKE_ARGS} -j$CORES

echo "[*] Упаковываем образы в build/out/$MODEL..."
rm -rf "build/out/$MODEL"
mkdir -p "build/out/$MODEL/boot_ramdisk00"

cp -a out/arch/arm64/boot/Image "build/out/$MODEL/"
cp -a build/ramdisk/boot/boot_ramdisk00 "build/out/$MODEL/"

pushd "build/out/$MODEL/boot_ramdisk00" > /dev/null
find . ! -name . | LC_ALL=C sort | cpio -o -H newc -R root:root | lz4 -l > ../boot_ramdisk
popd > /dev/null

python3 toolchain/mkbootimg/mkbootimg.py \
    --header_version 3 \
    --cmdline "androidboot.selinux=permissive loop.max_part=7" \
    --ramdisk "build/out/$MODEL/boot_ramdisk" \
    --os_version 16.0.0 \
    --os_patch_level 2025-11 \
    --kernel "build/out/$MODEL/Image" \
    --output "build/out/$MODEL/boot.img"

./toolchain/mkdtimg cfg_create "build/out/$MODEL/dtb.img" build/dtconfigs/exynos2100.cfg -d out/arch/arm64/boot/dts/exynos
./toolchain/mkdtimg cfg_create "build/out/$MODEL/dtbo.img" "build/dtconfigs/$MODEL.cfg" -d "out/arch/arm64/boot/dts/samsung/$MODEL"

echo "==============================================="
echo "Готово! Образы сохранены в build/out/$MODEL/"
echo "==============================================="

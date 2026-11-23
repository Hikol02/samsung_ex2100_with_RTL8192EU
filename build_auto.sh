#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "=== 1. Сброс KernelSU-Next в чистое состояние ==="
git -C KernelSU-Next reset --hard HEAD
git -C KernelSU-Next clean -fd

echo "=== 2. Проверка и копирование прошивки MT7610U ==="
mkdir -p firmware/mediatek
if [ ! -f "firmware/mediatek/mt7610u.bin" ]; then
    if [ -f "/lib/firmware/mediatek/mt7610u.bin" ]; then
        cp /lib/firmware/mediatek/mt7610u.bin firmware/mediatek/
    elif [ -f "/lib/firmware/mediatek/mt7610u.bin.zst" ]; then
        zstd -d /lib/firmware/mediatek/mt7610u.bin.zst -o firmware/mediatek/mt7610u.bin
    elif [ -f "/lib/firmware/mediatek/mt7610u.bin.xz" ]; then
        xz -dc /lib/firmware/mediatek/mt7610u.bin.xz > firmware/mediatek/mt7610u.bin
    else
        echo "[!] ВНИМАНИЕ: mt7610u.bin не найден в /lib/firmware/mediatek/."
        echo "    Сборка продолжится, но прошивку нужно будет положить на телефон вручную."
    fi
fi

echo "=== 3. Очистка и настройка arch/arm64/configs/p3s.config ==="
sed -i '/^CONFIG_CONFIG_/d' arch/arm64/configs/p3s.config

# Проверяем, добавлен ли уже блок MT7610U, если нет — добавляем
if ! grep -q "CONFIG_MT76x0U=y" arch/arm64/configs/p3s.config; then
    cat << 'CFG' >> arch/arm64/configs/p3s.config

# Wi-Fi drivers (MT7610U + RTL8192EU) & Firmware
CONFIG_WLAN=y
CONFIG_WLAN_VENDOR_MEDIATEK=y
CONFIG_CFG80211=y
CONFIG_MAC80211=y
CONFIG_MT76_CORE=y
CONFIG_MT76_USB=y
CONFIG_MT76x02_LIB=y
CONFIG_MT76x02_USB=y
CONFIG_MT76x0_COMMON=y
CONFIG_MT76x0U=y
CONFIG_RTL8192EU=y
CONFIG_EXTRA_FIRMWARE="mediatek/mt7610u.bin"
CONFIG_EXTRA_FIRMWARE_DIR="firmware"
CFG
fi

echo "=== 4. Автоматическое наложение патчей на KernelSU-Next ==="
if [ -f "patches/ksu-reboot.patch" ]; then
    patch -N -d KernelSU-Next -p1 < patches/ksu-reboot.patch || true
fi

if [ -f "patches/enable-susfs.patch" ]; then
    # Пробуем применить с увеличенным допуском контекста (fuzz=3)
    patch -N --fuzz=3 -d KernelSU-Next -p1 < patches/enable-susfs.patch || true

    # Если остался файл отказа selinux.c.rej — разрешаем конфликт автоматически
    if [ -f "KernelSU-Next/kernel/selinux/selinux.c.rej" ]; then
        echo "[*] Обнаружен сдвиг в selinux.c, применяем умное слияние..."
        python3 - << 'PY'
import re

with open("KernelSU-Next/kernel/selinux/selinux.c.rej", "r") as f:
    rej = f.read()

with open("KernelSU-Next/kernel/selinux/selinux.c", "r") as f:
    src = f.read()

# Вытаскиваем добавляемые (+) строки и строки контекста из .rej
added_lines = []
context_before = []
found_plus = False

for line in rej.splitlines():
    if line.startswith("@@") or line.startswith("---") or line.startswith("+++"):
        continue
    if line.startswith("+"):
        added_lines.append(line[1:])
        found_plus = True
    elif line.startswith(" "):
        if not found_plus:
            context_before.append(line[1:])

if added_lines:
    patch_block = "\n".join(added_lines) + "\n"
    # Ищем якорную строку контекста прямо перед вставкой
    inserted = False
    for ctx in reversed(context_before):
        ctx_clean = ctx.strip()
        if ctx_clean and ctx_clean in src:
            # Вставляем сразу после первой найденной совпавшей строки в нижней половине файла
            pos = src.rfind(ctx)
            if pos != -1:
                eol = src.find("\n", pos) + 1
                src = src[:eol] + patch_block + src[eol:]
                inserted = True
                print("[+] Успешно вставлен блок SuSFS в selinux.c после:", ctx_clean)
                break
    if not inserted:
        print("[!] Не удалось найти точный якорь в selinux.c, проверьте вручную.")
    with open("KernelSU-Next/kernel/selinux/selinux.c", "w") as f:
        f.write(src)
PY
        rm -f KernelSU-Next/kernel/selinux/selinux.c.rej
    fi
fi

echo "=== 5. Запуск оригинальной сборки build.sh (p3s + KSU + SuSFS) ==="
chmod +x build.sh
./build.sh -m p3s -k y -s y

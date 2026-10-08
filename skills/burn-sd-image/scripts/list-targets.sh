#!/usr/bin/env bash
# list-targets.sh — 列出所有磁盘，标注系统盘(⛔)与可烧录候选(✅)
# 只读脚本，不修改任何设备。用法: ./list-targets.sh
set -euo pipefail

SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SELF_DIR/lib.sh"
MP_FIELD=$(mp_field)

echo "== 全部磁盘 =="
lsblk -o NAME,SIZE,TYPE,TRAN,RM,HOTPLUG,FSTYPE,LABEL,"$MP_FIELD",MODEL
echo
echo "== 逐盘判定 =="

candidates=0
for sysdir in /sys/block/*; do
    name=$(basename "$sysdir")
    case "$name" in
        loop*|zram*|ram*|mtdblock*|dm-*|sr*|nbd*) continue ;;
    esac
    dev="/dev/$name"
    [ -b "$dev" ] || continue

    size=$(lsblk -ndo SIZE "$dev" | xargs)
    model=$(lsblk -ndo MODEL "$dev" 2>/dev/null | xargs || true)
    tran=$(lsblk -ndo TRAN "$dev" 2>/dev/null | xargs || true)
    rmflag=$(lsblk -ndo RM "$dev" 2>/dev/null | xargs || true)

    is_sys=0
    while IFS= read -r mp; do
        [ -z "$mp" ] && continue
        case "$mp" in
            /|/boot|/boot/efi|/config|/usr|/var|/home) is_sys=1 ;;
        esac
    done < <(lsblk -nlo "$MP_FIELD" "$dev" 2>/dev/null || true)

    byid=""
    for l in /dev/disk/by-id/*; do
        [ -e "$l" ] || continue
        if [ "$(readlink -f "$l")" = "$dev" ]; then byid=$l; break; fi
    done

    if [ "$is_sys" = 1 ]; then
        printf '⛔ %s  %-8s %-6s %s  —— 系统盘，禁止烧录\n' \
            "$dev" "$size" "${tran:-?}" "${model:-未知型号}"
    elif [ "$rmflag" = 1 ] || [ "$tran" = usb ] || [ "$tran" = mmc ]; then
        candidates=$((candidates + 1))
        printf '✅ %s  %-8s %-6s %s  —— 可烧录候选（务必核对容量/型号）\n' \
            "$dev" "$size" "${tran:-?}" "${model:-未知型号}"
        if [ -n "$byid" ]; then echo "     稳定路径: $byid"; fi
    else
        printf '⚠️  %s  %-8s %-6s %s  —— 非可移动，默认拒绝（需 --i-know-risks）\n' \
            "$dev" "$size" "${tran:-?}" "${model:-未知型号}"
    fi
done
echo

if [ "$candidates" = 0 ]; then
    echo "没有发现可烧录设备。读卡器插好了吗？枚举异常先看 references/troubleshooting.md（优先换 USB 口/换线）。"
fi

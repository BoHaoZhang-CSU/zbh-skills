#!/usr/bin/env bash
# verify.sh — 校验设备内容与镜像是否一致（可只单独验镜像本身）
# 退出码: 0 一致/通过 | 1 参数或镜像问题 | 4 校验不一致
set -euo pipefail
export LC_ALL=C
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SELF_DIR/lib.sh"

usage() {
    cat <<'EOF'
用法: sudo scripts/verify.sh <镜像> [整盘设备] [--sha256] [--size 字节数]
  不带设备: 只校验镜像本身（解压 CRC + 大小 + 哈希），不需要 root
  带设备:   把设备前 N 字节读回，与镜像哈希比对
  --size 字节数   给无法自动得知解压后大小的格式用（如 .bz2）
退出码: 0 一致/通过 | 1 参数或镜像问题 | 4 校验不一致
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
esac

IMG=""; DEV=""; HASH=md5sum; SIZE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --sha256) HASH=sha256sum ;;
        --size)
            shift
            SIZE=${1:-}
            if [ -z "$SIZE" ]; then echo "⛔ --size 需要一个字节数" >&2; exit 1; fi
            ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "未知选项: $1" >&2; exit 1 ;;
        *)
            if [ -z "$IMG" ]; then IMG=$1
            elif [ -z "$DEV" ]; then DEV=$1
            else usage; exit 1
            fi
            ;;
    esac
    shift
done
if [ -z "$IMG" ]; then usage; exit 1; fi
if [ ! -f "$IMG" ]; then echo "⛔ 镜像不存在: $IMG" >&2; exit 1; fi
decomp_for "$IMG" || exit 1
zip_single_entry_check "$IMG" || exit 1

echo "计算镜像哈希（同时验证压缩包完整性）……"
EXPECT=$("${DECOMP[@]}" "$IMG" | "$HASH" | awk '{print $1}') || {
    echo "⛔ 镜像解压失败（文件损坏？）" >&2; exit 1
}
SIZE_DETECTED=$(image_size "$IMG")
if [ -z "$SIZE" ]; then SIZE=$SIZE_DETECTED; fi
echo "  镜像: $IMG"
if [ -n "$SIZE" ]; then
    echo "  解压后大小: $SIZE 字节"
else
    echo "  解压后大小: 未知（校验设备时请加 --size <字节数>）"
fi
echo "  $HASH: $EXPECT"

if [ -z "$DEV" ]; then
    echo "✅ 镜像本身校验通过（未校验设备）"
    exit 0
fi

# ---- 校验设备（需要 root）----
# sudo 时间戳凭据绑定在"发起命令的父进程"上，脚本内 sudo 不可靠；
# 优先直接用 sudo 跑本脚本。若当前是交互终端，也允许用 sudo 前缀逐条提权。
if [ "$(id -u)" -eq 0 ]; then
    run_root() { "$@"; }
elif [ -t 0 ] || [ -t 1 ] || [ -t 2 ]; then
    run_root() { sudo "$@"; }
else
    echo "校验设备需要 root 权限。请用以下方式运行：" >&2
    echo "  sudo $0 <镜像> <设备> ..." >&2
    echo "  # agent: echo <密码> | sudo -S -v && sudo $0 <镜像> <设备> ..." >&2
    exit 1
fi

if [ -L "$DEV" ]; then DEV=$(readlink -f "$DEV"); fi
if [ ! -b "$DEV" ]; then echo "⛔ 不是块设备: $DEV" >&2; exit 1; fi
DEVNAME=${DEV#/dev/}
if [ ! -e "/sys/block/$DEVNAME" ]; then
    echo "⛔ 请传整盘设备（如 /dev/sde），不是分区" >&2; exit 1
fi
if [ -z "$SIZE" ]; then
    echo "⛔ 无法得知该镜像解压后大小，请用 --size <字节数> 指定" >&2; exit 1
fi
DEV_BYTES=$(run_root blockdev --getsize64 "$DEV")
if [ "$SIZE" -gt "$DEV_BYTES" ]; then
    echo "⛔ 镜像大小 $SIZE 字节 > 设备容量 $DEV_BYTES 字节" >&2; exit 1
fi

echo "读回设备前 $SIZE 字节并比对……"
ACTUAL=$(run_root head -c "$SIZE" "$DEV" | "$HASH" | awk '{print $1}') || {
    echo "⛔ 读回失败（介质/读卡器问题）" >&2; exit 4
}
if [ "$ACTUAL" = "$EXPECT" ]; then
    echo "✅ 一致（$HASH: $EXPECT）"
    exit 0
else
    echo "⛔ 不一致！" >&2
    echo "   期望: $EXPECT" >&2
    echo "   实际: $ACTUAL" >&2
    exit 4
fi

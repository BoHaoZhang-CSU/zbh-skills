#!/usr/bin/env bash
# burn.sh — 把整盘镜像写入 SD 卡/读卡器设备（Linux）
# 流程: 安全检查 → 烧前校验镜像(算参考哈希) → dd 写入 → 读回比对
# 退出码: 0 成功 | 1 参数/镜像问题 | 2 安全检查不过 | 3 写入失败 | 4 校验不一致
set -euo pipefail
export LC_ALL=C
SELF_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck disable=SC1091
source "$SELF_DIR/lib.sh"

usage() {
    cat <<'EOF'
用法: sudo scripts/burn.sh <镜像文件> <整盘设备> [选项]
  --dry-run        只做安全检查，不写入任何数据
  --no-verify      跳过烧前镜像校验与烧后读回比对（最快，不推荐）
  --sha256         用 sha256 代替 md5 做校验
  --yes            跳过交互确认（agent 已在对话中与用户确认时用）
  --i-know-risks   允许写入非可移动设备（默认拒绝）
支持镜像: .img(裸) .xz .gz .bz2 .zst .zip
退出码: 0 成功 | 1 参数/镜像问题 | 2 安全检查不过 | 3 写入失败 | 4 校验不一致
EOF
}

case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    "")        usage; exit 1 ;;
esac

# 需要 root。
# 注意：sudo 的时间戳凭据绑定在"发起命令的父进程"上，脚本内部再调 sudo 不可靠，
# 所以推荐用法是直接用 sudo 运行本脚本：
#   人类:  sudo scripts/burn.sh <镜像> <设备> ...
#   agent: echo <密码> | sudo -S -v && sudo scripts/burn.sh <镜像> <设备> ... --yes
if [ "$(id -u)" -ne 0 ]; then
    if [ -t 0 ] || [ -t 1 ] || [ -t 2 ]; then
        exec sudo -- "$0" "$@"   # 交互终端：自动提权，正常询问密码
    fi
    echo "需要 root 权限。请用以下方式运行：" >&2
    echo "  sudo $0 <镜像> <设备> [选项]" >&2
    echo "  # agent: echo <密码> | sudo -S -v && sudo $0 <镜像> <设备> --yes" >&2
    exit 2
fi

IMG=""; DEV=""; DRY=0; VERIFY=1; HASH=md5sum; YES=0; IKR=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)      DRY=1 ;;
        --no-verify)    VERIFY=0 ;;
        --sha256)       HASH=sha256sum ;;
        --yes)          YES=1 ;;
        --i-know-risks) IKR=1 ;;
        -h|--help)      usage; exit 0 ;;
        -*)             echo "未知选项: $1" >&2; usage; exit 1 ;;
        *)
            if [ -z "$IMG" ]; then
                IMG=$1
            elif [ -z "$DEV" ]; then
                DEV=$1
            else
                echo "多余参数: $1" >&2; usage; exit 1
            fi
            ;;
    esac
    shift
done
if [ -z "$IMG" ] || [ -z "$DEV" ]; then
    usage; exit 1
fi

echo "[1/4] 检查镜像与目标设备……"
if [ ! -f "$IMG" ]; then echo "⛔ 镜像文件不存在: $IMG" >&2; exit 1; fi
if [ ! -s "$IMG" ]; then echo "⛔ 镜像文件为空: $IMG" >&2; exit 1; fi
decomp_for "$IMG" || exit 1
zip_single_entry_check "$IMG" || exit 1

# ---- 目标设备解析与安全检查 ----
if [ -L "$DEV" ]; then DEV=$(readlink -f "$DEV"); fi
case "$DEV" in /dev/*) ;; *) echo "⛔ 设备路径必须以 /dev/ 开头: $DEV" >&2; exit 1 ;; esac
if [ ! -b "$DEV" ]; then echo "⛔ 不是块设备: $DEV" >&2; exit 1; fi
DEVNAME=${DEV#/dev/}
if [ ! -e "/sys/block/$DEVNAME" ]; then
    echo "⛔ $DEV 是分区，不是整盘。请写整盘设备（如 /dev/sde、/dev/mmcblk0），不要带分区号。" >&2
    exit 1
fi

MP_FIELD=$(mp_field)
sys_mp=""; other_mp=""
while IFS= read -r mp; do
    [ -z "$mp" ] && continue
    case "$mp" in
        /|/boot|/boot/efi|/config|/usr|/var|/home) sys_mp=$mp ;;
        *) other_mp=$mp ;;
    esac
done < <(lsblk -nlo "$MP_FIELD" "$DEV" 2>/dev/null || true)

if [ -n "$sys_mp" ]; then
    echo "⛔ $DEV 上有系统挂载点（$sys_mp）——这是本机系统盘，禁止烧录！" >&2
    exit 2
fi
if [ -n "$other_mp" ]; then
    echo "⛔ $DEV 有分区正在挂载（$other_mp），请先卸载再重试。" >&2
    exit 2
fi

TRAN=$(lsblk -ndo TRAN "$DEV" 2>/dev/null | xargs || true)
RMFLAG=$(lsblk -ndo RM "$DEV" 2>/dev/null | xargs || true)
if [ "$RMFLAG" != 1 ] && [ "$TRAN" != usb ] && [ "$TRAN" != mmc ] && [ "$IKR" != 1 ]; then
    echo "⛔ $DEV 不是可移动/USB 设备（TRAN=$TRAN RM=$RMFLAG），默认拒绝。" >&2
    echo "   确认这台设备确实可以清空，再加 --i-know-risks。" >&2
    exit 2
fi

DEV_BYTES=$(blockdev --getsize64 "$DEV")
SIZE=$(image_size "$IMG")
if [ -n "$SIZE" ] && [ "$SIZE" -gt "$DEV_BYTES" ]; then
    echo "⛔ 镜像解压后 $SIZE 字节 > 设备容量 $DEV_BYTES 字节，放不下。" >&2
    exit 2
fi
if [ -z "$SIZE" ]; then
    echo "⚠️ 该格式无法预读解压后大小，请自行确认镜像 ≤ $DEV_BYTES 字节"
fi

MODEL=$(lsblk -ndo MODEL "$DEV" 2>/dev/null | xargs || true)
DEV_HUMAN=$(numfmt --to=iec "$DEV_BYTES" 2>/dev/null || echo "$DEV_BYTES B")
PKG_HUMAN=$(du -h --apparent-size "$IMG" | cut -f1)
echo "  镜像: $IMG  (压缩包 $PKG_HUMAN${SIZE:+，解压后 $SIZE 字节})"
echo "  目标: $DEV  $DEV_HUMAN  ${MODEL:-未知型号}  (TRAN=${TRAN:-?} RM=${RMFLAG:-?})"

if [ "$DRY" = 1 ]; then
    echo "[dry-run] ✅ 安全检查全部通过，未写入任何数据。"
    exit 0
fi

if [ "$YES" != 1 ]; then
    ans=""
    if ! read -r -p "⚠️ $DEV 上所有数据将被清空！输入 yes 继续: " ans </dev/tty 2>/dev/null; then
        echo "⛔ 没有可交互终端。请在对话中确认后加 --yes 重跑。" >&2
        exit 1
    fi
    if [ "$ans" != yes ]; then
        echo "已取消。" >&2
        exit 1
    fi
fi

# ---- 烧前校验：解压同时验证压缩包完整性(xz/gz/zstd/bz2 自带 CRC 校验)，并得到参考哈希 ----
EXPECT=""
if [ "$VERIFY" = 1 ]; then
    echo "[2/4] 校验镜像完整性并计算参考哈希（大镜像需数分钟）……"
    EXPECT=$("${DECOMP[@]}" "$IMG" | "$HASH" | awk '{print $1}') || {
        echo "⛔ 镜像解压失败（文件损坏？）" >&2; exit 1
    }
    echo "      参考 $HASH: $EXPECT"
else
    echo "[2/4] (已跳过：--no-verify)"
fi

# ---- 写入 ----
echo "[3/4] 写入中……（大镜像需要数分钟到十几分钟，勿拔设备/勿断电）"
LOG=$(mktemp /tmp/burn-XXXXXX.log)
set +e
"${DECOMP[@]}" "$IMG" | dd of="$DEV" bs=4M conv=fsync status=progress 2>"$LOG"
pst=("${PIPESTATUS[@]}")
set -e
DRC=${pst[0]:-1}
WRC=${pst[1]:-1}
echo "--- 写入输出（末几行）---"
tr '\r' '\n' < "$LOG" | tail -n 3

if [ "$DRC" -ne 0 ]; then
    echo "⛔ 解压/读取镜像失败（rc=$DRC），写入已中断" >&2; rm -f "$LOG"; exit 3
fi
if [ "$WRC" -ne 0 ]; then
    echo "⛔ dd 写入失败（rc=$WRC）。建议重插读卡器/换 USB 口后重试" >&2; rm -f "$LOG"; exit 3
fi

WRITTEN=$(tr '\r' '\n' < "$LOG" | grep -oE '^[0-9]+ bytes' | tail -n 1 | awk '{print $1}' || true)
if [ -n "$SIZE" ] && [ -n "$WRITTEN" ] && [ "$WRITTEN" != "$SIZE" ]; then
    echo "⛔ 实际写入 $WRITTEN 字节 ≠ 镜像 $SIZE 字节" >&2; rm -f "$LOG"; exit 3
fi
if [ -n "$WRITTEN" ]; then echo "  已写入 $WRITTEN 字节"; fi
sync

# ---- 读回校验 ----
if [ "$VERIFY" = 1 ]; then
    RSIZE=${SIZE:-$WRITTEN}
    if [ -z "$RSIZE" ]; then
        echo "⛔ 无法确定写入字节数，跳过读回。请用 scripts/verify.sh 手动校验" >&2
        rm -f "$LOG"; exit 4
    fi
    echo "[4/4] 读回校验中（按设备读速，可能十几分钟）……"
    ACTUAL=$(head -c "$RSIZE" "$DEV" | "$HASH" | awk '{print $1}') || {
        echo "⛔ 读回失败（介质/读卡器问题）" >&2; rm -f "$LOG"; exit 4
    }
    if [ "$ACTUAL" != "$EXPECT" ]; then
        echo "⛔⛔ 读回校验不一致！" >&2
        echo "   期望: $EXPECT" >&2
        echo "   实际: $ACTUAL" >&2
        rm -f "$LOG"; exit 4
    fi
    echo "      ✅ 一致（$HASH: $EXPECT）"
else
    echo "[4/4] (已跳过：--no-verify)"
fi

# ---- 收尾 ----
rm -f "$LOG"
blockdev --rereadpt "$DEV" 2>/dev/null || true
echo
echo "== 新的分区表 =="
lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEV" || true
echo
echo "✅ 烧录完成。核对上面的分区符合预期后，可安全移除设备："
echo "   eject $DEV"
echo "   若提示不支持 eject，改用:  echo 1 > /sys/block/$DEVNAME/device/delete"
exit 0

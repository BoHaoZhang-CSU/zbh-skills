#!/usr/bin/env bash
# lib.sh — burn.sh / verify.sh / list-targets.sh 共用函数（被 source，勿直接执行）

# 探测 lsblk 的挂载点字段名（util-linux >= 2.37 用 MOUNTPOINTS，旧版用 MOUNTPOINT）
mp_field() {
    if lsblk -nlo MOUNTPOINTS >/dev/null 2>&1; then
        echo MOUNTPOINTS
    else
        echo MOUNTPOINT
    fi
}

# 根据镜像扩展名设置全局数组 DECOMP（解压命令），并检查工具是否存在。
# 未知扩展名按裸镜像处理，但先做压缩魔数兜底（防止没改名的压缩包被当裸镜像写入）。
decomp_for() {
    local img=$1 magic
    case "$img" in
        *.xz)         DECOMP=(xz -dc) ;;
        *.gz)         DECOMP=(gzip -dc) ;;
        *.bz2)        DECOMP=(bzip2 -dc) ;;
        *.zst|*.zstd) DECOMP=(zstd -dc) ;;
        *.zip)        DECOMP=(unzip -p) ;;
        *)
            magic=$(head -c 6 "$img" 2>/dev/null | od -An -tx1 | tr -d ' \n')
            case "${magic:-}" in
                fd377a585a00*) echo "⛔ $img 是 xz 压缩文件，请重命名为 .xz 后重试" >&2; return 1 ;;
                1f8b*)         echo "⛔ $img 看起来是 gzip 压缩文件，请重命名为 .gz 后重试" >&2; return 1 ;;
                425a68*)       echo "⛔ $img 看起来是 bzip2 压缩文件，请重命名为 .bz2 后重试" >&2; return 1 ;;
                28b52ffd*)     echo "⛔ $img 看起来是 zstd 压缩文件，请重命名为 .zst 后重试" >&2; return 1 ;;
                504b03*)       echo "⛔ $img 看起来是 zip 压缩文件，请重命名为 .zip 后重试" >&2; return 1 ;;
                *)             DECOMP=(cat) ;;
            esac
            ;;
    esac
    if ! command -v "${DECOMP[0]}" >/dev/null 2>&1; then
        echo "⛔ 缺少工具 ${DECOMP[0]}，请先安装（xz-utils / gzip / bzip2 / zstd / unzip）" >&2
        return 1
    fi
}

# 回显镜像解压后的字节数；无法确定时回显空。
# 注意: gzip -l 对解压后 >4GiB 的文件会因 ISIZE 32 位回绕给出偏小的值，
#      该值仅用于容量预检，真实安全性由写入时 dd 报错 + 读回校验兜底。
image_size() {
    local img=$1 s=""
    case "$img" in
        *.xz)         s=$(xz -l --robot "$img" 2>/dev/null | awk -F'\t' '/^totals/{print $5}') ;;
        *.gz)         s=$(gzip -l "$img" 2>/dev/null | awk 'NR==2{print $2}') ;;
        *.zip)        s=$(unzip -l "$img" 2>/dev/null | awk '/^ *[0-9]+ +[0-9]+ file/{print $1; exit}') ;;
        *.zst|*.zstd) s=$(zstd -l "$img" 2>/dev/null | awk 'NR==2{print $3}') ;;
        *)            s=$(stat -c %s "$img" 2>/dev/null) ;;
    esac
    case "$s" in
        ''|*[!0-9]*) echo "" ;;
        *)           echo "$s" ;;
    esac
}

# zip 必须是单条目（unzip -p 会把所有条目串起来，必须拒绝多文件 zip）
zip_single_entry_check() {
    local img=$1 n
    [ "${DECOMP[0]:-}" = unzip ] || return 0
    n=$(unzip -Z -1 "$img" 2>/dev/null | grep -c . || true)
    if [ "$n" != 1 ]; then
        echo "⛔ zip 里有 $n 个文件，无法确定烧哪个（应为单个镜像文件）" >&2
        return 1
    fi
}

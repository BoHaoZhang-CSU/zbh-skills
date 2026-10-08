#!/usr/bin/env bash
# install.sh — 把本仓库 skills/* 安装到 ~/.claude/skills/
#
# 用法:
#   ./install.sh [技能名...] [--copy] [--dest DIR]
#     (无技能名 = 安装全部)
#   默认符号链接: 改仓库文件即时生效，git pull 即更新
#   --copy:       复制安装（快照式，不依赖仓库目录）
#
# 环境变量: CLAUDE_SKILLS_DIR 可覆盖目标目录（默认 ~/.claude/skills）
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MODE=link
NAMES=()

usage() {
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --copy) MODE=copy ;;
        --link) MODE=link ;;
        --dest) DEST=${2:?--dest 需要一个目录参数}; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "未知选项: $1" >&2; usage; exit 1 ;;
        *) NAMES+=("$1") ;;
    esac
    shift
done

if [ ${#NAMES[@]} -eq 0 ]; then
    for d in "$REPO"/skills/*/; do
        NAMES+=("$(basename "$d")")
    done
fi
if [ ${#NAMES[@]} -eq 0 ]; then
    echo "⛔ skills/ 下没有任何技能目录" >&2
    exit 1
fi

mkdir -p "$DEST"
for name in "${NAMES[@]}"; do
    src="$REPO/skills/$name"
    if [ ! -f "$src/SKILL.md" ]; then
        echo "⛔ 跳过 $name：$src 下没有 SKILL.md" >&2
        exit 1
    fi
    tgt="$DEST/$name"
    if [ -L "$tgt" ]; then
        if [ "$(readlink -f "$tgt")" = "$(readlink -f "$src")" ]; then
            echo "↺ $name 已链接到本仓库，跳过"
            continue
        fi
        echo "⛔ $tgt 已是别的链接，请先处理（rm 或改名）" >&2
        exit 1
    fi
    if [ -e "$tgt" ]; then
        echo "⛔ $tgt 已存在且不是符号链接，请先处理（rm 或改名）" >&2
        exit 1
    fi
    case "$MODE" in
        link) ln -s "$src" "$tgt" ;;
        copy) cp -a "$src" "$tgt" ;;
    esac
    chmod +x "$tgt"/scripts/*.sh 2>/dev/null || true
    echo "✅ 已安装 $name -> $tgt（$MODE）"
done

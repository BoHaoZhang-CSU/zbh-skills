# zbh-skills

个人 [Claude Code](https://claude.com/claude-code) 技能（skill）合集。
**每个技能 = `skills/` 下的一个独立目录**，可单独安装、单独演进，互不影响。

## 技能列表

| 技能 | 说明 |
| --- | --- |
| [burn-sd-image](skills/burn-sd-image/) | Linux 下把镜像（`.img/.xz/.gz/.bz2/.zst/.zip`）烧录到 SD 卡/内存卡/USB 读卡器。含防写错盘闸门（系统盘/挂载/容量检查）与写后读回校验 |

## 目录结构

```
zbh-skills/
├── skills/                    # 全部技能，目录名 = 技能名 = SKILL.md 里的 name
│   └── burn-sd-image/
│       ├── SKILL.md           # 技能本体（frontmatter 决定何时被触发）
│       ├── scripts/           # 可执行工具脚本
│       ├── references/        # 按需加载的详细资料
│       └── local-notes.md     # 本机适配笔记（.gitignore 忽略，不提交）
├── templates/
│   └── SKILL.template.md      # 新技能骨架，复制即用
├── install.sh                 # 一键安装技能到 ~/.claude/skills/
├── LICENSE
└── README.md
```

## 安装

```bash
git clone git@github.com:BoHaoZhang-CSU/zbh-skills.git ~/wp/zbh-skills
cd ~/wp/zbh-skills
./install.sh                     # 把 skills/* 全部符号链接到 ~/.claude/skills/
./install.sh burn-sd-image       # 只安装指定技能
./install.sh --copy              # 复制安装（不依赖仓库目录；git pull 不会自动更新）
```

默认用**符号链接**：改仓库里的文件 Claude Code 立即生效，`git pull` 即更新所有技能。
新开一个 Claude Code 会话后技能即被发现；也可用 `/burn-sd-image` 手动调用。

## 如何新增一个技能

1. 复制模板：`cp templates/SKILL.template.md skills/<新技能名>/SKILL.md`
2. 写 `SKILL.md`——frontmatter 的 **`name` 必须等于目录名**，`description` 写清触发场景（这是 Claude 决定调不调用它的唯一依据）
3. 需要脚本、参考资料就放同目录的 `scripts/`、`references/`（大段资料别堆进 SKILL.md）
4. `./install.sh <新技能名>` 装到本机，实测一轮
5. 提交：`git add -A && git commit -m "新增技能 xxx" && git push`

## 约定

- 一个技能一个目录；技能之间不共享文件（宁复制、勿耦合）
- 破坏性操作必须有安全闸门 + 人工确认，并在 SKILL.md 写明红线
- 机器相关的个人笔记一律叫 `local-notes.md`（已全局 gitignore），模板用 `local-notes.example.md`

## License

MIT

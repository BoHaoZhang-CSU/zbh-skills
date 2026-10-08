# burn-sd-image

**Linux 上把镜像烧录到 SD 卡的 Claude Code 技能（skill）**——给 agent 用的安全烧录工作流，
也可当作纯 shell 脚本工具单独使用。

将整盘镜像（`.img` / `.xz` / `.gz` / `.bz2` / `.zst` / `.zip`）写入 SD 卡/读卡器，
内置"防写错盘"闸门与写后读回校验。

## 特性

- **列设备**：`list-targets.sh` 标出系统盘（⛔ 禁烧）与可烧录候选（✅，附稳定 by-id 路径）
- **写入前闸门**：系统盘检测 / 挂载检测 / 可移动性检查 / 容量检查 / 交互确认——写错盘基本不可能
- **烧前校验**：解压镜像的同时验证压缩包 CRC 并计算参考哈希（文件坏了不会被写进卡）
- **写后读回**：把卡读回来比对 md5/sha256，不一致退出码 4；校验一致性有据可查
- **收尾**：重读分区表、安全移除提示（兼容不支持 eject 的读卡器）
- **本机适配层**：`local-notes.md` 记录你自己的环境怪癖（不提交 git）

## 安装

本技能在 [zbh-skills](https://github.com/BoHaoZhang-CSU/zbh-skills) 仓库的 `skills/burn-sd-image/` 下：

```bash
git clone git@github.com:BoHaoZhang-CSU/zbh-skills.git
cd zbh-skills && ./install.sh burn-sd-image   # 符号链接到 ~/.claude/skills/（git pull 即更新）
```

或手动安装：把本目录整个放到 `~/.claude/skills/burn-sd-image`，并 `chmod +x scripts/*.sh`。

新开一个 Claude Code 会话，直接说"**帮我烧卡**"/"把 xxx.img 烧到内存卡"，或输入 `/burn-sd-image`。

## 手动使用（不依赖 agent）

```bash
scripts/list-targets.sh                        # 看有哪些盘、谁是系统盘
sudo scripts/burn.sh  镜像.img.xz /dev/sde      # 交互确认 → 校验 → 写入 → 读回
sudo scripts/burn.sh  镜像.img.xz /dev/sde --dry-run   # 只做安全检查
sudo scripts/verify.sh 镜像.img.xz /dev/sde     # 单独复核某张卡
scripts/verify.sh     镜像.img.xz               # 只验镜像文件本身（免 root）
```

退出码：`0` 成功 ｜ `1` 参数/镜像问题 ｜ `2` 安全检查不过 ｜ `3` 写入失败 ｜ `4` 校验不一致

## 依赖

- 必需：bash、coreutils（dd/head/md5sum）、util-linux（lsblk/blockdev）
- 按镜像格式需要：`xz` / `gzip` / `bzip2` / `zstd` / `unzip`

## 本机适配（推荐做一次）

复制 `local-notes.example.md` 为 `local-notes.md`，填写你这台机器的：
sudo 方式、USB 端口怪癖（比如必须插某个 Hub）、内核日志读取方式、已知读卡器特性、速度参考。
该文件已被 `.gitignore` 忽略，agent 每次烧录前会先读它。

## 范围与边界

- ✅ Linux → SD 卡 / 读卡器（USB 或内置）/ U 盘 / USB 存储
- ❌ macOS / Windows；Android fastboot；RK maskrom / rkdeveloptool；SPI / 串口烧录

## 安全声明

烧录会**清空目标设备全部数据**。脚本内置多重拦截，但仍请人工核对设备容量与型号；
误写系统盘将造成不可恢复的数据丢失。使用本工具即表示你理解并接受该风险。

## License

MIT

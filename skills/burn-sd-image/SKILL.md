---
name: burn-sd-image
description: Linux 下把镜像烧录到 SD 卡/内存卡（USB 读卡器或内置读卡器）。当用户说"烧录/烧卡/写卡/刷机/把 xxx.img 烧到内存卡、SD 卡"、需要用 dd 写 img/xz/gz/bz2/zst/zip 镜像到 /dev/sdX 或 /dev/mmcblkX、需要写后读回校验时使用。含安全检查脚本、压缩格式对照、故障速查。Burn/flash a Linux image to an SD card from Linux.
---

# 烧录镜像到 SD 卡（Linux）

**范围**：Linux 机器上，把整盘镜像（.img / .xz / .gz / .bz2 / .zst / .zip）写入 SD 卡（USB 读卡器、内置读卡器均可）。
**不适用**：macOS/Windows；Android fastboot；RK maskrom/rkdeveloptool；SPI/串口烧录 —— 请换各自专用工具。

## 开始前：先读 local-notes.md

本技能目录下若存在 `local-notes.md`，**先读它**——里面记录本机环境适配（sudo 密码方式、USB 端口怪癖、已知设备特性等）。没有该文件就按下面通用流程走（模板见 `local-notes.example.md`）。

## 流程

### 1. 识别读卡器与目标设备
- 运行 `scripts/list-targets.sh`（只读）：列出全部磁盘，⛔=系统盘（禁烧），✅=可烧录候选（附稳定 by-id 路径）
- 没有任何候选设备：看内核日志（`sudo dmesg | tail -50`），枚举报错（如 `error -110` 超时）几乎都是**换 USB 口 / 换 Hub / 换线**就能解决，详见 `references/troubleshooting.md`

### 2. 与用户确认（破坏性操作，必做）
- 确认镜像文件：可以在下载目录找出来让用户选（`ls -lh ~/Downloads` 里的 `*.img* *.xz *.gz *.zst *.zip`），**别猜**
- 确认目标设备：容量和型号与用户手里那张卡对得上（读卡器丝印/卡面容量）
- 提醒：卡上数据将**全部清空**。想先看看卡里有没有用户数据，可只读挂载（不会写任何东西）：
  `sudo mkdir -p /mnt/peek && sudo mount -o ro,noload <设备>3 /mnt/peek && ls /mnt/peek/home/`
  看完 `sudo umount /mnt/peek`
- 用 AskUserQuestion 得到明确确认后再动手

### 3. 预检（只读，不写入）
```bash
sudo scripts/burn.sh <镜像> <设备> --dry-run
```

### 4. sudo 凭据（重要，容易踩）
sudo 的时间戳凭据绑定在"**发起命令的父进程**"上：**脚本内部再调 sudo 不可靠**，正确姿势是"直接以 sudo 运行脚本"：
- 人类（有终端）：直接 `sudo scripts/burn.sh ...`，会正常询问密码
- agent（无终端）：`echo <密码> | sudo -S -v && sudo scripts/burn.sh ... --yes`
- ⚠️ 任何 `sudo -S` 都**不要与数据管道共用 stdin**（sudo 会把管道开头的镜像数据当密码吃掉，写坏卡）
- 密码只从用户当次会话获取，不要写入任何文件

### 5. 正式烧录
```bash
sudo scripts/burn.sh <镜像> <整盘设备> --yes
```
- 默认：预检 → 烧前校验镜像（解压同时验证压缩包 CRC）+ 算参考哈希 → dd 写入 → **读回比对**
- `--no-verify` 跳过校验（最快，不推荐）；`--sha256` 用 sha256 代替 md5；`--i-know-risks` 允许写非可移动设备（一般不用）
- 速度参考（USB2 读卡器）：写约 17.5 MB/s，7GB 镜像写入 ≈10 分钟、读回 ≈9 分钟
- 单条命令超 10 分钟被工具自动转后台属正常：**等完成通知，不要重复启动第二次写入**

### 6. 收尾
- 脚本会重读分区表并打印新分区：核对分区数量、LABEL 符合预期
- 安全移除：`eject <设备>`；提示不支持时 `echo 1 | sudo tee /sys/block/<名字>/device/delete`
- 明确告诉用户"**可以拔卡了**"
- 需要单独复核时（比如怀疑写入有问题），随时可跑 `scripts/verify.sh <镜像> <设备>`

## 脚本退出码
`0` 成功 ｜ `1` 参数/镜像问题 ｜ `2` 安全检查不过 ｜ `3` 写入失败 ｜ `4` 校验不一致

## 安全红线（不可绕过）
- 脚本内置拦截（系统盘 / 挂载中 / 非可移动 / 容量 / 交互确认）是**闸门不是建议**，不要用变通手段绕开
- 设备不确定 → 停下来问用户，**永远不猜**
- 校验不一致 → 重烧；两次都不一致再查线 / 读卡器 / 卡（见 troubleshooting）
- 绝不写本机系统盘（脚本已拦，但自己心里必须有数）

## 参考
- `references/formats.md` —— 各压缩格式解压/取大小命令对照
- `references/troubleshooting.md` —— 枚举失败 / I/O 错误 / 校验不一致 / 假卡检测
- `local-notes.example.md` —— 本机适配模板（复制为 local-notes.md 后填写，已被 .gitignore 忽略）

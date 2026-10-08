# 故障速查

## 1. 读卡器插上没反应 / lsusb 里都看不到
- 看内核日志：`sudo dmesg | tail -50`（`dmesg_restrict=1` 的机器必须 sudo）
- 典型症状：`device descriptor read/all, error -110`（枚举超时，反复重试）
  → 排查顺序：**换 USB 口（优先有供电的 Hub 口） → 换线 → 换读卡器**
  → "直插板载口失败、插 Hub 就成功"很常见（供电/枚举兼容问题），不代表读卡器坏
- `lsusb` 能看到设备但没有 `/dev/sdX`：看 dmesg 里 usb-storage 的报错，同样先换口换线

## 2. dd 中途 I/O error / 设备掉线
- 读卡器供电不足或接触不良：换有源 Hub、重插紧、换线
- 杂牌大容量卡写入不稳定也会掉线
- 重烧一次；仍失败换卡对比测试

## 3. 读回校验不一致（脚本退出码 4）
- 先原样重烧一次
- 两次都不一致：换读卡器/线；再不行怀疑卡本身（扩容卡、坏块、翻新卡）
- 检测假卡/扩容卡（会写满整卡，耗时长）：`f3write` + `f3read`，或 h2testw
- 上板子能正常启动的话，也可能是偶发读错误，重烧后校验通过即可

## 4. 写完分区表没更新
- `sudo blockdev --rereadpt <设备>`；不行就重新插拔读卡器再看 `lsblk`

## 5. 拔卡前的安全移除
- 先确认没有分区处于挂载状态（`mount | grep <设备名>`）
- `sudo eject <设备>`；提示 `unable to eject`（读卡器不支持）时：
  `echo 1 | sudo tee /sys/block/<设备名>/device/delete`，成功后即可拔

## 6. 命令跑很久 / 被转后台
- 大镜像 + USB2 属正常（7GB ≈ 写入10分钟 + 读回9分钟）；**不要重复启动第二次写入**
- 想看进度：dd 的 `status=progress` 输出、或 `tail -f` 脚本日志

## 7. 提示"镜像放不下"
- 镜像解压后大于卡容量。注意厂商标称容量（1000 进制）与实际字节数（1024 进制）的差异
- 换更大卡或更小的镜像；`--no-verify` 不解决容量问题

## 8. 报"需要 root 权限"
- 用 sudo 直接运行脚本（不要指望脚本内部自己提权）：`sudo scripts/burn.sh ...`
- agent：`echo <密码> | sudo -S -v && sudo scripts/burn.sh ... --yes`
- 见 SKILL.md「sudo 凭据」一节

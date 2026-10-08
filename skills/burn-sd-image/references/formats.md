# 压缩格式对照（burn.sh / verify.sh 已自动处理，此表供手动排查与扩展）

| 扩展名 | 解压命令 | 解压后大小探测 | 备注 |
|---|---|---|---|
| `.img` `.bin` `.iso` 等 | `cat` | `stat -c %s` | 裸镜像，直接写 |
| `.xz` | `xz -dc` | `xz -l --robot`（totals 第 5 列） | 流自带 CRC64，解压过程即校验完整性 |
| `.gz` | `gzip -dc` | `gzip -l` 第 2 列 | ⚠️ 解压后 >4GiB 时 ISIZE 32 位回绕，大小仅供参考 |
| `.bz2` | `bzip2 -dc` | 无 | 读回校验时需 `verify.sh --size <字节数>` |
| `.zst` | `zstd -dc` | `zstd -l` 第 3 列 | 需安装 zstd |
| `.zip` | `unzip -p` | `unzip -l` 汇总行 | **必须单条目**；多文件会被脚本拒绝 |

依赖工具（按需）：`xz-utils` `gzip` `bzip2` `zstd` `unzip`

## 不支持的格式
`.7z` / `.lz4` / `.rar` 等：先手动解压成 `.img` 再烧：
```bash
7z x image.img.7z        # 或 lz4 -d image.img.lz4
scripts/burn.sh image.img /dev/sdX
```

## 手动写卡（不用脚本时）
```bash
xz -dc image.img.xz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```
写完务必读回比对（脚本默认会做，手动写卡别忘了）：
```bash
sudo head -c <解压后字节数> /dev/sdX | md5sum   # 与 xz -dc image.img.xz | md5sum 比对
```

## 速度参考
- USB 2.0 读卡器/集线器：15~20 MB/s（写）
- USB 3.0 读卡器 + 好卡：60~90 MB/s
- 写完后 dd 的 `conv=fsync` 刷盘可能额外多花几十秒到几分钟（卡内部缓存大时更久），属正常

# 本机环境适配（模板）

用法：把本文件复制为同目录下的 `local-notes.md` 并填写自己的内容。
`local-notes.md` 已被 `.gitignore` 忽略，不会提交到仓库；agent 每次烧录前会先读它。
没有内容可以删掉对应小节；全空也可以不建这个文件。

## sudo 方式
（例：本机 sudo 需密码，用户会在对话中提供。agent 用法：
`echo <密码> | sudo -S -v && sudo scripts/burn.sh <镜像> <设备> --yes`。
注意：sudo 凭据绑定"发起命令的父进程"，脚本内部再调 sudo 不可靠；
`sudo -S` 不能与数据管道共用 stdin。密码不要写入本文件。）

## USB 端口 / 供电怪癖
（例：板载 USB 口插读卡器枚举失败 -110，必须插到 XX Hub 的口上。）

## 内核日志读取方式
（例：dmesg_restrict=1，需 `echo <密码> | sudo -S dmesg`；journalctl -k 普通用户看不到。）

## 已知设备特性
（例：XX 读卡器不支持 eject，安全移除用 `echo 1 > /sys/block/<名字>/device/delete`。）

## 速度参考
（例：Hub 口写 ~17.5 MB/s；7GB 镜像写入+fsync 约 10 分钟，读回约 9 分钟。）

## 其他
（例：系统盘是 /dev/sda（UFS），另有若干 LUN 设备 sdb~sdd，绝不能碰。）

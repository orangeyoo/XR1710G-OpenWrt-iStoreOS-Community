# XR1710G Community First Release 公共发布清单

本清单对应 `iStoreOS-XR1710G-Community First Release`。它是面向 Econet/Gemtek XR1710G
的社区移植测试版，不是 iStoreOS 官方镜像。

## 发布文件

- `*-initramfs-recovery.itb`：临时 Recovery/内存系统。
- `*-squashfs-sysupgrade.itb`：确认 UBI 2.0 和 U-Boot/chainloader 后写入 NAND 的永久系统。
- `*.manifest`、`profiles.json`、`sha256sums`：软件包清单、设备 profile 和校验信息。
- `UBOOT-FLASH-GUIDE.md`：U-Boot 使用边界与刷机顺序；U-Boot 本体不包含在系统镜像内。

## 本次 First Release 验收

- 两台真机：Linux `6.18.38`，XR1710G UBI 2.0，MT7996/mt76 `b2704cf5`。
- 6 GHz 回程：US / 信道 37 / EHT320 / WPA3-SAE 802.11s，当前 Mesh `ESTAB`。
- 当前两端 `tx failed=0`；未发现 MT7996 firmware crash、MCU timeout、kernel panic、
  Call Trace、watchdog 重启、UBI/I/O 错误或 `airtime_link_metric_get`。
- 节点启动或无线重载时的短暂 SAE 失败、Mesh 重连、PPPoE PADO 超时和已知 TRNG/
  DSA/`-95` 启动提示已归类为非致命日志，不代表所有环境都不会出现 warning。

## 公开前检查

1. 发布前运行 `sha256sum -c sha256sums`。
2. 只发布本目录和公开源码，不发布 `backups/`、运行时配置、诊断原始日志或迁移档案。
3. 不把家庭网络的 SSID、PPPoE、root 密码、DDNSTO/OpenClash 配置写入 issue、截图或压缩包。
4. 刷机前确认设备型号为 XR1710G、U-Boot 支持 UBI 2.0，并保留 TTL/Recovery 救援路径。
5. 首次启动默认管理地址为 `192.168.50.1`；两台设备必须逐台配置，节点应改为不冲突的地址。

## 反馈格式

出现异常时只提交脱敏后的 `xr1710g-mesh-diag` 报告、版本号、监管域、频道/带宽、摆位和
吞吐结果。不要提交 `/etc/config` 原文件或包含密码/token 的完整 overlay 备份。

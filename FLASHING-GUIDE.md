# XR1710G v1.6.0 刷机指南 / Flashing Guide

## 中文

仅适用于 Gemtek XR1710G。v1.6.0 已通过两台设备刷后基础检查。升级前备份；如有多台，建议先升级节点，确认正常后再升级主路由。

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.0-sysupgrade.itb` | 唯一系统固件 |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 可选 U-Boot，仅在“更新 U-Boot / Update U-Boot”入口使用 |
| `SHA256SUMS.txt` | 系统与 U-Boot 校验，不刷入 |
| `FLASHING-GUIDE.md` | 本说明，不刷入 |

### 已有兼容 OpenWrt / iStoreOS

旧版后台可能在大配置备份时触发30秒超时。若确认后没有重启，不要重复提交；先检查升级进程/日志，安排维护窗口修补旧入口或经SSH受控升级。本次1.6包含新入口修复，但它不能在刷入前自动修复旧系统。已有兼容U-Boot无需为此更新。

备份需要的配置 → 系统 → 备份/升级 → 上传 sysupgrade ITB → 确认并等待重启。
同系列保留配置升级继续使用原地址和密码；跨发行版或排查旧配置问题时建议不保留配置。
不要把系统 ITB 上传至 Update U-Boot。

### Wiro U-Boot Recovery

1. 只连接目标设备，进入 Recovery；电脑设为自动获取 IP，打开 `http://192.168.255.1/`。
2. 选择 **系统固件双清 / System Firmware Double-Clean**，上传上述 sysupgrade ITB。
3. 双清会删除旧配置、overlay 和其中的 Docker 数据，必须提前备份。
4. 红灯通常闪烁约三分钟，必须等待 **页面 100%、绿灯常亮且系统可访问**。全程不要断电、复位或拔线。

### 旧版兼容 HTTP U-Boot

若旧版没有自动 DHCP，直连电脑手动设为 `192.168.255.2/24`，打开 `http://192.168.255.1/`。
选择 **Firmware → UBI 2.0 - 439 MiB**，上传同一个 sysupgrade ITB，等待写入和重启。
结束后将电脑恢复自动获取 IP。

### U-Boot 是否必须升级

**不需要为了系统升级到 1.6 而重刷已有兼容 U-Boot。**
本次下载区已附原样验证的 `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin`。需要更换时按 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 专页操作；上游署名、许可证和对应源码书面提供承诺保持不变。
只有对应的 flash-slot.bin 能进入 **更新 U-Boot / Update U-Boot**；系统 ITB 和裸 u-boot.bin 不能混刷。

### 初始账号与无线

- 管理地址：`192.168.50.1`
- 用户名：`root`
- 管理员初始密码：`password`（保留配置升级不覆盖原密码）
- 2.4/5GHz：无默认 Wi-Fi 密码，初始开放；应立即设置加密。
- 6GHz：无预设 SAE 密钥，802.11s 模板默认禁用。
- 5GHz 首次默认 EHT80。可手动选择 EHT160。DFS 检测期间暂时不广播，等待检测完成再判断是否失败。
- 交流群：1061612207。

两台新刷设备不要同时连入同一网络，以免初始地址与 DHCP 冲突。
不要复制另一台设备的 Factory、EEPROM、caldata 或 MAC。
首次界面是中文：**系统 → 系统 → 语言和界面 → English → 保存并应用**。

## English

For Gemtek XR1710G only. Use the **sysupgrade ITB** as the system firmware, **SHA256SUMS.txt** to verify integrity, and this guide for instructions. GitHub source archives are not flashable firmware.

### Compatible running system

Older pages may time out after 30 seconds while backing up a large configuration. If no reboot occurs, do not resubmit. Inspect the task/logs, then schedule a controlled entrypoint hotfix or SSH upgrade. This rebuilt v1.6 fixes future upgrades but cannot repair the running old entrypoint before installation. No U-Boot update is needed for this issue.

Back up settings, open **System → Backup / Flash Firmware**, upload `xr1710g-community-v1.6.0-sysupgrade.itb`, confirm, and wait for reboot. Preserved upgrades retain the existing address and password. Avoid preserving settings across distributions or when eliminating stale configuration issues.

### Wiro Recovery

Enter Recovery with only the target router connected. Set the computer to DHCP and open `http://192.168.255.1/`. Choose **System Firmware Double-Clean** and upload the same sysupgrade ITB. This erases configuration, overlay and Docker data stored there; back up first.

Wait for **100% in the page, a solid green LED and a reachable installed system**. The red LED typically blinks for about three minutes. Never remove power, reset or unplug during writing.

### Legacy compatible HTTP U-Boot

If DHCP is unavailable, temporarily set the computer to `192.168.255.2/24`, open `http://192.168.255.1/`, choose **Firmware → UBI 2.0 - 439 MiB**, and upload the same sysupgrade ITB. Restore computer DHCP after installation.

A compatible U-Boot does **not** need updating for firmware 1.6. The unchanged optional `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` is included in this release. See [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) for the U-Boot procedure, upstream credits, licenses and written corresponding-source offer. U-Boot retains its v1.0.0 version. Never upload a system ITB or raw u-boot.bin to **Update U-Boot**.

### First boot

Address `192.168.50.1`, user `root`, password `password`. Preserved upgrades keep existing credentials. Initial 2.4/5GHz networks are open; set encryption and change the administrator password immediately. The empty-key 6GHz 802.11s template is disabled. The factory 5GHz width remains EHT80; EHT160 is selectable and may require a foreground DFS/CAC wait before the AP becomes available.

Configure clean units individually to prevent duplicate addresses and DHCP servers. Do not copy another device's Factory, EEPROM, caldata or MAC.

The initial UI is Chinese. Open **System → System → Language and Style** (系统 → 系统 → 语言和界面), select **English**, and click **Save & Apply** (保存并应用).

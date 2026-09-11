# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.6.1

## 中文

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区固件。本版在 v1.6.0 基础上修复桥接节点内核日志刷屏、Apple 设备漫游兼容性、LuCI 无线配置误回退及 MLO 页面误操作风险。

### 本次更新

- **桥接节点日志刷屏修复**：空置端口（如节点的 WAN 口）不再每秒向内核日志输出 `USXGMII AN down` 诊断。v1.4–v1.6.0 中该打印以限速上限持续刷屏，约 8 分钟即把节点全部系统日志冲掉，严重影响排查。现改为链路状态跳变时打印一次，异常事件（`cdr-reset`）诊断与 RX-lock 恢复逻辑不变。实机验收：节点 WAN 空置 12 小时仅 1 条记录，日志完整覆盖整个开机周期。
- **FT-over-DS 漫游兼容修复**：出厂 5GHz 的 802.11r 此前仅允许 over-the-air 快速漫游（`ft_over_ds='0'`），Apple 设备惯用 FT-over-DS，导致每次跨 AP 漫游退回完整认证，弱信号下重连缓慢。现出厂及保留配置升级均迁移为 `ft_over_ds='1'`（两种漫游方式同时可用）；迁移只修改该开关，不触碰密钥、信道、SSID 等用户设置。实机验证两台设备升级后生效，漫游恢复正常。
- **LuCI 无线配置误回退修复**：应用 5GHz DFS 频宽（如 EHT160，需约 60 秒 CAC）时，LuCI 原厂的 90 秒确认窗口可能先到并自动回滚配置，表现为"160 改回 80"。现出厂将 `luci.apply.rollback` 提升为 300 秒；已有自定义值不覆盖。该修复不改变 v1.5 已修复的后台 CAC 启动故障本身。
- **MLO 页面防误操作**：MLO 编辑器不再显示 802.11s Mesh 回程接口，避免把 6GHz 回程误改为 AP/STA 导致组网损坏；存在 Mesh 接口时页面给出指引提示。
- **其余保持不变**：Linux 6.18.41、内核补丁链（除上述日志限流）、mt76 r7、IPv6 去重、后台升级修复、无线出厂默认（5GHz channel 36 / EHT80 / 29dBm）、Argon、iStore、Docker、Full Cone、PassWall2、OpenClash、风扇策略。

### 下载：只需关注这四个文件

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | 唯一系统固件：兼容系统升级或 U-Boot 的系统固件入口 |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 原样附带的可选 U-Boot，仅用于 **更新 U-Boot / Update U-Boot** |
| `SHA256SUMS.txt` | 两个二进制的完整性校验，不刷入 |
| `FLASHING-GUIDE.md` | 中英文刷机教程，不刷入 |

**已有兼容 U-Boot 不需要重刷。不要把系统 ITB 上传到 Update U-Boot。**

- 兼容系统：备份配置 → 系统 → 备份/升级 → 上传 sysupgrade ITB。同系列保留配置升级继续使用原地址和密码；升级后自动应用 FT-over-DS 与回滚窗口迁移。
- v1.6.0 用户：普通保留配置升级即可，无需 U-Boot 操作。
- Wiro Recovery：进入目标设备的 `http://192.168.255.1/`，选择"系统固件双清"，上传同一个 ITB。双清删除旧配置及 overlay 中的 Docker 等数据，务必先备份。红灯通常闪烁约三分钟，等待 **100%、绿灯常亮且系统可访问**，不要断电。
- 旧兼容 HTTP U-Boot：选择 **Firmware → UBI 2.0 - 439 MiB**，使用同一个 sysupgrade ITB。

### 初始账号与无线

- 管理地址：**192.168.50.1**；用户名：**root**；初始管理员密码：**password**。
- 2.4GHz / 5GHz Wi-Fi：**没有预设密码**；首次有线登录后立即设置加密。
- 6GHz Mesh：无预设 SAE 密钥，模板默认禁用。组网前设置两端一致的 Mesh ID、SAE 密钥、信道、带宽和监管设置。
- 出厂 5GHz 为 channel 36 / EHT80，6GHz 模板为 channel 37 / EHT160 / 802.11s；支持按实际环境选择 160/320MHz。5GHz 160MHz 启动需等待 DFS/CAC，不能将等待期误判为掉回 80MHz。
- 保留配置升级不覆盖原密码和无线设置。两台干净设备不要同时接入网络，以免地址/DHCP 冲突。

### 本版实机验证

两台 XR1710G 已刷入本次 1.6.1 并完成验收：迁移全部生效（`ft_over_ds='1'`、`luci.apply.rollback='300'`、MLO 过滤在位）；节点 WAN 空置 12 小时日志仅 1 条 PCS 记录、日志完整保留；三频配置无损保留，6GHz channel 37 / 320MHz / 802.11s Mesh 双端 ESTAB；S24、Mac 及 iPhone 正常接入与漫游，无驱动崩溃、MCU timeout 或存储错误。**日志刷屏与迁移修复为实机确认；不构成长期游戏、行走漫游或极限吞吐承诺。** 实测家用参数不代替出厂默认。

[完整变更](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/CHANGES-v1.md) · [Wi-Fi 修复详情](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FIX-WIFI-STABILITY-V1.6.1.md) · [来源与许可证](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/ATTRIBUTION.md)

本项目不是 OpenWrt、iStoreOS 或硬件厂商官方发布，各组件保留原许可证和上游署名。附带的 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 未修改，署名、许可证及对应源码书面提供承诺见其专页。

### 交流群与赞赏

**本固件交流群：1061612207**

![Wiro 交流群二维码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg)

赞赏自愿，不影响下载、使用或开源许可。

![赞赏码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png)

## English

Unofficial OpenWrt / iStoreOS community firmware for **Gemtek XR1710G (Airoha AN7581 + MediaTek MT7996)**.

### Changes from v1.6.0

- **Bridge-node kernel-log flood fixed:** an idle port (for example a node's unused WAN port) no longer prints the `USXGMII AN down` PCS diagnostic every second. In v1.4–v1.6.0 that ratelimited print still rotated the node's entire system log away within about eight minutes. It now reports once per link-state change; event-style `cdr-reset` diagnostics and the RX-lock recovery logic are unchanged. Verified on hardware: twelve hours of idle-port operation produced exactly one line and a complete boot-to-now log.
- **FT-over-DS roaming compatibility:** the factory 5GHz 802.11r configuration previously allowed over-the-air FT only (`ft_over_ds='0'`). Apple clients prefer FT over the distribution system and fell back to full authentication on every roam, which reconnected slowly at weak signal. Factory defaults and preserved-configuration upgrades now use `ft_over_ds='1'` (both mechanisms advertised). The migration changes only this switch — keys, channels and SSIDs are untouched. Verified active on both units after upgrade.
- **LuCI wireless-config rollback window:** applying a DFS-spanning 5GHz width (for example EHT160 with its ~60 s CAC) could exceed the stock 90-second LuCI confirmation window, which then rolled the change back — users saw 160 "revert" to 80. `luci.apply.rollback` is raised to 300 seconds out of the box; owner-configured values are preserved. This does not alter the background-CAC startup fix from v1.5.
- **MLO editor safety:** 802.11s mesh backhaul interfaces are hidden from the MLO AP/STA grid so the backhaul cannot be overwritten from that page; a notice points to Network → Wireless.
- Everything else is unchanged: Linux 6.18.41, kernel patch set (apart from the log gating above), mt76 r7, the IPv6 and detached-upgrade fixes, factory wireless defaults (5GHz channel 36 / EHT80 / 29 dBm), Argon, iStore, Docker, Full Cone, PassWall2, OpenClash and fan policy.

### Files and upgrading

The four assets are the **v1.6.1 sysupgrade ITB** (system firmware), the **v1.0.0 flash-slot BIN** (optional, unchanged U-Boot), **SHA256SUMS.txt** and the **bilingual FLASHING-GUIDE.md**. GitHub source archives are not flashable images. Verify SHA-256 before flashing.

Existing compatible U-Boot needs no update. Never upload a system ITB to **Update U-Boot**. Use **System → Backup / Flash Firmware**, or compatible U-Boot's system-firmware entry. v1.6.0 users simply perform an ordinary preserved-configuration upgrade; the FT-over-DS and rollback-window migrations apply automatically.

Wiro Recovery **System Firmware Double-Clean** erases configuration and overlay data, including Docker data stored there. Back up first. Wait for **100%, a solid green LED and a reachable system**; the red LED typically blinks for about three minutes. Do not remove power. Legacy compatible U-Boot uses **Firmware → UBI 2.0 - 439 MiB**, with the same ITB.

### Login, Wi-Fi and English UI

Clean installation: **192.168.50.1 / root / password**. Initial 2.4/5GHz networks have no preset password. The empty-key 6GHz Mesh template is disabled. Connect one unit by Ethernet and set passwords immediately. Preserved upgrades retain existing address, credentials and wireless settings.

Factory 5GHz: channel 36/EHT80; 6GHz template: channel 37/EHT160/802.11s. Select wider channels only where supported and permitted. A 5GHz 160MHz AP must complete DFS/CAC before broadcasting.

The initial UI is Chinese. Open **System → System → Language and Style** (系统 → 系统 → 语言和界面), choose **English**, then **Save & Apply** (保存并应用).

### Validation and attribution

Both units run this v1.6.1 image. All migrations verified active; the idle-port log fix confirmed with twelve hours of single-line output; wireless configuration preserved intact; 6GHz channel 37 / 320MHz 802.11s Mesh ESTAB on both ends; a Galaxy S24, MacBooks and iPhones associated and roamed normally with no checked driver, MCU or storage errors. These are post-flash and short-term checks, not long-term gaming, walking-roam or peak-throughput guarantees.

See [changes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/CHANGES-v1.md), [Wi-Fi fix details](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/FIX-WIFI-STABILITY-V1.6.1.md) and [attribution](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.1/ATTRIBUTION.md). Component licenses remain applicable. Optional [Wiro U-Boot](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) retains its attribution, licenses and written corresponding-source offer.

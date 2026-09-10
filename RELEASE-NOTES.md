# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.6.0

## 中文

Gemtek XR1710G（Airoha AN7581 + MediaTek MT7996）非官方社区固件。本版在 v1.5 基础上修复 IPv6 重复客户端及后台升级超时，回移两项官方 mt76 修复。

### 本次更新

- **IPv6 / CPU 高占用修复**：避免 PPPoE 自动 IPv6 和手动 DHCPv6 在同一链路重复启动、争用 ubus 后高速重试。保留正常 IPv6及用户配置，不靠关闭 IPv6 解决；重复逻辑接口报告 `DHCPV6_DUPLICATE_CLIENT`，修正配置后可重新连接。
- **后台升级修复**：确认后的升级由独立后台任务执行，避免校验和大配置备份超过旧 RPC 的 30 秒限制而被中止。保留原生镜像/布局校验和升级选项，加入重复提交保护、状态查询及中英文失败提示；关闭网页不取消任务，断线不等于升级成功，不自动重刷。
- **两项官方无线驱动修复**：回移 MCU 拒绝 TWT 时的链表清理、终端断开关联后的管理帧 ALTX 队列选择。沿用 `b2704cf5` 与现有 AN7581/10G/PPE/NPU 适配，mt76 包修订为 r7；不是整套无线驱动或内核升级，不宣称未经测试的吞吐提升。
- **其余保持不变**：Linux 6.18.41、设备树、hostapd、10G/PPE 保护、Argon、iStore、Docker、Full Cone、PassWall2、OpenClash、无线默认及风扇策略。BBR 已集成并默认启用，不必另装 TurboACC；BBR 不是所有转发流量或 UDP 的通用加速。

### 下载：只需关注这四个文件

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.0-sysupgrade.itb` | 唯一系统固件：兼容系统升级或 U-Boot 的系统固件入口 |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 原样附带的可选 U-Boot，仅用于 **更新 U-Boot / Update U-Boot** |
| `SHA256SUMS.txt` | 两个二进制的完整性校验，不刷入 |
| `FLASHING-GUIDE.md` | 中英文刷机教程，不刷入 |

**已有兼容 U-Boot 不需要重刷。不要把系统 ITB 上传到 Update U-Boot。**

- 兼容系统：备份配置 → 系统 → 备份/升级 → 上传 sysupgrade ITB。同系列保留配置升级继续使用原地址和密码。
- **从旧版升级的注意事项**：旧系统仍执行旧入口，上传 1.6 不能在刷入前修好旧入口。若遇到“等待但不重启”，不要反复提交；检查任务后安排受控 SSH 升级或修补旧入口。无需因此更新 U-Boot。
- Wiro Recovery：进入目标设备的 `http://192.168.255.1/`，选择“系统固件双清”，上传同一个 ITB。双清删除旧配置及 overlay 中的 Docker 等数据，务必先备份。红灯通常闪烁约三分钟，等待 **100%、绿灯常亮且系统可访问**，不要断电。
- 旧兼容 HTTP U-Boot：选择 **Firmware → UBI 2.0 - 439 MiB**，使用同一个 sysupgrade ITB。

### 初始账号与无线

- 管理地址：**192.168.50.1**；用户名：**root**；初始管理员密码：**password**。
- 2.4GHz / 5GHz Wi-Fi：**没有预设密码**；首次有线登录后立即设置加密。
- 6GHz Mesh：无预设 SAE 密钥，模板默认禁用。组网前设置两端一致的 Mesh ID、SAE 密钥、信道、带宽和监管设置。
- 出厂 5GHz 为 channel 36 / EHT80，6GHz 模板为 channel 37 / EHT160 / 802.11s；支持按实际环境选择 160/320MHz。5GHz 160MHz 启动需等待 DFS/CAC，不能将等待期误判为掉回80MHz。
- 保留配置升级不覆盖原密码和无线设置。两台干净设备不要同时接入网络，以免地址/DHCP冲突。

### 本版实机验证

两台 XR1710G 已刷入本次 1.6。主路由从 1.4 经受控 SSH 调用新后台任务完成保留配置升级并重启；网络、无线、DHCP、防火墙及 OpenClash 配置保持一致。PPPoE、IPv6、DNS、HTTPS 和 OpenClash 正常，IPv6 客户端保持单一，未出现此前重复注册重试。

两台 5GHz 运行160MHz，6GHz channel37 / 320MHz / 802.11s Mesh ESTAB。双向短测20/20、10/10 Ping无丢包；检查期间未发现所查驱动崩溃、MCU timeout 或存储错误。**这不是长期游戏、手机行走漫游或极限吞吐承诺，也未将 SSH 升级等同于浏览器完整刷机流程验收。** 实测家用参数不代替上述出厂默认。

[完整变更](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/CHANGES-v1.md) · [IPv6与上游补丁](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/FIX-IPV6-DUPLICATE-CLIENT.md) · [升级修复](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/FIX-BACKEND-UPGRADE.md) · [来源与许可证](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/ATTRIBUTION.md)

本项目不是 OpenWrt、iStoreOS 或硬件厂商官方发布，各组件保留原许可证和上游署名。附带的 [Wiro U-Boot v1.0.0](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) 未修改，署名、许可证及对应源码书面提供承诺见其专页。

### 交流群与赞赏

**本固件交流群：1061612207**

![Wiro 交流群二维码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/wiro-qq-group.jpg)

赞赏自愿，不影响下载、使用或开源许可。

![赞赏码](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/wiro-uboot-v1.0.0/support-qr.png)

## English

Unofficial OpenWrt / iStoreOS community firmware for **Gemtek XR1710G (Airoha AN7581 + MediaTek MT7996)**.

### Changes from v1.5

- **IPv6:** prevent duplicate PPP-auto and explicit DHCPv6 clients on one link, avoiding ubus-registration restart loops and excessive CPU usage without disabling working IPv6 or resetting configuration. A conflicting logical interface reports `DHCPV6_DUPLICATE_CLIENT`; correct its settings and reconnect it.
- **Backend upgrades:** run confirmed upgrades in detached jobs so validation and larger configuration backups survive the ordinary 30-second RPC limit. Preserve native validation and upgrade options; add mutual exclusion, status and error feedback. Closing the page does not cancel the job. Connection loss is not proof of success; there is no automatic retry.
- **mt76 backports:** rejected-TWT list cleanup and ALTX management-frame queuing after disassociation. Retain the `b2704cf5` baseline and board/10G/PPE/NPU fixes; package revision r7. No wholesale driver-stack update or unmeasured speed claim.
- Kernel 6.18.41, device tree, hostapd, plugins, Argon, Docker, fan policy and wireless defaults remain unchanged. BBR is already included and enabled; TurboACC is not required for BBR. BBR is not a general accelerator for forwarded traffic or UDP.

### Files and upgrading

The four assets are the **v1.6.0 sysupgrade ITB** (system firmware), the **v1.0.0 flash-slot BIN** (optional, unchanged U-Boot), **SHA256SUMS.txt** and the **bilingual FLASHING-GUIDE.md**. GitHub source archives are not flashable images. Verify SHA-256 before flashing.

Existing compatible U-Boot needs no update. Never upload a system ITB to **Update U-Boot**. Use **System → Backup / Flash Firmware**, or compatible U-Boot's system-firmware entry. An old installation still runs its old upgrade entrypoint: if it times out, do not repeatedly submit; inspect the task and arrange a controlled SSH upgrade or entrypoint hotfix.

Wiro Recovery **System Firmware Double-Clean** erases configuration and overlay data, including Docker data stored there. Back up first. Wait for **100%, a solid green LED and a reachable system**; the red LED typically blinks for about three minutes. Do not remove power. Legacy compatible U-Boot uses **Firmware → UBI 2.0 - 439 MiB**, with the same ITB.

### Login, Wi-Fi and English UI

Clean installation: **192.168.50.1 / root / password**. Initial 2.4/5GHz networks have no preset password. The empty-key 6GHz Mesh template is disabled. Connect one unit by Ethernet and set passwords immediately. Preserved upgrades retain existing address, credentials and wireless settings.

Factory 5GHz: channel36/EHT80; 6GHz template: channel37/EHT160/802.11s. Select wider channels only where supported and permitted. A 5GHz 160MHz AP must complete DFS/CAC before broadcasting.

The initial UI is Chinese. Open **System → System → Language and Style** (系统 → 系统 → 语言和界面), choose **English**, then **Save & Apply** (保存并应用).

### Validation and attribution

Both units booted this image. A retained-configuration main-router upgrade through the detached SSH-launched job completed, and PPPoE, IPv6, DNS, HTTPS, OpenClash and Mesh recovered. Key configuration files were unchanged. One stable DHCPv6 client remained, with no duplicate-client errors observed.

Both units ran 5GHz160 and 6GHz320 Mesh; short bidirectional checks passed 20/20 and 10/10 pings with no loss. No checked driver-crash/MCU/storage errors were found. These are basic post-flash checks, not long-term gaming, walking-roam or peak-throughput guarantees; the complete browser upload/polling flash flow was not independently exercised. Tested household settings are not factory defaults.

See [changes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/CHANGES-v1.md), [upstream fixes](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/FIX-IPV6-DUPLICATE-CLIENT.md) and [attribution](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/blob/v1.6.0/ATTRIBUTION.md). Component licenses remain applicable. Optional [Wiro U-Boot](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0) retains its attribution, licenses and written corresponding-source offer.

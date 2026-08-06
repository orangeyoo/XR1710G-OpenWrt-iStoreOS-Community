# 恩山论坛发布帖：Gemtek XR1710G iStoreOS/OpenWrt 社区第一版

## 标题建议

`[XR1710G] iStoreOS/OpenWrt 社区第一版发布：MT7996 Wi-Fi 7、6GHz 802.11s Mesh、EHT320、OpenClash、U-Boot`

## 正文

最近针对 Gemtek XR1710G 做了一套社区移植固件，现公开第一版测试发布。

这台设备的硬件组合是 Airoha AN7581 + MediaTek MT7996，重点解决了 XR1710G 在 OpenWrt/iStoreOS 生态中设备树、NAND/UBI 2.0、MT7996 Wi-Fi 7、6GHz 无线回程、iStoreOS 风格界面和 NPU 状态展示等适配问题。

### 下载

Release：

https://github.com/orangeyoo/iStoreOS-XR1710G-Community/releases/tag/v1.0.0

源码：

https://github.com/orangeyoo/iStoreOS-XR1710G-Community

Release 下载区只需要关注这几个文件：

| 文件 | 用途 |
|---|---|
| `xr1710g-uboot-first-release-flash-slot.bin` | U-Boot 更新文件，只在 U-Boot 的 Update U-Boot 页面刷一次 |
| `xr1710g-community-first-release-recovery.itb` | U-Boot Recovery 页面使用的系统镜像 |
| `xr1710g-community-first-release-sysupgrade.itb` | 已运行兼容 OpenWrt/iStoreOS 时使用的升级镜像 |
| `SHA256SUMS.txt` | 刷写前校验文件，不刷入路由器 |
| `FLASHING-GUIDE.md` | 中文和英文的文件用途及刷机路径说明 |

### 普通刷机路径

如果设备已经能正常进入兼容的 OpenWrt：直接使用 `sysupgrade.itb`。

如果设备进入了 YYH2913 U-Boot Recovery 页面：使用 `recovery.itb`。

只有需要更新 U-Boot 时，才刷 `uboot-first-release-flash-slot.bin`。不要把系统 ITB 当作 U-Boot，也不要把裸 `u-boot.bin` 直接刷进槽位。

刷机前请确认设备型号是 Gemtek XR1710G，并核对 SHA-256。首次启动管理地址为 `192.168.50.1`，用户名 `root`，初始密码为空；登录后立即设置密码。

### 这版主要改了什么

- 重新整理 XR1710G Airoha AN7581 设备树、分区和 UBI 2.0 镜像布局。
- 基于 Linux 6.18.38，固定 XR1710G MT76/MT7996 适配提交 `b2704cf5`。
- 默认 LAN 地址改为 `192.168.50.1`，减少与光猫 `192.168.1.1` 冲突。
- 默认 6GHz 回程为单跳 802.11s Mesh、US 监管域、PSC 信道 37、EHT320、WPA3-SAE。
- WDS/AP-WDS 兼容修复已包含，但 WDS 不是默认回程，MLO 默认关闭。
- 修正 MT7996 终态 `tx failed` 统计，加入无线、Mesh、温度和 NPU 诊断页面。
- 集成 iStoreOS 风格界面、iStore/QuickStart/Argon 入口、OpenClash 核心和软件源隔离修复。
- 增加 PPPoE/LAN 角色工具，避免把 PPPoE 误配置到 LAN。
- 2.4GHz 默认使用兼容老设备的 WPA/WPA2 Personal 混合策略；5GHz 用于终端接入，6GHz 默认用于 Mesh 回程。

### 6GHz 回程说明

默认方案是 802.11s Mesh，不是 MLO。两台 XR1710G 的 6GHz Mesh ID、WPA3-SAE 密钥、信道和带宽必须一致。

这套方案适合把 6GHz 专门用于节点间回程，同时让手机、电脑继续使用 5GHz/2.4GHz。是否能达到理想吞吐，取决于楼层距离、墙体、摆位和信号强度，不能只看理论 PHY 速率。

### 已完成的实机验收

两台 XR1710G 已完成只读日志检查：

- 6GHz Mesh 状态为 `ESTAB`
- US 监管域、信道 37、EHT320
- 两端 `tx failed=0`
- 温度约 `52.6°C / 56.7°C`
- 未发现 firmware crash、MCU timeout、kernel panic、watchdog、UBI/I/O 错误或 `airtime_link_metric_get`

重启或无线重载期间可能出现短暂 SAE 认证失败、Mesh 断开后自动恢复。这不代表零秒切换承诺。

### 已知边界

- 这是社区非官方构建，只适用于 XR1710G，不要刷到其他 Airoha 或 MediaTek 设备。
- Release 当前标记为 Pre-release，尤其是 U-Boot 大文件上传修复还需要更多新设备真机验收。
- 首次界面默认中文，英文用户进入 LuCI 后打开 `System → System → Language and Style`，将 Language 改为 `English`，点击 `Save & Apply`。
- 当前公开系统镜像是在最后一轮翻译审计前构建的；翻译修正已进入源码，后续重建镜像时会纳入。
- 不要上传包含 Wi-Fi 密码、PPPoE 账号密码、root 密码、DDNSTO token 或完整 `/etc/config` 的日志和备份。

### 上游来源

项目在源码中标注了 YYH2913/openwrt、naoki66/ImmortalWrt-for-Gemtek-XR1710G、iStoreOS/iStoreX、OpenClash、Argon、QuickStart、mt76、hostapd 以及 Airoha/MediaTek 上游内容。

U-Boot 来源于：

https://github.com/YYH2913/http-uboot

U-Boot 的来源、补丁和未修改范围见源码仓库的 `uboot/` 目录。

### 反馈问题时请提供

请注明：设备批次、当前模式（主路由/节点）、是否使用 6GHz Mesh、信道和带宽、摆放距离，以及脱敏后的 `dmesg`、`iw dev`、`ubus call network.wireless status` 输出。不要只发理论速率截图，也不要公开私人网络凭据。

建议发布版块：恩山无线论坛的 OpenWrt/iStoreOS 相关版块。

建议论坛标签：`XR1710G`、`iStoreOS`、`OpenWrt`、`Wi-Fi 7`、`6GHz Mesh`、`MT7996`。

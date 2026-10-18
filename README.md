# XR1710G OpenWrt / iStoreOS Wi-Fi 7 社区固件

**当前版本：[v2.02](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v2.02)** · 更新日期：2026-10-13 · 本次同时发布固件与可选 U-Boot 更新。

[![Release](https://img.shields.io/github/v/release/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E5%8F%91%E5%B8%83)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/total?style=flat-square&label=%E4%B8%8B%E8%BD%BD)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Stars](https://img.shields.io/github/stars/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E6%98%9F%E6%A0%87)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community)
[![Forks](https://img.shields.io/github/forks/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E5%A4%8D%E5%88%BB)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/forks)
[![Issues](https://img.shields.io/github/issues/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E9%97%AE%E9%A2%98)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/issues)
[![Last Commit](https://img.shields.io/github/last-commit/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E6%9C%80%E8%BF%91%E6%8F%90%E4%BA%A4)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/commits/source-2.0)
[![GPL-2.0](https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF%E8%AF%81-GPL--2.0--or--later-blue?style=flat-square)](ATTRIBUTION.md)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%E7%BA%BF-0099FF?style=flat-square)](https://openwrt.org)
[![Kernel](https://img.shields.io/badge/%E5%86%85%E6%A0%B8-6.18.53-green?style=flat-square)](CHANGES-v1.md)
[![Wi-Fi 7](https://img.shields.io/badge/Wi--Fi%207-MT7996%20%E4%B8%89%E9%A2%91-8A2BE2?style=flat-square)](https://en.wikipedia.org/wiki/Wi-Fi_7)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-333333?style=flat-square)](https://www.airoha.com/)
[![iStoreOS](https://img.shields.io/badge/iStoreOS-%E7%BB%84%E4%BB%B6%E9%9B%86%E6%88%90-FF6600?style=flat-square)](https://github.com/YYH2913/openwrt)
[![Docker](https://img.shields.io/badge/Docker-%E9%A2%84%E8%A3%85%E9%BB%98%E8%AE%A4%E5%85%B3-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![QQ Group](https://img.shields.io/badge/%E4%BA%A4%E6%B5%81%E7%BE%A4-1061612207-orange?style=flat-square)](#交流与支持)

面向 **Gemtek XR1710G** 的非官方社区固件：Wi-Fi 7 三频 + 6GHz 专线 Mesh 回程 + iStore 商店 + Docker，开箱即用。

**[下载最新 v2.02](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v2.02)** · [更新了什么](#v202-更新) · [刷机指南](docs/tutorials/XR1710G-Flashing-Guide-ZH.md) · [Mesh 组网教程](MESH-GUIDE-ZH.md) · [English](README-EN.md)

## 30 秒速览

| 项目 | 说明 |
|---|---|
| 适用于 | **仅 Gemtek XR1710G**（Airoha AN7581 + MediaTek MT7996） |
| 是什么 | 非官方 OpenWrt / iStoreOS 社区固件，不是任何厂商官方发布 |
| 亮点 | 三频 Wi-Fi 7、两台 6GHz 专线组网、iStore 商店、OpenClash / PassWall、Docker |
| 刷机后管理地址 | `http://192.168.50.1` |
| 初始账号 | 用户名 `root`，初始密码为 `password` |
| 首次 Wi-Fi | 2.4/5GHz 开放网络；登录后立即设置密码 |

⚠️ 不要刷入其他型号或外壳相似的其他 Airoha/MediaTek 设备。

## 四步上手

1. **下载**：v2.02 Release 页提供系统固件、Recovery 镜像和校验文件，普通用户只刷系统固件。
2. **刷入**：已在运行兼容 OpenWrt/iStoreOS → 后台上传升级；新机/全刷 → 兼容 U-Boot 上传同一个文件。详见 [FLASHING-GUIDE.md](FLASHING-GUIDE.md)。
3. **登录**：电脑网线连路由器，打开 `192.168.50.1`，`root / password`。
4. **收尾**：改管理员密码 → 给 2.4/5GHz 设密码；要两台组网看 [Mesh 教程](MESH-GUIDE-ZH.md)（一页纸，照表格填空即可）。

界面默认简体中文；切换英文：**系统 → 系统 → 语言和界面 → English → 保存应用**。

## 图文刷机教程（新手版）

不想翻文字版？这份图文教程从拆机接 TTL 讲到刷入 Wiro iStoreOS 固件，全程截图对照，跟着做就能完成：

- **中文版**：[在线图文版](docs/tutorials/XR1710G-Flashing-Guide-ZH.md) · [PDF](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/v2.02/XR1710G-Flashing-Guide-ZH.pdf)
- **English**: [Read online](docs/tutorials/XR1710G-Flashing-Guide-EN.md) · [PDF](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/download/v2.02/XR1710G-Flashing-Guide-EN.pdf)

两份 PDF 也作为附件挂在 [v2.02 Release](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v2.02) 页面，可直接下载打印。

## v2.02 更新

- **passwall 取代 passwall2**：v1 应用，fw4/nftables 双适配；出厂未开启，在面板自行配置节点（勿与 OpenClash 同开）。
- quickstart/iStore 首页出厂默认简体中文（修复 kenzok8 quickstart po 目录布局导致的英文回退）。
- **UPnP 根治**：miniupnpd 改用 nftables 变体，规则经 nftables.d 片段自动挂入 fw4；旧 iptables 变体的 fw4 告警与不上链问题消除。
- 首启自动修复 argon 设置页 rpcd 后端 CRLF（"luci.argon Object not found"）。
- 内核 TCP 缓冲调优；PPE PPPoE 卸载 MAC 校验修正（`9999-32`）。
- 可选 Wiro U-Boot 更新至 v2.1：修复 v2.0 恢复页底部乱码，页脚 `xr1710g-wiro-recovery-2.1`。
- 对应完整源码随本版公布：分支 `source-2.0`，标签 `v2.02`。

v2.0/2.01 的完整变更见对应 [Release 页](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases)。PPE 硬件转发/PPPoE 快速路径/Full Cone NAT 等基础能力自 v2.0 起延续。

10G 双向线速与长期稳定性仍是进行中目标，本版未作最终验收；家庭实际使用已验证外网有线/无线下载稳定。

Mesh 回程请关闭 MLO；MLO + WDS 桥接仍有兼容性问题。

切换国家码后若 5GHz 异常，请重启 5GHz 无线并等待 DFS 检查完成。

历史版本逐条变更见 [CHANGES-v1.md](CHANGES-v1.md)。

## 下载与升级

[v2.02 发布页](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v2.02)提供以下附件：

| 文件 | 用途 |
|---|---|
| `istoreos-xr1710g-community-2.02-r0-59ae07f-airoha-an7581-econet_xr1710g-ubi-squashfs-sysupgrade.itb` | **系统固件**：后台升级或兼容 U-Boot 永久安装都用它 |
| `istoreos-xr1710g-community-2.02-r0-59ae07f-airoha-an7581-econet_xr1710g-ubi-initramfs-recovery.itb` | Recovery/全刷镜像：U-Boot Recovery 页或救砖用，普通升级不需要 |
| `xr1710g-wiro-uboot-v2.1-flash-slot.bin` | 可选 Wiro U-Boot v2.1（恢复页乱码修复），仅用于"更新 U-Boot"，已有设备不强制重刷 |
| `XR1710G-Flashing-Guide-ZH.pdf` / `-EN.pdf` | 图文刷机指南（中文/英文），不刷入 |
| `SHA256SUMS` | 校验文件，不刷入 |

**Wiro U-Boot v2.1 为可选更新**（修复 v2.0 恢复页底部乱码；flash-slot 布局不变，不刷不影响固件使用）：恢复页（断电 → 红灯亮起长按 reset → 192.168.255.1）选择该文件上传即可，无需 TTL。来源与许可证见 [v2.02 发布页（含 U-Boot v2.1 附件）](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v2.02)与[U-Boot 源码分支](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/tree/uboot-2.0)。刷机步骤见 [FLASHING-GUIDE.md](FLASHING-GUIDE.md)。

v2.02 已在实机验证保配置升级（v2.01/v2.0 → v2.02）；从 v1.x 直接升级仍建议**不保留配置**。GitHub 自动生成的 Source code 压缩包即本版完整源码（分支 `source-2.0`），不是刷机文件；不要把系统 ITB 刷进 U-Boot 槽位。升级前备份重要数据；旧后台升级若超时不重启，不要反复提交，按指南排查。

## 首次启动默认值

干净首启后，驱动加载完成才应用无线默认值：

- 2.4GHz：US、信道 1、EHT20、请求 28dBm；SSID `XR1710G`，初始开放且没有预置密码。
- 5GHz：US、channel 36、EHT160、请求 29dBm；SSID `XR1710G-5G`，初始开放且没有预置密码，启用 802.11k/v/r 与终端防误清退设置。
- 6GHz：US、PSC channel 37、EHT160、请求 28dBm；SSID `XR1710G-6G`，初始为 OWE AP，要求 PMF。
- 三频初始各自为单链路 MLO AP；Mesh 回程需另行配置，并关闭回程接口 MLO。
- 2.4/5GHz 不预置 Wi-Fi 密码；首次登录后应立即修改管理员密码并设置无线加密。
- 三频共享同一个 Linux PHY，监管域只能三频统一，不能按频段设置不同国家码。

需要兼容老设备时，2.4GHz 可选 WPA/WPA2 混合加密。XZ 实验档（AU 派生 + 6GHz 36dBm 实验规则）默认关闭，仅限已取得授权的受控测试，详见历史文档。

## 两台组网（Mesh 回程）

```
光猫 ── 主路由(192.168.50.1) ════ 6GHz 专线 ════ 节点(192.168.50.2)
              │                                      │
        手机/电脑连 2.4G/5G Wi-Fi ——全屋同名，自动漫游
```

完整步骤见 [MESH-GUIDE-ZH.md](MESH-GUIDE-ZH.md)（一页纸简明版）。角色准备命令：

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24   # 或 main-pppoe
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

工具只备份并提交配置，不擅自重载网络或重启。

## 功能一览

| 类别 | 内容 |
|---|---|
| 系统 | Linux 6.18.53、UBI 2.0 布局、默认地址 192.168.50.1、performance 调频、单控制器风扇策略 |
| 无线 | 三频 Wi-Fi 7（MT7996，mt76 be5ce791-r10，mac80211/cfg80211 backports 7.2-r4）、802.11s Mesh、802.11k/v/r、BBR 默认启用 |
| 商店/插件 | iStore、iStoreX、QuickStart、Argon 主题、OpenClash、PassWall（默认关闭，勿与 OpenClash 同开）、Nikki、EqosPlus |
| Docker | OpenWrt 上游 Moby/containerd/runc/compose + Dockerman；预装但默认关闭，三入口共用一套配置 |
| 网络 | PPE 硬件流卸载/NAT 快速路径（修复并出厂启用）、Full Cone NAT（默认开启，不能绕过 CGNAT/双重 NAT）、10G 口保护修复 |
| 诊断 | `xr1710g-role` 角色工具、`xr1710g-mesh-diag` 脱敏诊断、状态页缓存化（不走 devmem） |

## 源码发布

**v2.0 起完整源码随版本公布**：分支 [`source-2.0`](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/tree/source-2.0)（标签 `v2.02`）是 v2.02 镜像对应的完整 OpenWrt / iStoreOS 构建树——Linux 6.18.53 Airoha 平台 XR1710G BSP 补丁集（SOE/PPE 卸载栈、LRO、缓冲转发等 `9999-*` 系列）、mt76/MT7996 NPU 栈（`0100–0114`）、fullcone NAT、XR1710G 出厂默认与 LuCI 应用；构建种子 `xr1710g-2.0.seed.config`（`cp xr1710g-2.0.seed.config .config && make defconfig`）。U-Boot 源码不在其中，详见树内 [XR1710G-SOURCE-2.0.md](XR1710G-SOURCE-2.0.md)。

v1.x 时代的构建脚手架（`configs/`、`feeds.d/`、`patches/` 等）已于 2026-10-11 自仓库移除以免误导；其内容可在 v1.6.1–v1.9 标签的 Source 归档中查阅。

## 历史版本构建

v1.x 版本使用旧的 Docker 构建脚手架构建；该脚手架已于 2026-10-11 随仓库整理移除，
如需查阅见 v1.6.1–v1.9 标签的 Source 归档。v2.0 起直接从本源码树构建（见上文
“源码发布”与树内 [XR1710G-SOURCE-2.0.md](XR1710G-SOURCE-2.0.md)）。

## 上游与许可证

本项目以 [YYH2913/openwrt](https://github.com/YYH2913/openwrt) 板级支持为基础，按 iStoreOS 公开组件方式集成，并使用/标注 YYH2913/http-uboot、OpenWrt、mt76、hostapd、iStore/iStoreX、QuickStart、OpenClash、PassWall、Argon、Nikki、sirpdboy/EqosPlus 及 Airoha/MediaTek 上游内容。完整固定提交与许可证见 [ATTRIBUTION.md](ATTRIBUTION.md)；各组件继续适用其原许可证，上游不为本固件背书。

## 交流与支持

| 交流群 **1061612207** | 赞赏自愿 |
|---|---|
| <img src="docs/images/wiro-qq-group.jpg" width="240" alt="QQ群二维码"> | <img src="docs/images/support-qr.png" width="240" alt="赞赏码"> |

# XR1710G OpenWrt / iStoreOS Wi-Fi 7 社区固件

[![Release](https://img.shields.io/github/v/release/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E5%8F%91%E5%B8%83)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/total?style=flat-square&label=%E4%B8%8B%E8%BD%BD)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/latest)
[![Stars](https://img.shields.io/github/stars/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E6%98%9F%E6%A0%87)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/stargazers)
[![Forks](https://img.shields.io/github/forks/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E5%A4%8D%E5%88%BB)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/forks)
[![Issues](https://img.shields.io/github/issues/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E9%97%AE%E9%A2%98)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/issues)
[![Last Commit](https://img.shields.io/github/last-commit/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community?style=flat-square&label=%E6%9C%80%E8%BF%91%E6%8F%90%E4%BA%A4)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/commits/public-first-release)
[![GPL-2.0](https://img.shields.io/badge/%E8%AE%B8%E5%8F%AF%E8%AF%81-GPL--2.0--or--later-blue?style=flat-square)](ATTRIBUTION.md)
[![OpenWrt](https://img.shields.io/badge/OpenWrt-24.10%20%E7%BA%BF-0099FF?style=flat-square)](https://openwrt.org)
[![Kernel](https://img.shields.io/badge/%E5%86%85%E6%A0%B8-6.18.41-green?style=flat-square)](CHANGES-v1.md)
[![Wi-Fi 7](https://img.shields.io/badge/Wi--Fi%207-MT7996%20%E4%B8%89%E9%A2%91-8A2BE2?style=flat-square)](https://en.wikipedia.org/wiki/Wi-Fi_7)
[![SoC](https://img.shields.io/badge/SoC-Airoha%20AN7581-333333?style=flat-square)](https://www.airoha.com/)
[![iStoreOS](https://img.shields.io/badge/iStoreOS-%E7%BB%84%E4%BB%B6%E9%9B%86%E6%88%90-FF6600?style=flat-square)](https://github.com/YYH2913/openwrt)
[![Docker](https://img.shields.io/badge/Docker-%E9%A2%84%E8%A3%85%E9%BB%98%E8%AE%A4%E5%85%B3-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![QQ Group](https://img.shields.io/badge/%E4%BA%A4%E6%B5%81%E7%BE%A4-1061612207-orange?style=flat-square)](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/wiro-uboot-v1.0.0)

面向 **Gemtek XR1710G** 的非官方社区固件：Wi-Fi 7 三频 + 6GHz 专线 Mesh 回程 + iStore 商店 + Docker，开箱即用。

**[下载最新 v1.6.1](https://github.com/orangeyoo/XR1710G-OpenWrt-iStoreOS-Community/releases/tag/v1.6.1)** · [更新了什么](#v161-更新) · [刷机指南](FLASHING-GUIDE.md) · [Mesh 组网教程](MESH-GUIDE-ZH.md) · [English](README-EN.md)

## 30 秒速览

| 项目 | 说明 |
|---|---|
| 适用于 | **仅 Gemtek XR1710G**（Airoha AN7581 + MediaTek MT7996） |
| 是什么 | 非官方 OpenWrt / iStoreOS 社区固件，不是任何厂商官方发布 |
| 亮点 | 三频 Wi-Fi 7、两台 6GHz 专线组网、iStore 商店、OpenClash/PassWall2、Docker |
| 刷机后管理地址 | `http://192.168.50.1` |
| 初始账号 | 用户名 `root`，初始密码为 `password` |
| 首次 Wi-Fi | 2.4/5GHz 开放网络；登录后立即设置密码 |

⚠️ 不要刷入其他型号或外壳相似的其他 Airoha/MediaTek 设备。

## 四步上手

1. **下载**：Release 页只需关注 4 个文件（见下表），普通用户只刷第 1 个。
2. **刷入**：已在运行兼容 OpenWrt/iStoreOS → 后台上传升级；新机/全刷 → 兼容 U-Boot 上传同一个文件。详见 [FLASHING-GUIDE.md](FLASHING-GUIDE.md)。
3. **登录**：电脑网线连路由器，打开 `192.168.50.1`，`root / password`。
4. **收尾**：改管理员密码 → 给 2.4/5GHz 设密码；要两台组网看 [Mesh 教程](MESH-GUIDE-ZH.md)（一页纸，照表格填空即可）。

界面默认简体中文；切换英文：**系统 → 系统 → 语言和界面 → English → 保存应用**。

## v1.6.1 更新

- 修复桥接节点内核日志刷屏：空置 WAN 口不再每秒刷 `USXGMII AN down`，日志不再被冲掉（实机 12 小时仅 1 条）。
- 修复 Apple 设备漫游兼容：出厂及升级迁移改用 `ft_over_ds='1'`，跨 AP 漫游不再退回完整认证；只改该开关，不触碰用户无线设置。
- 修复 LuCI 无线配置误回退：应用 160MHz 等 DFS 频宽时的确认窗口从 90 秒提升到 300 秒，不再被误判回滚为 80MHz。
- MLO 编辑器隐藏 802.11s Mesh 回程接口，防止误改导致组网损坏。
- IPv6 去重、后台升级修复、mt76 r7、默认密码与无线参数不变。详情及验证边界见 [Wi-Fi 修复说明](FIX-WIFI-STABILITY-V1.6.1.md)。
- 两台已完成刷后验收：迁移全部生效、节点日志完整保留、6GHz Mesh ESTAB、多品牌手机/电脑接入漫游正常。

历史版本（v1.4 起）逐条变更见 [CHANGES-v1.md](CHANGES-v1.md)。

## 下载：只需关注 4 个文件

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.6.1-sysupgrade.itb` | **唯一系统固件**：后台升级或兼容 U-Boot 永久安装都用它 |
| `xr1710g-wiro-uboot-recovery-v1.0.0-flash-slot.bin` | 可选 U-Boot 更新，只能在"更新 U-Boot"页面刷；已有兼容 U-Boot 不必重刷 |
| `SHA256SUMS.txt` | 校验文件，不刷入 |
| `FLASHING-GUIDE.md` | 中英文刷机教程，不刷入 |

不需要 recovery.itb；GitHub 自动生成的 Source code 压缩包不是刷机文件；不要把系统 ITB 刷进 U-Boot 槽位。旧后台升级若超时不重启，不要反复提交，按指南排查。

## 首次启动默认值

干净首启后，驱动加载完成才应用无线默认值：

- 2.4GHz：US、自动信道、HE20、请求 28dBm；SSID `XR1710G`，初始开放且没有预置密码。
- 5GHz：US、channel 36、EHT80、请求 29dBm；SSID `XR1710G-5G`，初始开放且没有预置密码，启用 802.11k/v/r 与终端防误清退设置。
- 6GHz：US、PSC channel 37、EHT160、请求 28dBm、WPA3-SAE 802.11s Mesh 模板；没有预置密钥，因此首次默认禁用，两端设置相同 Mesh ID 和密钥后启用。
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
| 系统 | Linux 6.18.41、UBI 2.0 布局、默认地址 192.168.50.1、performance 调频、单控制器风扇策略 |
| 无线 | 三频 Wi-Fi 7（MT7996，mt76 固定基线 b2704cf5）、802.11s Mesh、802.11k/v/r、BBR 默认启用 |
| 商店/插件 | iStore、iStoreX、QuickStart、Argon 主题、OpenClash、PassWall2（默认关闭，勿与 OpenClash 同开）、Nikki、EqosPlus |
| Docker | OpenWrt 上游 Moby/containerd/runc/compose + Dockerman；预装但默认关闭，三入口共用一套配置 |
| 网络 | Airoha PPE 硬件卸载、Full Cone NAT（默认关闭，不能绕过 CGNAT/双重 NAT）、10G 口保护修复 |
| 诊断 | `xr1710g-role` 角色工具、`xr1710g-mesh-diag` 脱敏诊断、状态页缓存化（不走 devmem） |

## 实机验证边界（诚实声明）

- v1.6.1：两台实机刷后验收通过（迁移生效、节点日志保留、Mesh ESTAB、多终端接入漫游正常）；不代表长期游戏、行走漫游或极限吞吐承诺。
- v1.4 历史：10G 直连 3.85/1.69Gbps、6GHz 320MHz 摆位实测中位约 715/720Mbps 等数据为特定条件实测，详见 [CHANGES-v1.md](CHANGES-v1.md)，不构成所有环境保证。
- 历史要点：v1.5 修复 5GHz 160MHz 前台 CAC 启动；v1.4 修复 LAN 编辑/首页重定向/风扇单控/Dockerman Moby 29 显示，删除 GlassTheme 及其中文包，并预装 Full Cone 与 PassWall2。

## 构建

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

关键入口：`configs/openwrt.config`（固定配置）、`feeds.d/openwrt`（固定上游提交）、`diy-part2.d/openwrt.sh`（社区集成）、`patches/`（补丁集）、`scripts/prebuild-xr1710g-release.sh`（源码门禁）、`scripts/verify-xr1710g-build.sh`（镜像门禁）。

## 上游与许可证

本项目以 [YYH2913/openwrt](https://github.com/YYH2913/openwrt) 板级支持为基础，按 iStoreOS 公开组件方式集成，并使用/标注 YYH2913/http-uboot、naoki66/ImmortalWrt-for-Gemtek-XR1710G、OpenWrt、mt76、hostapd、iStore/iStoreX、QuickStart、OpenClash、PassWall2、Argon、Nikki、sirpdboy/EqosPlus 及 Airoha/MediaTek 上游内容。完整固定提交与许可证见 [ATTRIBUTION.md](ATTRIBUTION.md)；各组件继续适用其原许可证，上游不为本固件背书。

固件交流群：**1061612207**

# 开源来源、版权与许可证说明

`iStoreOS-XR1710G-Community` 是多个开源项目的社区集成和 XR1710G 真机适配。
它不是 LinkEase/iStoreOS、OpenWrt、ImmortalWrt、Gemtek、Airoha 或 MediaTek 的
官方产品。各文件和二进制组件继续适用其上游许可证与版权声明。
本仓库原创的构建脚本、集成代码和说明在没有其他文件级声明时采用
`GPL-2.0-or-later`；该许可不覆盖或重新授权第三方组件。

## 核心系统与设备支持

| 项目 | 本项目中的用途 | 来源/固定版本 | 许可证说明 |
|---|---|---|---|
| [YYH2913/openwrt](https://github.com/YYH2913/openwrt) | XR1710G DTS、AN7581 target、UBI 2.0、网口、NPU/MT7996 支持 | `2a845ee80c7c52caafe57d518a15b16738eb9ed7` | 以仓库内各组件许可证为准，OpenWrt 核心主要为 GPL-2.0 |
| [OpenWrt](https://github.com/openwrt/openwrt) | Linux 路由系统、构建系统、软件包框架 | 由 YYH2913 分支及固定 feeds 提供 | GPL-2.0 及各软件包自身许可证 |
| [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) | 配置兼容与社区生态参考 | `configs/immortalwrt.config` | 以各文件/软件包声明为准 |
| [naoki66/ImmortalWrt-for-Gemtek-XR1710G](https://github.com/naoki66/ImmortalWrt-for-Gemtek-XR1710G) | `luci-app-airoha-fancontrol`、`luci-app-airoha-flowsense`、`luci-app-airoha-npu` 初始来源 | 同步工作流明确记录来源 | 应用 Makefile 声明 GPL-2.0-or-later 或 Apache-2.0 |

## 无线、Mesh 与网络补丁

| 项目 | 本项目中的用途 | 来源/固定版本 | 许可证说明 |
|---|---|---|---|
| [OpenWrt mt76](https://github.com/openwrt/mt76) | MT7996 Wi-Fi 7 驱动 | `b2704cf5a4068b672bf47ad5bf6b4802b6770a90`，叠加 YYH2913 AN7581/NPU 补丁 | ISC/GPL 兼容声明以源码文件为准 |
| [hostapd/wpa_supplicant](https://w1.fi/hostapd/) | WPA3-SAE、802.11s Mesh、AP/STA-WDS | `b004de0bf1b54d669d358b7f33d6f474bd9719a6` | BSD-3-Clause |
| hostapd commit `61280edc...` | 多 BSS 下 WDS unexpected-frame 事件路由修复 | 补丁保留作者 Kamil Bienkiewicz 和 Signed-off-by | 沿用 hostapd 许可证 |
| OpenWrt uhttpd / iStoreOS backports | `/apps` raw proxy、后端关闭及 forwarded headers | 来自 iStoreOS `istoreos-24.10` 的公开补丁，源码内保留版权文本 | uhttpd 的 ISC 许可及补丁原声明 |

## iStoreOS、LuCI 与应用生态

| 项目 | 本项目中的用途 | 固定来源 |
|---|---|---|
| [iStoreOS](https://github.com/istoreos/istoreos) | iStoreOS 公开组件化方式、QuickStart/iStoreX 与 `/apps` 兼容参考 | 选择性回移，不冒充官方发行版 |
| [LinkEase iStore](https://github.com/linkease/istore) | `luci-app-store` 软件中心 | `7c5c69796fd9798610a56a80e1895aa9033e1e6c` |
| [LinkEase NAS packages](https://github.com/linkease/nas-packages) | NAS 应用 feed | `e6953655559ceafd1684d8f9ac3c7d8d602771bc` |
| [LinkEase NAS LuCI](https://github.com/linkease/nas-packages-luci) | NAS 应用 LuCI feed | `a2f8a871477c79744051f4fdc7f703a23b91c227` |
| [jjm2473/openwrt-third](https://github.com/jjm2473/openwrt-third) | iStoreOS 第三方聚合 feed | `02355a3eb0c58b4d2747e1ec0fc78ac2cd0f8519` |
| [OpenClash](https://github.com/vernesong/OpenClash) | `luci-app-openclash` 与标准 UI 路径 | `a9e5d98cd664917724dbfb0a31440e512ab45a1b` |
| [kenzok8/openwrt-clashoo](https://github.com/kenzok8/openwrt-clashoo) | Clash 相关依赖 feed | `3f88fbc93d3c6c83a148f2bd9aaed71409f78325` |
| [Nikki](https://github.com/nikkinikki-org/OpenWrt-nikki) | 可选代理应用 feed | `f06b6b448928501e7511bdfb3497b1186d919316` |
| [sirpdboy/luci-app-poweroffdevice](https://github.com/sirpdboy/luci-app-poweroffdevice) | sirpdboy feed 锚点；EqosPlus 另按其仓库许可证分发 | `8f53359c3234c7c398b846b5425f9b0b017c03ec` |
| [wukongdaily/luci-app-run](https://github.com/wukongdaily/luci-app-run) | 可选应用 feed | `a114f683c19bcac4b8c378048e94408bed183b2f` |
| [luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) | LuCI Argon 主题 | 固件 manifest 所列版本；沿用上游许可证 |

## 构建与发布工具

- [P3TERX/Actions-OpenWrt](https://github.com/P3TERX/Actions-OpenWrt)：早期 GitHub Actions OpenWrt 构建流程参考。
- [GitHub Actions](https://github.com/features/actions)：自动构建运行环境。
- [softprops/action-gh-release](https://github.com/softprops/action-gh-release)：Release 发布 action。
- [klever1988/cachewrtbuild](https://github.com/klever1988/cachewrtbuild)：OpenWrt 构建缓存 action。

## 二进制固件与商标

MT7996、AN7581 NPU、RTL826x 等固件包可能包含由硬件厂商提供并经上游项目
重新分发的二进制文件。其许可和再分发条件以对应 OpenWrt 包、源码仓库和固件
文件附带声明为准。`OpenWrt`、`iStoreOS`、`ImmortalWrt`、`Gemtek`、`Airoha`、
`MediaTek` 等名称及商标归各自权利人所有；本项目中的使用仅用于说明兼容性。

## 贡献与再分发

再分发源码或固件时，请同时保留：

1. 本文件和上游版权/许可证声明。
2. `feeds.d/openwrt` 中的固定提交信息。
3. 补丁头部的作者、提交号和 Signed-off-by。
4. “社区测试版、非官方发布”的显著说明。

若某个文件自身带有许可证头，则该文件头优先于本聚合说明。

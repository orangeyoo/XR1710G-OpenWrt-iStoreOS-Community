# XR1710G iStoreOS / OpenWrt Wi-Fi 7 社区固件

**XR1710G 固件、iStoreOS XR1710G 移植、OpenWrt XR1710G、MT7996 Wi-Fi 7、
6GHz 无线回程、802.11s Mesh 与 AP-WDS。**

这是面向 **Econet/Gemtek XR1710G（Airoha AN7581 + MT7996）** 的社区移植。
它以 [YYH2913/openwrt](https://github.com/YYH2913/openwrt) 的 XR1710G
板级支持为底座，并按 iStoreOS 的公开组件化方式加入
[iStore](https://github.com/linkease/istore) 软件中心和 QuickStart。

它不是 iStoreOS 官方发布版；系统内也会显示
`iStoreOS-XR1710G-Community First Release`，以免与官方镜像混淆。

本项目提供可复现构建源码、Recovery/Sysupgrade 固件、SHA-256、中文刷机说明、
6 GHz Mesh/WDS 实测结果和脱敏诊断工具。默认管理地址为 `192.168.50.1`，
适合需要 XR1710G OpenWrt、iStore 软件中心、OpenClash、Wi-Fi 漫游和 6 GHz
无线回程的用户。

> 搜索关键词：XR1710G OpenWrt、XR1710G iStoreOS、XR1710G 固件、Gemtek
> XR1710G、Airoha AN7581、MediaTek MT7996、Wi-Fi 7 路由器、6GHz Mesh、
> EHT320、802.11s、WDS、ImmortalWrt。

## 这一版包含什么

- XR1710G 专用 DTS、网络映射、UBI 升级逻辑和 MT7996/NPU 固件。
- `luci-app-store`、`quickstart`、`luci-app-quickstart`。
- `wpad-mesh-openssl`，用于 WPA3-SAE 的 802.11s Mesh。
- hostapd AP-WDS 多 BSS 事件路由修复；6 GHz EHT320 的 AP-WDS/STA-WDS
  四地址桥接已在两台真机上验证可用，但默认仍保留长期验证的 802.11s。
- `usteer`，用于两台 AP 交换 802.11k/v 邻居信息；默认是温和模式，不拒绝
  关联、不踢客户端，也不硬编码 SSID。
- `wireless-regdb`、`iw-full` 和 `tcpdump`，便于检查 6 GHz 回程。
- 监管域默认 `US`；社区版首启把 6 GHz 设置为经过双机验证的
  802.11s、信道 37、`EHT80`，并使用必须修改的占位密钥。
- `/usr/sbin/xr1710g-mesh-diag`，用于生成脱敏的无线/Mesh 诊断报告。
- `/usr/sbin/xr1710g-role`，用于安全、显式地设置主路由或 Mesh 节点角色；
  它不会自行重载网络或重启。
- `/usr/sbin/xr1710g-wireless-defaults`，在 MT7996 驱动加载后确认三频配置完整，
  再一次性应用 2.4/5 GHz 漫游和 6 GHz SAE Mesh 首启策略；失败会下次重试。
- AdGuard Home 作为可选应用保留，但无配置时默认禁用，不抢占 DNS 或设置端口。
- `/etc/init.d/xr1710g-bootlog`，记录有界的有序/非有序关闭历史；它不能判定
  非有序关闭究竟来自断电、复位还是 watchdog。

软件中心界面和 APK 兼容层已经内置，但第三方应用是否提供
`aarch64_cortex-a53`/APK 包仍由对应应用仓库决定，不能把“软件中心能打开”
等同于“商店内每个应用都能安装”。

系统软件源固定为 OpenWrt 官方 `snapshots` 中实际存在的 7 个仓库；iStore 的
`is-opkg` 包装器则使用隔离的私有仓库列表。这样 QuickStart 首页不会因为
不存在的 `releases/SNAPSHOT` 或第三方目录而循环报告“软件源错误”。
snapshot 是滚动仓库，除非已确认版本和内核 ABI 匹配，否则不要批量升级
内核、驱动和底层系统包。

本次验证时，iStore 的 APK 服务端已提供 `aarch64_cortex-a53` 到
`aarch64_generic` NAS 仓库的映射；这说明商店具备该架构的软件源入口，
但仍不代表每个具体应用都已提供可安装包。

First Release 的首次启动、恢复出厂和 Recovery/failsafe 管理地址统一为
`192.168.50.1`（`/24`），避免与常见的 `192.168.1.1` 光猫管理网冲突；
用户名 `root`，初始密码为空。请先通过有线 LAN 登录并立即设置管理员密码。
无线初始配置只用于确认
三张射频卡和双机回程是否正常；投入使用前必须同时修改两台的 Mesh 密钥。

First Release 的普通无线首启占位配置是：2.4 GHz 使用 `psk-mixed` 并启用 802.11k/v，
但关闭 802.11r，以兼容只支持 WPA/WPA2 Personal 的老设备；5 GHz 使用
`sae-mixed` 并启用 802.11r/k/v，FT mobility domain 为 `6616`。占位 SSID
和密码不含任何真机凭据，刷完后应在两台设备上分别设置成完全相同的 SSID、
加密方式和密码。这里的配置不会从主路由自动复制到节点。

## 主路由与节点角色

同一份固件可以刷两台，但无法在离线镜像中判断哪台是主路由。默认两台都会
以 `192.168.50.1` 和 DHCP 服务器启动，所以必须逐台配置，不能把两台未经
设置的设备同时接入同一网络：

1. 主路由：设置最终 LAN 地址（例如 `192.168.10.1`）、开启 DHCP，并只在
   独立 WAN 接口上配置 DHCP/PPPoE；不要把 LAN 协议改成 PPPoE。
2. Mesh 节点：设置同网段且不冲突的静态地址（例如 `192.168.10.2`），关闭
   DHCP 服务器，将网关和 DNS 都设为主路由地址。
3. 两台分别设置相同的 2.4/5 GHz SSID、加密方式和密码；6 GHz 两端则必须
   使用相同的 Mesh ID、SAE 密钥、信道和带宽。
4. 先保留网线管理路径确认 `mesh plink: ESTAB`，再拔掉节点网线测试纯无线
   回程。不要同时修改两台并重载无线，以免失去管理连接。

固件不会写入 PPPoE 账号、root 密码、用户 SSID/密码或上述示例地址。

First Release 提供角色工具来减少误把 LAN 改成 PPPoE 的风险：

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.10.1/24
xr1710g-role main-pppoe 192.168.10.1/24
xr1710g-role node 192.168.10.2/24 192.168.10.1
```

它先在 `/root/xr1710g-role-backups/` 保存 UCI 备份，然后只提交配置，不重载
网络、无线、DNS、防火墙，也不自动重启。保持网线连接，运行 `status` 复核后
再自行重启。PPPoE 新密码通过终端隐藏输入，不放在命令行历史中。

## First Release 刷后验证边界

First Release 保持已在双机 A/B 测试中验证的 mt76 模块，并在离线验收中逐字节校验。
AdGuard 默认禁用、角色工具、漫游首启值、Recovery/Sysupgrade 文件一致性等
可以在刷前验证。Airoha TRNG 的 SCU 时钟开启顺序虽已修正，但其偶发冷启动
问题只能在真机新内核启动后证明，因此必须先刷节点，做多轮彻底断电冷启动并
检查三张无线、NPU、`dmesg` 和服务端口；节点通过后才刷主路由。

OpenClash 仍使用官方的 `/usr/share/openclash/ui` 路径，内置 Metacubexd 和
Zashboard。v6 同时预置 `/etc/crontabs/root` 并在首启强制修复为 `0600`，
解决 OpenClash 卡在 “Step 5: Add Cron Rules, Start Daemons...” 的问题。

## 构建

本地 Linux/Docker 构建：

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

构建成功后，文件位于 Docker volume 的版本化 `/work/dist/` 子目录。构建脚本固定了
XR1710G 源码与第三方 feeds 的 commit，并在产出后自动核验设备 profile、
软件包清单、MT7996 固件及镜像类型。构建还会在完整 rootfs 安装后强制重建
recovery，并验证 FIT 中存在独立 ramdisk；随后解压 cpio，检查 `/init`、
iStore、QuickStart 和诊断脚本，避免交付只有 recovery 文件名、实际却没有
内存根文件系统的无效镜像。GitHub Actions 的唯一目标也是 `openwrt`。

## 刷机前必须确认

本次底座采用 YYH2913 2026 年的新 XR1710G UBI 布局。源码明确警告：
BMT/BBT 边界已经变化，必须先使用匹配的新布局 chainloader/U-Boot，
再从 recovery/initramfs 启动并完整重建 UBI。**不能把本镜像当作能从任意
原厂或旧版分区布局直接保留配置升级的普通 sysupgrade。**

本仓库只发布 recovery 和 sysupgrade 镜像，不发布也不自动写入 bootloader。
如果尚未确认你的两台设备已经处于 YYH2913 新布局，先不要刷
`sysupgrade.itb`。先备份原始 MTD、确认串口/救砖路径及当前
`ubus call system board`、`cat /proc/mtd`、`fw_printenv` 输出。

在已确认新布局的设备上，也建议先用
`*-initramfs-recovery.itb` 临时启动并检查网口、无线和闪存，再决定是否写入
`*-squashfs-sysupgrade.itb`。首次从不同发行版切换时不要保留配置。

网页刷机配套使用 YYH2913
[HTTP U-Boot 260712](https://github.com/YYH2913/http-uboot/releases/tag/260712)
的 `xr1710g-uboot-v2026.07-ab7fd651-flash-slot.bin`。进入
`http://192.168.255.1` 后，系统固件应选择 `Firmware` + `UBI 2.0` 并上传
`*-squashfs-sysupgrade.itb`。U-Boot 安装/升级与系统刷写的区别见
`UBOOT-FLASH-GUIDE.md`。

## 6 GHz Mesh 首测

这版提供所需的 full wpad/SAE/Mesh 用户空间能力，并预置
`XR1710G-CHANGE-ME` 作为明确不可投入生产的占位密钥。两台设备需使用完全
相同的监管域、6 GHz 信道/带宽、Mesh ID、加密方式和密钥；正式使用前同时
修改两台的密钥。默认和首测都使用 `EHT80`，稳定后再尝试 160/320 MHz。

首轮测试建议仅启动 6 GHz Mesh 接口，不要立刻把两端唯一的管理 LAN 都改成
无线回程。先确认 `iw dev <mesh接口> station dump` 显示
`mesh plink: ESTAB`，并从一台设备持续 ping 另一台的有线管理地址，再逐步把
Mesh 接口加入所需桥接/VLAN。这样即使 Mesh 参数配错，仍可从网线恢复配置。

上游目前仍有一个针对 AN7581 + MT7996 + 6 GHz 802.11s 的开放问题：
[`airtime_link_metric_get()` 警告](https://github.com/openwrt/openwrt/issues/24080)。
它发生在 mac80211 无法取得有效速率、回退的平均速率又为 0 时；已知现象是
Mesh 仍可传输，但日志会被 warning 回溯刷屏。首版没有用
`WARN_ON_ONCE()` 掩盖它，因为那只能降低刷屏，不能修复 MT7996 速率数据来源。

复现后在两台机器分别运行：

```sh
xr1710g-mesh-diag
```

把命令输出指向的 `/tmp/xr1710g-mesh-diag-*.txt` 发回即可继续定位。脚本会隐藏
MAC 地址和常见密钥字段。

## 关键文件

- `configs/openwrt.config`：固定的 XR1710G 基础构建配置。
- `feeds.d/openwrt`：固定 commit 的 iStore/LinkEase 和第三方 feeds。
- `packages/openwrt.conf`：iStore、QuickStart 与 Mesh 包选择。
- `diy-part2.d/openwrt.sh`：移除冲突的 wpad 变体并写入社区版标识。
- `scripts/prepare-istore-feed.sh`：带原文校验的 APK 依赖兼容补丁。
- `files/etc/apk/repositories.d/distfeeds.list`：经过真机验证的官方
  snapshot 软件源白名单。
- `scripts/rebuild-initramfs-recovery.sh`：完整 rootfs 安装后的 recovery 二次构建。
- `scripts/verify-xr1710g-build.sh`：产物安全和功能验收门。
- `scripts/package-release.sh`：只打包 XR1710G 产物、校验信息和测试说明。
- `files/usr/sbin/xr1710g-mesh-diag`：上机诊断工具。
- `files/usr/sbin/xr1710g-role`：不会自动切网的主路由/节点角色配置工具。
- `files/etc/init.d/xr1710g-bootlog`：有界的持久化启动/关闭记录。
- `RELEASE-NOTES.md`：刷机前置条件、首测步骤和已知问题。
- `UBOOT-FLASH-GUIDE.md`：配套 HTTP U-Boot 版本及网页刷机步骤。

## 上游与鸣谢

本项目不是从零编写，设备支持、应用、补丁和构建流程来自多个开源项目。完整
来源、固定提交、用途和许可证边界见 [ATTRIBUTION.md](ATTRIBUTION.md)。主要上游：

- [YYH2913/openwrt](https://github.com/YYH2913/openwrt) — XR1710G/AN7581 板级支持、UBI 2.0 与 NPU/MT7996 基础。
- [naoki66/ImmortalWrt-for-Gemtek-XR1710G](https://github.com/naoki66/ImmortalWrt-for-Gemtek-XR1710G) — Airoha LuCI 应用来源。
- [OpenWrt](https://github.com/openwrt/openwrt)、[mt76](https://github.com/openwrt/mt76)、[hostapd](https://w1.fi/hostapd/) — 系统、无线驱动和 WPA/802.11s 用户空间。
- [iStoreOS](https://github.com/istoreos/istoreos)、[LinkEase iStore](https://github.com/linkease/istore) — iStoreOS 公开组件与软件中心。
- [OpenClash](https://github.com/vernesong/OpenClash)、[luci-theme-argon](https://github.com/jerrykuku/luci-theme-argon) — 可选代理管理与 LuCI 主题。

各上游组件继续适用其原许可证和版权声明。本仓库的聚合、补丁与说明不会改变
第三方项目的许可证，也不表示上述项目为本社区固件背书。

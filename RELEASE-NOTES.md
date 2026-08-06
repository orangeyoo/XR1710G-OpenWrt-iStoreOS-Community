# iStoreOS-XR1710G-Community 测试版说明

## 构建身份

- 设备：Econet/Gemtek XR1710G（Airoha AN7581 + MT7996）
- 板级底座：`YYH2913/openwrt`
- 分支：`xr1710g-6.18-integration`
- 固定提交：`2a845ee80c7c52caafe57d518a15b16738eb9ed7`
- 内核：Linux 6.18.38
- 架构：`aarch64_cortex-a53`
- 包管理器：APK
- 名称：`iStoreOS-XR1710G-Community First Release`

这是社区移植测试版，不是 LinkEase/iStoreOS 官方发布版。

## 2026-08-06 双机现场日志验收

两台真实 XR1710G 均已运行本 First Release 并完成只读复核：

- 主路由 `192.168.50.1`、节点 `192.168.50.2` 均为 `6.18.38`、同一 First Release
  构建提交；6 GHz 为 US / 信道 37 / EHT320 / WPA3-SAE 802.11s，当前
  `mesh plink: ESTAB`。
- 两端当前 `tx failed=0`，温度约 52.6°C / 56.7°C，NPU `0.1111`，MT7996
  WM/DSP/WA 固件均正常加载；没有发现 firmware crash、MCU timeout、kernel
  panic、Call Trace、watchdog 重启、UBI/I/O 错误或 `airtime_link_metric_get`。
- 节点启动和主路由无线重载期间，主路由曾记录短暂的 SAE 认证失败/重连、一次
  Mesh 断开后自动恢复，以及 PPPoE PADO 超时。这些事件均发生在对端尚未完全
  上线或接口重载窗口，当前链路已恢复并保持稳定；发布后若在正常运行期间持续
  出现同类事件，应采集 `xr1710g-mesh-diag` 报告再判断。
- Airoha TRNG 偶发冷启动提示、mt7530 `-517`、无线初始化阶段 `-95` 和无配置
  的旧 DDNSTO 实例提示仍属于已知非致命启动/重载日志，不作为“零 warning”承诺。

因此本 First Release 可以作为社区测试版发布，但不应标记为官方版或“所有环境均无日志告警”；
首次刷机和改无线参数仍需保留有线救援路径。

## First Release：2026-08-03 iStoreOS 新版应用入口兼容层

本 First Release 保留已在 XR1710G 真机验证的 Linux 6.18.38、mt76
`b2704cf5`、AN7581/NPU 补丁、hostapd WDS r3、UBI 2.0 和默认
`192.168.50.1`，没有为追版本号切换到 iStoreOS 24.10/25.12 的旧内核或
Rockchip/x86 底座，也没有更换已验证的无线驱动。

本版从 iStoreOS 官方 `istoreos-24.10` 提交 `a405f0378a` 选择性回移 uhttpd
反向代理三段补丁：原始 raw proxy、新版 ucode 崩溃/后端关闭修复，以及
`X-Forwarded-Proto/Host/Port/For` 请求头。它为新版 LinkEase Full 的
`/apps` 同源入口提供底层能力。三份补丁均固定 SHA-256，并已在本版较新的
uhttpd `2026.06.16~7b1bec45` 基线上完成补丁级和包级编译验证。

固件不预装也不启动体积较大的 `linkeasefull`。它按官方方式预置
`/apps=http://127.0.0.1:19290` 同源映射，因为 LinkEase Full 安装包依赖基础
系统提供该入口；映射本身不会新增后台进程或监听端口，只有用户安装应用并
访问 `/apps` 时才会连接后端。

审计还确认 v7 的 QuickStart 0.13.0、iStore 0.2.0、iStoreX 0.6.6 以及 7 月
27 日的 LinkEase feeds 已是当时上游固定版本；UCI、rpcd、odhcpd/odhcp6c、
kmodloader、dnsmasq、dropbear、OpenSSL 和 CA 证书则来自比 iStoreOS 24.10
更晚的 OpenWrt 基线，已包含对应可靠性/安全修复，故不把旧包整包倒灌。
官方 OTA 没有 XR1710G 兼容镜像，本 First Release 不启用官方 OTA，避免跨平台误刷。

## v7：2026-08-03 默认 LAN 192.168.50.1 与 6 GHz WDS 修复版

v7 将全新首启、恢复出厂以及 Recovery/failsafe 的默认管理地址统一从
`192.168.1.1` 改为 `192.168.50.1/24`，避免与常见的光猫管理地址冲突。
它启用 OpenWrt 自带的 `TARGET_DEFAULT_LAN_IP_FROM_PREINIT` 生成机制，不依赖
首启后再执行临时 UCI 改址。离线验收会分别解包 Recovery 和 Sysupgrade，核对
`/lib/preinit/00_preinit.conf` 与 `/etc/board.d/99-lan-ip`，任一镜像仍使用旧
地址就拒绝发布。两台新刷设备仍会拥有相同默认地址，必须逐台接线和设置；子
节点应在组网前改为同网段的不冲突地址，例如 `192.168.50.2`。

本版同时包含下述原定 v6-r4 的 AP-WDS 四地址桥接修复与全部既有修复。

## v6-r4：2026-08-03 6 GHz AP-WDS 四地址桥接修复（未发布，合入 v7）

v6-r4 回移 hostapd 上游提交
`61280edc2e1d6e38566d386e64227655eee3120e`。旧版本在多个 BSS 共用同一
nl80211 driver 时，把 `NL80211_CMD_UNEXPECTED_4ADDR_FRAME` 事件错误投递给
第一个 BSS context，导致 6 GHz AP-WDS 虽能完成 SAE 认证和关联，却不会创建
每站点 AP/VLAN 四地址接口，二层数据无法通过。

修复后二台 XR1710G 在 US / 信道 37 / EHT320 / SAE 下完成真机验证：主节点
创建 `phy0.2-ap0.sta1`（AP/VLAN、`4addr: on`），hostapd 将对端报告为
`"wds": true`，双向 Ping 均为 20/20、0% 丢包，路由器端点双向 TCP 为
547.316/487.594 Mbps。电脑有线接主节点、子节点作为另一端的跨回程复测中，
稳定样本达到约 754–756 Mbps（电脑到节点）和 488–492 Mbps（节点到电脑）。
测试期间 `tx failed=0`，无 MT7996/MCU timeout、firmware crash、call trace 或
设备重启。

本版只修复 WDS 支持，不把默认回程从已经长期验证的 802.11s 自动切成 WDS；
用户仍可保留默认 Mesh。构建将 hostapd/wpad package release 从 r2 提升到 r3，
并在完整镜像验收中核对补丁、prepared source、manifest 及 Recovery/Sysupgrade
内的实际 wpad 二进制，避免增量构建误装旧包。

## v6-r3：2026-08-02 完整后置无线默认值修订版

v6-r2 已经在第二台干净首启上证明：三频均自动生成，2.4/5 GHz AP 与 6 GHz
SAE Mesh 实际启动，旧版 OWE/AKM 错误消失，TRNG、NPU 和 mt76 哈希正常。
继续审计时发现同一底座的 `16-airoha-wifi-tuning` 也因在 MT7996 加载前执行
而被空跑删除，所以它原本针对终端突发卡顿设置的 `uapsd=0` 和
`disassoc_low_ack=0` 未进入 2.4/5 GHz AP。

v6-r3 将这两项并入已经通过真机证明的 post-kmod helper，并把它们加入真实
首启顺序回归测试与 Recovery/Sysupgrade 解包验收。5 GHz 同时明确固定在双机
吞吐与漫游测试使用的信道 36/EHT80，不因早期脚本中的未验证 EHT160 值产生
行为变化。v6-r2 因这一已知遗漏不再作为最终测试候选。

## v6-r2：2026-08-02 真机首启修订版（已被 v6-r3 取代）

旧 v6 在第二台不保留配置的真机首启中确认：MT7996 驱动由 `kmodloader`
加载，而 OpenWrt 在此之前执行的第一次 `wifi config` 看不到三张 radio；因此
旧首启脚本虽然离线检查通过，实际运行时却匹配不到任何无线 section。结果是
2.4/5 GHz 保留无密码 AP，6 GHz 保留 OWE AP，并因所选
`wpad-mesh-openssl` 不提供 OWE 而无法启动。旧 v6 已撤回。

v6-r2 增加 `/usr/sbin/xr1710g-wireless-defaults`：它在 `kmodloader` 之后重新
执行无线探测，只有 2.4/5/6 GHz 三个频段和对应接口全部生成后，才写入
2.4 GHz WPA/WPA2、5 GHz r/k/v 和 6 GHz SAE 802.11s 策略；成功后写一次性
标记，不会在后续启动覆盖用户设置。若任一频段缺失则返回失败，让首启脚本
保留到下次启动重试，不把 OWE/半配置状态当作成功。

回归测试从“完全没有 wireless UCI”的真实首启顺序开始，模拟驱动加载后
生成三频并检查最终状态；同时覆盖缺少 6 GHz 时不得写完成标记，以及标记后
不得覆盖用户 SSID。Recovery 与 Sysupgrade 都会解包检查相同的 helper。

本修订还包含第二台真机暴露的角色工具修复：板型 helper 不再与可选
`board_name` 命令同名；所有可选 UCI 删除在 `set -e` 下保持幂等；节点 ULA
从正确的 `network.globals.ula_prefix` 删除。模拟 UCI 现在也会像真机一样在
删除不存在项时返回失败。

## v6：2026-08-02 系统默认值与可诊断性修正版（已撤回）

v6 保留 v5 已经在两台真机上完成 A/B 与持续负载验证的 mt76 驱动，三个
核心模块的 SHA-256 必须与 v5 真机版本完全一致。本版没有用未验证的无线
驱动替换它，主要修复 v5 永久镜像和默认配置中的问题：

- AdGuard Home 仍可由用户手动启用，但干净镜像不再创建其 S/K 自启链接；
  首启和接口上线触发器也不会启动无 YAML 配置的首次设置服务，避免开放
  `3000`、抢占 `53` 或在节点持续产生失败日志；已有有效配置不会被删除；
- 新增 `/usr/sbin/xr1710g-role`，显式配置主路由 DHCP、主路由 PPPoE 或
  Mesh 节点角色。它强制 PPPoE 只落在独立 WAN，整理主路由 IPv6 PD/LAN RA，
  节点则关闭 DHCPv4、RA、DHCPv6 和独立 ULA；只备份并提交 UCI，不自动重载
  网络、Wi-Fi、DNS、防火墙或重启；
- 首启继续清空 usteer 的 `ssid_list`，5 GHz 明确使用
  `ft_psk_generate_local=1`，因此用户以后修改 SSID 不会留下旧白名单；
- 新增有界的持久化启动历史，只区分“上一次有序关闭”和“上一次未有序
  关闭”。它不能区分断电、硬复位和 watchdog，Recovery RAM 系统中不写记录；
- 将 Airoha TRNG 所需的三路 SCU clock gate 移到 RNG/oscillator 使能之前，
  修正一次冷启动 health-check 失败的可疑初始化竞态。该项必须在刷机后通过
  两台多轮彻底断电冷启动验证，发布说明不提前宣称真机已解决；
- 永久 Sysupgrade 和 Recovery 都增加相同文件、AdGuard 禁用状态、TRNG 最终
  源码顺序、私有凭据/实验回退脚本缺失检查；角色工具另有模拟 UCI 单元测试。

v6 的离线验收通过只代表镜像结构、代码路径和默认状态正确。实际升级顺序必须
是先刷 Mesh 节点、完成多轮冷启动及 Wi-Fi/NPU/日志检查，再刷主路由；不能同时
刷两台，也不能把 TRNG 偶发问题视为刷前已完成真机证明。

## v5：2026-08-02 双机 A/B 验证的 mt76 更新

v5 保留 v4 的 iStoreOS 界面、OpenClash、软件源、漫游和 6 GHz 802.11s
配置，正式集成了两台 XR1710G 真机验证过的无线驱动组合：

- 上游 mt76 固定为 `b2704cf5a4068b672bf47ad5bf6b4802b6770a90`
  （2026-08-01）；
- 在该提交上重基 YYH2913 的 XR1710G/AN7581 NPU、功率控制与 MCU
  统计等板级修改；
- 修正 MT7996 `tx_failed` 统计口径：重试只计入 `tx_retries`，只有最终
  未收到 ACK 的帧才计入 `tx_failed`；
- 构建器从公开 Git 提交和两份固定补丁重现源码，不依赖本机临时源码包；
- Recovery 与 Sysupgrade 验收会提取并校验三个核心模块，必须与真机 A/B
  测试版本的 SHA-256 完全一致。

固定摆位、6 GHz 信道 37、EHT80、4 条 TCP 流、每轮 15 秒的结果：

| 驱动组合 | 楼上节点 → 楼下主路由 | 楼下主路由 → 楼上节点 |
|---|---:|---:|
| 两台旧版 `59676919` | 443.1 Mbps | 302.9 Mbps |
| 两台新版 `b2704cf5`，5 轮平均 | 463.5 Mbps | 455.7 Mbps |

新版把原先明显不对称的方向从约 303 Mbps 提高到约 456 Mbps（约
`+50.4%`）；另一方向约 `+4.6%`。随后双向各进行 60 秒持续测试，结果为
463.4/454.6 Mbps；满载同时 ping 65 次均为零丢包，平均约 15 ms、最高约
38 ms。测试后两端 6 GHz Mesh 均保持 `ESTAB`，NPU/WM/WA/DSP 正常，日志
没有 MT7996 reset、timeout、crash、call trace 或 kernel panic。

这说明升级在本次固定环境中带来了可复现的实际收益；它不代表所有距离、
干扰和信道条件下都能得到相同比例的提升。

## v4：2026-07-31 双机漫游与 OpenClash 完整修复

v4 在 v3 已验证的软件源、NPU、iStoreX、Argon 和 6 GHz 802.11s 基础上新增：

- 2.4 GHz 首启采用 WPA/WPA2 Personal 混合模式（`psk-mixed`），启用
  802.11k/v、关闭 802.11r，兼容老设备；
- 5 GHz 首启采用 WPA2/WPA3 Personal 混合模式（`sae-mixed`），启用
  802.11r/k/v，mobility domain 固定为 `6616`，使用 over-the-air FT；
- 内置并启用 `usteer`，但关闭主动拒绝关联、踢客户端、强制漫游、负载踢出
  和跨频段 steering；不设置 `ssid_list`，因此用户改名后仍对所有 SSID 生效；
- 新增 `/etc/crontabs/root`，权限为 `0600`，首启也会自动补建和修复权限，
  解决 OpenClash 0.47.133 卡在启动 Step 5；
- 验收同时确认 Metacubexd、Zashboard、OpenClash 标准 UI 路径和
  `SAFE_PATHS=/usr/share/openclash:/etc/ssl`；
- 继续保留 6 GHz 独立 WPA3-SAE 802.11s 回程、信道 37、EHT80。

所有 SSID 和密码均为公开占位值。镜像不含用户的 Wi-Fi、PPPoE、root 密码或
真实管理地址。

## v3：2026-07-31 真机问题修复汇总

本版在双机实测后固化了以下修复：

- QuickStart/iStore 软件源：不再生成不存在的 `releases/SNAPSHOT` 和
  第三方官方仓库路径；系统源与 iStore 私有源隔离；
- 6 GHz 默认回程：从无法完成桥接回包的 AP-WDS 改为已验证稳定的
  WPA3-SAE 802.11s、信道 37、EHT80；
- NPU 状态：Linux 6.18 优先读取 conntrack 的 `[HW_OFFLOAD]`，不再因旧
  debugfs `ppe/bind` 为空而误报 NPU idle；
- 默认启用 Packet Steering、软件 Flow Offload 和硬件 Flow Offload；
- Airoha NPU/FlowSense、风扇和 jitter 后端以 LF 换行打包，避免 rpcd
  因 CRLF 无法执行；
- OpenClash 内置正式 Meta 核心但保持默认关闭。

## iStoreOS 界面与 OpenClash

本版在原 XR1710G/6 GHz 底座上新增并核验：

- `luci-app-istorex 0.6.6`：iStoreOS 风格首页壳；
- `luci-theme-argon 2.2.12.3` 与 `luci-app-argon-config 0.9.2`：
  普通 LuCI 设置页使用 Argon；
- `luci-app-openclash 0.47.133`；
- OpenClash 所需的 Ruby/YAML、透明代理和网络依赖；
- 已内置 aarch64 Meta/Mihomo 核心
  `/etc/openclash/core/clash_meta`，SHA-256：
  `ceb3fb6715aa6b922851126fa41980489aedd8e3e47fd767380b6d76317c1981`。

OpenClash 默认关闭，不会在尚未导入订阅或配置时接管网络。

## 已验证

- XR1710G 是唯一启用的设备 profile。
- `wpad-mesh-openssl` 是唯一启用的 hostapd/wpad provider。
- 已包含 WPA3-SAE/802.11s 所需的 full wpad、`wireless-regdb` 和
  `iw-full`。
- 首启 6 GHz 默认使用已通过双机桥接验收的 802.11s/EHT80；不再采用只能
  关联但无法正常桥接回包的 AP-WDS/STA-WDS。
- 已包含 MT7996 驱动、固件和 Airoha MT7996 NPU 固件。
- 已包含 iStore、QuickStart、iStoreX、Argon 和 OpenClash。
- 系统 APK 源只包含 7 个已验证存在的 OpenWrt 官方 snapshot 仓库；
  iStore 私有 APK 源与系统源隔离。
- Recovery 是带独立 XZ ramdisk 的 FIT，不是空 initramfs：
  - FIT 中明确包含 `RAMDisk Image` 和 `Init Ramdisk: initrd-1`；
  - 解压后的 cpio 大于 10 MiB；
  - cpio 中存在 `/init`、iStore、QuickStart、iStoreX、Argon、
    OpenClash、Meta 核心和 `/usr/sbin/xr1710g-mesh-diag`。
- 已直接提取永久 sysupgrade FIT 中的 squashfs rootfs，确认同样存在
  iStoreX、Argon、OpenClash 完整运行文件及 Meta 核心。
- `profiles.json`、manifest 和镜像实际包选择一致。
- `sha256sums` 已全部验证通过。

真机验证结果：

```text
apk update       -> 成功，约 9990 个可用包
is-opkg update   -> 成功，877 个 iStore 包
QuickStart 首页  -> 网络连接正常（不再显示“软件源错误”）
```

OpenWrt snapshot 仓库会滚动更新。不要在未核对内核 ABI 和驱动版本的情况下
批量升级底层系统包。

两台 XR1710G 已验证社区移植版可以启动、UBI 正常、三张 MT7996 射频正常，
iStoreX/Argon/OpenClash 文件完整，6 GHz SAE 802.11s 回程可以自动达到
`mesh plink: ESTAB`。OpenClash 默认关闭，仍需由用户导入自己的有效配置。

## 配套 HTTP U-Boot

正常网页刷机推荐使用 YYH2913 的正式发布版：

```text
Release: 260712
File: xr1710g-uboot-v2026.07-ab7fd651-flash-slot.bin
SHA256: 44e8911c55d3e8f2a8be1befb8a8d892047780ab46850057949a661ec2e45953
```

本项目没有重新编译或修改这个 Bootloader。若第二台尚未安装该 HTTP
  U-Boot，请仍使用之前核验过的上游原件；本 v6 系统包不包含也不更新
Bootloader。详细步骤见 `UBOOT-FLASH-GUIDE.md`。

## 文件用途

- `*-initramfs-recovery.itb`
  - 用于临时 Recovery/内存系统测试。
  - 它仍要求当前 Bootloader 能正确加载该 XR1710G FIT。
- `*-squashfs-sysupgrade.itb`
  - 永久系统镜像。
  - 在确认 Bootloader 和 UBI 2.0 布局之前不要刷。
- `*.manifest`
  - 固件内置软件包清单。
- `profiles.json`
  - XR1710G profile、镜像大小与 SHA-256 元数据。
- `sha256sums`
  - 所有交付文件的校验和。
- `config.buildinfo`、`feeds.buildinfo`、`version.buildinfo`
  - 可复现构建信息。
- `verify.txt`
  - 本地最终验收结果。

## 刷机前硬性条件

本镜像内嵌的是 YYH2913 的 XR1710G **UBI 2.0** 布局：

| 分区 | 起始 | 大小 |
|---|---:|---:|
| `vendor` | `0x00000000` | `0x00600000` |
| `chainloader` | `0x00600000` | `0x00100000` |
| `ubi` | `0x00700000` | `0x1b700000` |
| `reserved_bmt` | `0x1be00000` | `0x04200000` |

YYH2913 底座明确要求：先安装支持该边界的 XR1710G chainloader/U-Boot，
再从 Recovery 完整重建 UBI。不同布局之间只更新 `fit` 或普通保留配置
sysupgrade 都不安全。

在提供任何永久写入命令前，请先从你当前系统取得并保存：

```sh
ubus call system board
cat /proc/mtd
fw_printenv
```

还需要确认：

1. 原始 MTD 已做离机备份；
2. 有 3.3 V UART 串口日志和可用的救砖路径；
3. 当前使用哪一种 Bootloader/安装方案；
4. Bootloader 的 Recovery 页面或串口能否先做 RAM-only 启动；
5. 两台设备逐台操作，第一台完成稳定验证后再动第二台。

不要把 W1700K chainloader、Airoha EVB 的 FIP/preloader 或其他机型
Bootloader 写入 XR1710G。

## 首次上机检查

本 First Release 默认管理地址为 `192.168.50.1`，用户名 `root`，初始密码为空。
先只连接有线 LAN，启动后立即设置管理员密码。然后运行：

```sh
ubus call system board
cat /proc/mtd
iw reg get
iw dev
apk query --installed | grep -E 'wpad|mt7996|wireless-regdb|luci-app-(store|istorex|openclash)|luci-theme-argon|quickstart'
```

确认三张射频卡、网口、NAND/UBI 和 LuCI 都正常，再开始 Mesh 测试。

第二台必须全新刷入，不保留旧配置。首次登录后确认 iStoreX 首页和 Argon
设置页正常；OpenClash 先保持关闭，导入你自己的订阅/配置并检查无误后再开启。

## 两台设备的角色和漫游配置

同一份 v6 镜像不会擅自猜测主路由和节点。两台首次启动会有相同的默认地址，
应逐台连接、逐台配置：

- 主路由：最终 LAN 地址与 DHCP 服务器只在主路由配置；PPPoE 只能配置在
  独立 WAN 接口；
- 节点：设置同网段静态管理地址，关闭 DHCP，网关/DNS 指向主路由；
- 2.4 GHz：两台使用相同 SSID、`psk-mixed` 和密码，保持 r 关闭、k/v 开启；
- 5 GHz：两台使用相同 SSID、`sae-mixed` 和密码，保持 r/k/v 开启，并使用
  相同 mobility domain；
- 6 GHz：两台使用相同 Mesh ID、SAE 密钥、信道和带宽。

改主路由 Wi-Fi 名称或密码不会自动同步到节点，必须分别修改两台。v6 的
usteer 没有 SSID 白名单，所以改名后无需再调整 usteer。

本 First Release 可在保持有线管理连接时先运行以下命令；命令只提交配置，不会主动切网：

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.10.1/24
xr1710g-role main-pppoe 192.168.10.1/24
xr1710g-role node 192.168.10.2/24 192.168.10.1
```

PPPoE 已配置时 `main-pppoe` 保留现有账号密码；如需写入新账号，把用户名作为
第三个参数，工具会从终端隐藏读取密码。执行后先用 `status` 检查，再由用户
自行选择合适时机重启。

## 6 GHz 回程首测

- 两台都使用 `US` 监管域；
- 两端使用相同的信道、带宽、Mesh ID、SAE 密钥；
- 首测使用信道 37、`EHT80`；
- 确认稳定后再尝试 `EHT160`/`EHT320`；
- 先保持有线管理路径，不要立即把唯一管理接口改成无线；
- 先确认：

```sh
iw dev <mesh接口> station dump
iw dev <mesh接口> mpath dump
```

必须看到 peer link 达到 `ESTAB`，再做持续 ping 和吞吐测试。

## `airtime_link_metric_get()` 诊断

OpenWrt issue
[#24080](https://github.com/openwrt/openwrt/issues/24080) 截至本版构建时仍为
open。已知触发条件是 mac80211 计算 Mesh airtime metric 时没有取得有效
rate，且回退平均速率也是 0。把 `WARN_ON()` 改成 `WARN_ON_ONCE()` 只会减少
日志刷屏，不会修复 MT7996 速率数据来源，因此本测试版没有掩盖该 warning。

如果复现，两台分别运行：

```sh
xr1710g-mesh-diag
```

把生成的 `/tmp/xr1710g-mesh-diag-*.txt` 发回。脚本会遮盖常见密钥字段和
MAC 地址；上传前仍建议自行快速检查一遍。

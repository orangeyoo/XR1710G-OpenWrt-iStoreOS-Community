# XR1710G OpenWrt / iStoreOS Wi-Fi 7 Community Firmware v1.4.0

**语言 / Languages：** [中文（本页）](README.md) | [English](README-EN.md) | [双语刷机指南 / Bilingual Flashing Guide](FLASHING-GUIDE.md)

**Gemtek XR1710G、Airoha AN7581、MediaTek MT7996、OpenWrt、iStoreOS、Wi-Fi 7、6GHz 802.11s Mesh。**

这是面向 **Econet/Gemtek XR1710G（Airoha AN7581 + MT7996）** 的非官方社区移植。项目以 [YYH2913/openwrt](https://github.com/YYH2913/openwrt) 的板级支持为基础，按 iStoreOS 的公开组件化方式集成 iStore、QuickStart、Argon、OpenClash、PassWall2、OpenWrt 上游 Docker 套件及 XR1710G 状态/诊断功能。

本项目不是 LinkEase/iStoreOS、OpenWrt、Gemtek、Airoha 或 MediaTek 的官方发布。固件只适用于 XR1710G，不要刷入相似外壳或其他 Airoha/MediaTek 设备。

## v1.4.0 正式版更新

- 修复 LAN 编辑页异常与静态 IPv4 CIDR 保存问题。用户输入不带前缀的 LAN 地址时按 `/24` 安全规范化；后端守护同时处理旧式 `ipaddr + netmask`，避免重启后 LAN/DHCP 因地址格式失效。
- 修复首页被错误重定向到“状态 → 概况”的问题；iStoreX/QuickStart 首页路由不再依赖服务启动时序。
- 风扇改为单一控制器，加入低温最低稳定档、阶梯升速、迟滞和传感器异常兜底，避免两个服务竞争控制。
- 修复 Dockerman 对 Moby 29 信息结构的解析；Docker 未启动时显示明确状态和启用入口，不再展开原始嵌套 JSON。
- 删除 GlassTheme 及其中文包；干净首启默认 Argon，Sysupgrade 保留用户已经选择的主题。
- 6GHz 干净首启模板固定为 `US / channel 37 / EHT160 / 802.11s / network=lan`。模板不预置 SAE 密钥，因此默认禁用；设置两端一致的 Mesh ID 和密钥后再启用。
- MT7996 NPU RX 路径补齐入口网卡信息，确保 PPE 缓存未命中时桥接/FDB 软件回退仍保留正确上下文。准确边界是“有线 Airoha PPE 卸载 + MT7996 Wi-Fi NPU 队列”；未加入未经证明的 802.11s 端到端 PPE 直通。
- 为 10G 联网后本机流量加入 bridge/PPE 保护：本地 FDB、目标为路由器本机和同入口回注流不再被错误绑定回 10G GDM4，普通有线转发与 NAT/PPE 卸载保持可用。
- 预装 `kmod-nft-fullcone` 及匹配的 libnftnl/nftables/firewall4/LuCI 支持，默认关闭。它不能绕过 CGNAT 或双重 NAT，也不保证 NAT Type 1。
- 预装 PassWall2 `26.8.20`、Xray `26.7.28`、sing-box `1.13.19`及 firewall4 原生 nftables 透明代理路径，默认关闭。PassWall2 与 OpenClash 不要同时启用。
- 强化首次凭据门禁：初始管理员密码为 `password`；2.4/5GHz 不预置 Wi-Fi 密码，6GHz 空密钥 Mesh 模板保持禁用。

详细变更见 [CHANGES-v1.md](CHANGES-v1.md)，来源和许可证边界见 [ATTRIBUTION.md](ATTRIBUTION.md)。

## 核心能力

- Linux 6.18.41，XR1710G AN7581 DTS、NAND/UBI 2.0、以太网、PPE 和 NPU 支持。
- 固定 XR1710G mt76/MT7996 适配提交 `b2704cf5`；hostapd 基线为 2026-07-09 `f08f2749`。
- 2.4/5/6GHz 三频 Wi-Fi 7，WPA3-SAE 802.11s Mesh；MLO 默认关闭。
- WDS/AP-WDS 为补充能力，不是默认回程；当前推荐回程仍是单跳 802.11s。
- iStore、iStoreX、QuickStart、Argon、OpenClash、PassWall2、Nikki、EqosPlus 和诊断页面。
- OpenWrt 上游 Moby、containerd、runc、docker-compose 与 Dockerman；Docker 默认停止且不自启。
- 默认管理地址 `192.168.50.1/24`，减少与常见 `192.168.1.1` 光猫冲突。
- `/usr/sbin/xr1710g-role`：准备主路由或节点角色，只提交配置，不擅自切网或重启。
- `/usr/sbin/xr1710g-mesh-diag`：生成脱敏的 Mesh、信号、速率、重试、温度和日志摘要。

## 默认无线策略

干净首启后，驱动加载完成才应用无线默认值：

- 2.4GHz：US、自动信道、HE20、请求 28dBm；SSID 为 `XR1710G`，初始开放且没有预置密码。
- 5GHz：US、channel 36、EHT80、请求 29dBm；SSID 为 `XR1710G-5G`，初始开放且没有预置密码，并启用 802.11k/v/r 与活跃终端防误清退设置。
- 6GHz：US、PSC channel 37、EHT160、请求 28dBm、加入 `lan` 的 WPA3-SAE 802.11s Mesh 模板；没有预置密钥，因此首次默认禁用。

首次登录后应立即修改管理员密码，并为 2.4/5GHz 设置加密和密码。需要兼容老设备时，可把 2.4GHz 设置为 WPA/WPA2 Personal 混合模式。两台设备的 6GHz Mesh 必须设置相同的 Mesh ID、SAE 密钥、频道、带宽和监管域，再分别启用。

XR1710G 三个频段共享同一个 Linux PHY，内核最终只应用一个监管域，不能把三张 Radio 当作完全独立国家码。标准 US/AU 使用原始 regdb 规则。

### XZ 实验档

XZ 是用户主动选择的组合实验配置：2.4/5GHz 使用固定 AU 规则，6GHz 加入 36dBm 无 AFC 实验规则。XZ 不是国家监管域，本固件没有实现 AFC，也不授予 Standard Power 权限。它默认关闭，仅限受控实验室或已取得相应授权的测试；用户必须遵守所在地法律、频道和功率限制。实际功率仍受驱动、固件和 Factory 校准约束。

## 实机验证边界

v1.4.0 Recovery 与 Sysupgrade 镜像均通过完整内容门禁，关键 rootfs、无线模板、Argon、LAN CIDR、Dockerman、Full Cone、PassWall2 与 NPU 修复检查一致。

10G 隔离测试中：

- XR1710G `wan` 协商 10Gbps Full，`lan1` 与测试 NAS 协商 5Gbps Full。
- 15 秒、4 并发 TCP：XR → NAS 约 3.85Gbps，NAS → XR 约 1.69Gbps。
- 两个端口最终 `rx/tx errors=0`，无新增 Link Down、watchdog、DMA/NPU timeout、firmware crash 或 kernel panic。

这些结果证明了本次线材、对端和直连本机端点条件下的载波与传输稳定性，不代表所有交换机、运营商、路由/NAT 或异构桥接拓扑的保证。

既有双机无线验证摆位为楼上、楼下各一台，节点间约 5 米，中间隔木质楼梯和水泥楼板。手动选择 XZ/channel 37/EHT320 后，6GHz 802.11s 约 10 分钟的 20 次双向 4 并发测试中位数约 715/720Mbps，最低约 678/671Mbps，满载后双向各 600 Ping 均 0% 丢包。该结果是特定摆位和手动 EHT320 配置的实测，不是默认 EHT160 或所有环境的吞吐承诺。

## 两台设备的角色和 Mesh

同一镜像不会猜测哪台是主路由。两台干净首启都会使用 `192.168.50.1` 和 DHCP，因此应逐台配置：

1. 主路由保留不冲突的 LAN 地址和 DHCP，只在独立 WAN 接口配置上网方式。
2. 节点设置同网段静态地址，例如 `192.168.50.2/24`，关闭 DHCPv4、RA 和 DHCPv6 服务器，并将网关/DNS 指向主路由。
3. 两台分别设置相同的 2.4/5GHz SSID、加密方式和密码；固件不会自动同步这些设置。
4. 两台 6GHz 设置相同的 Mesh ID、SAE 密钥、频道、带宽和监管域。
5. 保留网线管理，确认 `mesh plink: ESTAB` 后再拔掉节点网线。

角色工具示例：

```sh
xr1710g-role status
xr1710g-role main-dhcp 192.168.50.1/24
xr1710g-role main-pppoe 192.168.50.1/24
xr1710g-role node 192.168.50.2/24 192.168.50.1
```

工具会先备份 UCI，只提交配置，不自动重载网络、无线或重启。完整 Mesh 步骤见 [MESH-GUIDE-ZH.md](MESH-GUIDE-ZH.md)。

## Docker

本项目没有自制 Docker 引擎。固件预装的是 OpenWrt feeds 提供的开源 Moby、containerd、runc、docker-compose 和 luci-app-dockerman。

- 默认已安装，但停止且不自启。
- 从 iStore、Dockerman 或命令行启用后才启动。
- 三种入口控制同一个 `/etc/init.d/dockerd`、`/etc/config/dockerd` 和 `/var/run/docker.sock`。
- 数据目录为 `/overlay/docker/`；大量镜像和容器建议挂载外部存储。

## Release 文件

正式 Release 只保留以下必要文件：

| 文件 | 用途 |
|---|---|
| `xr1710g-community-v1.4.0-sysupgrade.itb` | 后台升级及兼容 HTTP U-Boot 的永久系统安装，普通用户优先使用 |
| `xr1710g-community-v1.4.0-recovery.itb` | 临时救援/恢复镜像，不代替永久 Sysupgrade 安装 |
| `xr1710g-uboot-flash-slot.bin` | 基于 YYH2913 HTTP U-Boot 的实机验证兼容版，加入大文件上传节流与安全中断处理；只有需要更新 U-Boot 时才刷 |
| `SHA256SUMS.txt` | 文件完整性校验，不刷入路由器 |
| `FLASHING-GUIDE.md` | 中英文刷机路径与文件用途 |

普通用户请先阅读 [FLASHING-GUIDE.md](FLASHING-GUIDE.md)。已运行兼容 OpenWrt/iStoreOS，或使用兼容 HTTP U-Boot 的 **Firmware + UBI 2.0 - 439 MiB** 页面时，优先使用 `xr1710g-community-v1.4.0-sysupgrade.itb`。不要把系统 ITB 刷进 U-Boot 槽位。

首次启动地址为 `192.168.50.1`，用户名 `root`，初始密码为 `password`。请先用有线单独连接并立即修改管理员密码及无线加密。

### 切换英文界面

首次界面默认简体中文。进入 **系统 → 系统 → 语言和界面**，把语言改为 **English** 并保存应用。英文路径为 **System → System → Language and Style**。

## 构建

```sh
docker volume create xr1710g-istoreos-final
docker run --name xr1710g-istoreos-build-final \
  -v xr1710g-istoreos-final:/work \
  -v "$PWD":/builder:ro \
  ubuntu:22.04 bash /builder/scripts/build-local-docker.sh
```

关键入口：

- `configs/openwrt.config`：固定构建配置。
- `feeds.d/openwrt`：固定上游 feeds 提交。
- `diy-part2.d/openwrt.sh`：XR1710G/iStoreOS 社区集成。
- `patches/`：OpenWrt、LuCI、软件包和内核补丁。
- `scripts/prebuild-xr1710g-release.sh`：源码发布门禁。
- `scripts/verify-xr1710g-build.sh`：最终 Recovery/Sysupgrade 镜像门禁。

## 上游与许可证

本项目使用并标注了 YYH2913/openwrt、YYH2913/http-uboot、naoki66/ImmortalWrt-for-Gemtek-XR1710G、OpenWrt、mt76、hostapd、iStoreOS、iStore/iStoreX、QuickStart、OpenClash、PassWall2、Argon、Nikki、sirpdboy/EqosPlus 及 Airoha/MediaTek 上游内容。完整固定提交、用途和许可证见 [ATTRIBUTION.md](ATTRIBUTION.md)。各第三方组件继续适用其原许可证，本项目不代表上述上游为本固件背书。
